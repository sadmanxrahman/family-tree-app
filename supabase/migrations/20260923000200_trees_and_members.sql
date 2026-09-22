-- Trees (family spaces) and who belongs to them.
--
-- Nearly every row-level security policy in the app reduces to "what is the current
-- account's role in this row's tree?", answered by the helper functions below. They are
-- SECURITY DEFINER so they can read tree_members without triggering tree_members' own
-- policies (which would recurse).

create table public.trees (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  created_by uuid not null references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.trees is 'A family space. Created only through public.create_tree().';

create index trees_created_by_idx on public.trees (created_by);

create trigger trees_set_updated_at
  before update on public.trees
  for each row execute function public.set_updated_at();

create table public.tree_members (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  user_id uuid not null references public.app_users (id) on delete restrict,
  role public.tree_role not null default 'member',
  invited_by uuid references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Set when someone leaves or is removed. Rejoining creates a new row.
  deleted_at timestamptz
);

comment on table public.tree_members is
  'Accounts with access to a tree. Changed only through the membership functions below.';

-- One active membership per account per tree; removed memberships stay as history.
create unique index tree_members_active_unique
  on public.tree_members (tree_id, user_id) where deleted_at is null;
create index tree_members_user_id_idx on public.tree_members (user_id) where deleted_at is null;
create index tree_members_invited_by_idx on public.tree_members (invited_by);

create trigger tree_members_set_updated_at
  before update on public.tree_members
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Permission helpers
-- ---------------------------------------------------------------------------

-- The current account's role in a tree, or null if it is not an active member of a
-- tree that still exists.
create function public.tree_role_of(p_tree_id uuid)
returns public.tree_role
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
  from public.tree_members m
  join public.trees t on t.id = m.tree_id
  where m.tree_id = p_tree_id
    and m.user_id = (select auth.uid())
    and m.deleted_at is null
    and t.deleted_at is null;
$$;

create function public.is_tree_member(p_tree_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.tree_role_of(p_tree_id) is not null;
$$;

-- Owners, admins and members can add and edit; viewers only read.
create function public.can_edit_tree(p_tree_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.tree_role_of(p_tree_id) in ('owner', 'admin', 'member'), false);
$$;

create function public.is_tree_admin(p_tree_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.tree_role_of(p_tree_id) in ('owner', 'admin'), false);
$$;

-- No under-18 accounts (CLAUDE.md): creating or joining a tree requires the 18+
-- confirmation recorded at sign-in.
create function public.is_confirmed_adult()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.app_users
    where id = (select auth.uid()) and age_confirmed_at is not null and deleted_at is null
  );
$$;

-- True when the current account and p_user_id are both active members of some tree.
create function public.shares_tree_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tree_members mine
    join public.tree_members theirs on theirs.tree_id = mine.tree_id
    join public.trees t on t.id = mine.tree_id
    where mine.user_id = (select auth.uid())
      and theirs.user_id = p_user_id
      and mine.deleted_at is null
      and theirs.deleted_at is null
      and t.deleted_at is null
  );
$$;

-- ---------------------------------------------------------------------------
-- Tree and membership operations. Direct INSERT/UPDATE on trees' ownership and on
-- tree_members is not granted; these functions enforce the rules instead.
-- ---------------------------------------------------------------------------

-- Creates a tree and makes the caller its owner in one step. (A plain INSERT could not
-- return the new row: the caller only becomes a member after the insert.)
create function public.create_tree(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_tree_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if not public.is_confirmed_adult() then
    raise exception 'age_not_confirmed' using errcode = '42501';
  end if;

  insert into public.trees (name, created_by) values (trim(p_name), v_user_id)
  returning id into v_tree_id;

  insert into public.tree_members (tree_id, user_id, role) values (v_tree_id, v_user_id, 'owner');

  return v_tree_id;
end;
$$;

-- Owners can change anyone's role except their own; admins can change members and
-- viewers only. Nobody becomes owner this way (see transfer_tree_ownership).
create function public.set_member_role(p_member_id uuid, p_role public.tree_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.tree_members;
  v_caller_role public.tree_role;
begin
  select * into v_target from public.tree_members where id = p_member_id and deleted_at is null;
  if not found then
    raise exception 'member_not_found' using errcode = 'P0002';
  end if;

  v_caller_role := public.tree_role_of(v_target.tree_id);

  if p_role = 'owner' then
    raise exception 'use_transfer_tree_ownership' using errcode = '42501';
  end if;
  if v_target.role = 'owner' or v_target.user_id = (select auth.uid()) then
    raise exception 'cannot_change_this_member' using errcode = '42501';
  end if;
  if not (
    v_caller_role = 'owner'
    or (v_caller_role = 'admin' and v_target.role in ('member', 'viewer') and p_role <> 'admin')
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.tree_members set role = p_role where id = p_member_id;
end;
$$;

-- Same authority rules as set_member_role. Soft-deletes the membership.
create function public.remove_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.tree_members;
  v_caller_role public.tree_role;
begin
  select * into v_target from public.tree_members where id = p_member_id and deleted_at is null;
  if not found then
    raise exception 'member_not_found' using errcode = 'P0002';
  end if;

  v_caller_role := public.tree_role_of(v_target.tree_id);

  if v_target.role = 'owner' or v_target.user_id = (select auth.uid()) then
    raise exception 'cannot_remove_this_member' using errcode = '42501';
  end if;
  if not (
    v_caller_role = 'owner'
    or (v_caller_role = 'admin' and v_target.role in ('member', 'viewer'))
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.tree_members set deleted_at = now() where id = p_member_id;
  -- Defined with the persons table (next migration); resolved when this runs.
  perform public.release_claims_in_tree(v_target.tree_id, v_target.user_id);
end;
$$;

-- Anyone but the owner can leave. The owner must transfer ownership first.
create function public.leave_tree(p_tree_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if public.tree_role_of(p_tree_id) is null then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  if public.tree_role_of(p_tree_id) = 'owner' then
    raise exception 'owner_must_transfer_first' using errcode = '42501';
  end if;

  update public.tree_members
  set deleted_at = now()
  where tree_id = p_tree_id and user_id = v_user_id and deleted_at is null;
  perform public.release_claims_in_tree(p_tree_id, v_user_id);
end;
$$;

-- The owner hands the tree to another active member and becomes an admin.
create function public.transfer_tree_ownership(p_tree_id uuid, p_new_owner_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if public.tree_role_of(p_tree_id) is distinct from 'owner' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.tree_members
    where tree_id = p_tree_id and user_id = p_new_owner_user_id and deleted_at is null
      and user_id <> v_user_id
  ) then
    raise exception 'new_owner_not_a_member' using errcode = 'P0002';
  end if;

  update public.tree_members set role = 'admin'
  where tree_id = p_tree_id and user_id = v_user_id and deleted_at is null;
  update public.tree_members set role = 'owner'
  where tree_id = p_tree_id and user_id = p_new_owner_user_id and deleted_at is null;
end;
$$;

-- Only the owner can delete a tree. Soft delete: everything in it becomes invisible
-- because every policy checks membership of a tree that is not deleted.
create function public.delete_tree(p_tree_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.tree_role_of(p_tree_id) is distinct from 'owner' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  update public.trees set deleted_at = now() where id = p_tree_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges and row-level security
-- ---------------------------------------------------------------------------

revoke all on table public.trees from anon, authenticated;
grant select on table public.trees to authenticated;
grant update (name) on table public.trees to authenticated;

revoke all on table public.tree_members from anon, authenticated;
grant select on table public.tree_members to authenticated;

alter table public.trees enable row level security;
alter table public.tree_members enable row level security;

-- You can see a tree only if you are an active member of it.
create policy "trees: members can read"
  on public.trees for select to authenticated
  using (deleted_at is null and public.is_tree_member(id));

-- Owners and admins can rename a tree.
create policy "trees: admins can rename"
  on public.trees for update to authenticated
  using (deleted_at is null and public.is_tree_admin(id))
  with check (public.is_tree_admin(id));

-- You can see who else is in the trees you belong to.
create policy "tree_members: members can see fellow members"
  on public.tree_members for select to authenticated
  using (deleted_at is null and public.is_tree_member(tree_id));

-- app_users (from an earlier migration) could only be read by its own account. Members
-- of the same tree also need each other's display names.
create policy "app_users: fellow tree members can read"
  on public.app_users for select to authenticated
  using (deleted_at is null and public.shares_tree_with(id));

-- ...but only the display name, not the account's age confirmation or other internals.
revoke select on table public.app_users from authenticated;
grant select (id, display_name, created_at, updated_at) on table public.app_users to authenticated;

-- Helpers are callable by signed-in accounts only.
revoke execute on function
  public.tree_role_of(uuid),
  public.is_tree_member(uuid),
  public.can_edit_tree(uuid),
  public.is_tree_admin(uuid),
  public.is_confirmed_adult(),
  public.shares_tree_with(uuid),
  public.create_tree(text),
  public.set_member_role(uuid, public.tree_role),
  public.remove_member(uuid),
  public.leave_tree(uuid),
  public.transfer_tree_ownership(uuid, uuid),
  public.delete_tree(uuid)
from public, anon;

grant execute on function
  public.tree_role_of(uuid),
  public.is_tree_member(uuid),
  public.can_edit_tree(uuid),
  public.is_tree_admin(uuid),
  public.is_confirmed_adult(),
  public.shares_tree_with(uuid),
  public.create_tree(text),
  public.set_member_role(uuid, public.tree_role),
  public.remove_member(uuid),
  public.leave_tree(uuid),
  public.transfer_tree_ownership(uuid, uuid),
  public.delete_tree(uuid)
to authenticated;
