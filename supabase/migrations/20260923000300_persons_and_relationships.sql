-- Persons (nodes) and the relationships between them (edges).
--
-- Relationships are edges, never columns: a person has no father_id or mother_id.
-- parent_child and unions hold every link, which handles adoption, step-parents,
-- remarriage, half-siblings (sharing one parent), unknown parentage (no edge), more than
-- two parents, and the same person appearing in two branches (cousin marriage).
--
-- Deliberately NOT enforced here (tolerate messy real-world data, e.g. GEDCOM imports):
-- a maximum number of biological parents, or a living person having a death date. The
-- app warns about those instead.

-- ---------------------------------------------------------------------------
-- persons
-- ---------------------------------------------------------------------------

create table public.persons (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,

  -- All optional: a placeholder like "unknown father" has no name.
  given_names text check (char_length(given_names) <= 200),
  family_name text check (char_length(family_name) <= 200),
  -- e.g. a maiden name. Other spellings and scripts live in person_names.
  birth_family_name text check (char_length(birth_family_name) <= 200),
  -- Optional; blank means unknown. Used only for labels like "mother" vs "parent".
  gender public.person_gender,

  is_living boolean not null default true,

  birth_date date,
  birth_date_precision public.fuzzy_precision,
  birth_date_end date,
  death_date date,
  death_date_precision public.fuzzy_precision,
  death_date_end date,

  -- Anyone in the tree can hide a person from the map; only that person (once they have
  -- claimed their profile) can unhide themselves. Enforced by persons_guard below.
  hidden_from_map boolean not null default false,

  -- The account that is this person. Set only by claim approval or invitation
  -- acceptance, never by a direct update (no column privilege is granted).
  claimed_by_user_id uuid references public.app_users (id) on delete restrict,

  -- Foreign key to media_assets is added in the memories migration.
  profile_media_id uuid,

  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  -- Lets child tables use composite foreign keys that guarantee same-tree links.
  constraint persons_tree_id_id_key unique (tree_id, id),
  constraint persons_birth_date_valid
    check (public.fuzzy_date_is_valid(birth_date, birth_date_precision, birth_date_end)),
  constraint persons_death_date_valid
    check (public.fuzzy_date_is_valid(death_date, death_date_precision, death_date_end)),
  -- Deceased persons stay family-editable forever: they can never be claimed.
  constraint persons_deceased_never_claimed check (is_living or claimed_by_user_id is null)
);

comment on table public.persons is
  'A node in a family tree: a relative, living or deceased, claimed by an account or not.';

create index persons_tree_id_idx on public.persons (tree_id) where deleted_at is null;
create index persons_created_by_idx on public.persons (created_by);
create index persons_profile_media_id_idx on public.persons (profile_media_id);
-- One account claims at most one person per tree.
create unique index persons_one_claim_per_account_per_tree
  on public.persons (tree_id, claimed_by_user_id)
  where claimed_by_user_id is not null and deleted_at is null;
create index persons_claimed_by_user_id_idx on public.persons (claimed_by_user_id)
  where claimed_by_user_id is not null;

create trigger persons_set_updated_at
  before update on public.persons
  for each row execute function public.set_updated_at();

-- Guards the rules column privileges can't express.
create function public.persons_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if new.tree_id <> old.tree_id then
    raise exception 'persons_cannot_move_tree' using errcode = '42501';
  end if;

  -- Only the claimed person themselves can unhide from the map. The dashboard and
  -- server-side jobs (no signed-in account) are exempt.
  if old.hidden_from_map and not new.hidden_from_map and v_user_id is not null
     and old.claimed_by_user_id is distinct from v_user_id then
    raise exception 'only_the_person_can_unhide_from_map' using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger persons_guard
  before update on public.persons
  for each row execute function public.persons_guard();

-- Whether the current account may directly edit this person's details (and their name
-- variants and places): anyone who can edit the tree for unclaimed persons; only the
-- claimant for claimed persons. Everyone else proposes changes via change_requests.
create function public.can_edit_person(p_person_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.persons p
    where p.id = p_person_id
      and p.deleted_at is null
      and (
        (p.claimed_by_user_id is null and public.can_edit_tree(p.tree_id))
        or (p.claimed_by_user_id = (select auth.uid()) and public.is_tree_member(p.tree_id))
      )
  );
$$;

-- Releases any person an account had claimed in a tree (used when it leaves or is
-- removed; referenced by the membership functions in the previous migration).
create function public.release_claims_in_tree(p_tree_id uuid, p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.persons
  set claimed_by_user_id = null
  where tree_id = p_tree_id and claimed_by_user_id = p_user_id;
$$;

-- "Hide me from the map": any member of the tree, even a viewer, may hide anyone.
create function public.hide_person_from_map(p_person_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tree_id uuid;
begin
  select tree_id into v_tree_id from public.persons where id = p_person_id and deleted_at is null;
  if v_tree_id is null or not public.is_tree_member(v_tree_id) then
    raise exception 'person_not_found' using errcode = 'P0002';
  end if;
  update public.persons set hidden_from_map = true where id = p_person_id;
end;
$$;

-- Records a death. For a claimed person this also releases the claim (deceased persons
-- can't be claimed), so only owners and admins may do it, and the change_log entry is
-- tagged with the reason. The app must require an explicit confirmation step first.
create function public.mark_person_deceased(
  p_person_id uuid,
  p_death_date date default null,
  p_death_date_precision public.fuzzy_precision default null,
  p_death_date_end date default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_person public.persons;
begin
  select * into v_person from public.persons where id = p_person_id and deleted_at is null;
  if not found or not public.is_tree_member(v_person.tree_id) then
    raise exception 'person_not_found' using errcode = 'P0002';
  end if;
  if not v_person.is_living then
    raise exception 'already_deceased' using errcode = 'P0001';
  end if;

  if v_person.claimed_by_user_id is not null then
    if not public.is_tree_admin(v_person.tree_id) then
      raise exception 'only_admins_can_mark_claimed_person_deceased' using errcode = '42501';
    end if;
    perform set_config('app.change_reason', 'marked_deceased_claim_released', true);
  else
    if not public.can_edit_tree(v_person.tree_id) then
      raise exception 'not_allowed' using errcode = '42501';
    end if;
    perform set_config('app.change_reason', 'marked_deceased', true);
  end if;

  update public.persons
  set is_living = false,
      claimed_by_user_id = null,
      death_date = p_death_date,
      death_date_precision = p_death_date_precision,
      death_date_end = p_death_date_end
  where id = p_person_id;

  perform set_config('app.change_reason', '', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- person_names: nicknames, alternate spellings and native-script forms.
-- A separate table (not an array) so each variant carries its own script, has its own
-- change history, and can be indexed for search and cross-family matching.
-- ---------------------------------------------------------------------------

create table public.person_names (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  person_id uuid not null,
  name text not null check (char_length(trim(name)) between 1 and 300),
  kind public.name_kind not null default 'variant',
  -- ISO 15924 script code, e.g. Latn, Beng (Bengali), Arab. Null when not recorded.
  script text check (script ~ '^[A-Z][a-z]{3}$'),
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict
);

comment on table public.person_names is
  'Other names for a person: "Md. Rahman", "Mohammed Rahman", "মোহাম্মদ রহমান".';

create index person_names_tree_id_idx on public.person_names (tree_id) where deleted_at is null;
create index person_names_person_id_idx on public.person_names (person_id) where deleted_at is null;
create index person_names_created_by_idx on public.person_names (created_by);
create index person_names_lower_name_idx on public.person_names (lower(name)) where deleted_at is null;

create trigger person_names_set_updated_at
  before update on public.person_names
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- parent_child
-- ---------------------------------------------------------------------------

create table public.parent_child (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  parent_id uuid not null,
  child_id uuid not null,
  kind public.parent_child_kind not null,
  -- e.g. when an adoption, fostering or guardianship began and ended.
  start_date date,
  start_date_precision public.fuzzy_precision,
  start_date_end date,
  end_date date,
  end_date_precision public.fuzzy_precision,
  end_date_end date,
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  -- Both people must be in this edge's tree.
  foreign key (tree_id, parent_id) references public.persons (tree_id, id) on delete restrict,
  foreign key (tree_id, child_id) references public.persons (tree_id, id) on delete restrict,
  constraint parent_child_not_self check (parent_id <> child_id),
  constraint parent_child_start_date_valid
    check (public.fuzzy_date_is_valid(start_date, start_date_precision, start_date_end)),
  constraint parent_child_end_date_valid
    check (public.fuzzy_date_is_valid(end_date, end_date_precision, end_date_end))
);

comment on table public.parent_child is
  'Parent-to-child edges. Several kinds may link the same pair (e.g. step, then adoptive).';

-- Prevents accidental duplicates; different kinds between the same pair are allowed.
create unique index parent_child_active_unique
  on public.parent_child (parent_id, child_id, kind) where deleted_at is null;
create index parent_child_tree_id_idx on public.parent_child (tree_id) where deleted_at is null;
create index parent_child_parent_id_idx on public.parent_child (parent_id) where deleted_at is null;
create index parent_child_child_id_idx on public.parent_child (child_id) where deleted_at is null;
create index parent_child_created_by_idx on public.parent_child (created_by);

create trigger parent_child_set_updated_at
  before update on public.parent_child
  for each row execute function public.set_updated_at();

-- Nobody can be their own ancestor: a loop would make the tree impossible to draw.
-- This is structural integrity, so unlike the parent-count rule it IS enforced.
create function public.parent_child_prevent_cycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null then
    return new;
  end if;

  if exists (
    with recursive descendants (id) as (
      select new.child_id
      union
      select pc.child_id
      from public.parent_child pc
      join descendants d on pc.parent_id = d.id
      where pc.deleted_at is null and pc.id <> new.id
    )
    select 1 from descendants where id = new.parent_id
  ) then
    raise exception 'parent_child_would_create_cycle'
      using errcode = '23514',
            detail = 'This link would make someone their own ancestor.';
  end if;

  return new;
end;
$$;

create trigger parent_child_prevent_cycle
  before insert or update of parent_id, child_id, deleted_at on public.parent_child
  for each row execute function public.parent_child_prevent_cycle();

-- ---------------------------------------------------------------------------
-- unions
-- ---------------------------------------------------------------------------

create table public.unions (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  person_a_id uuid not null,
  person_b_id uuid not null,
  kind public.union_kind not null default 'marriage',
  status public.union_status not null default 'current',
  start_date date,
  start_date_precision public.fuzzy_precision,
  start_date_end date,
  end_date date,
  end_date_precision public.fuzzy_precision,
  end_date_end date,
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, person_a_id) references public.persons (tree_id, id) on delete restrict,
  foreign key (tree_id, person_b_id) references public.persons (tree_id, id) on delete restrict,
  constraint unions_not_self check (person_a_id <> person_b_id),
  constraint unions_start_date_valid
    check (public.fuzzy_date_is_valid(start_date, start_date_precision, start_date_end)),
  constraint unions_end_date_valid
    check (public.fuzzy_date_is_valid(end_date, end_date_precision, end_date_end))
);

comment on table public.unions is
  'Marriages and partnerships. The same two people may have several (married, divorced, remarried).';

create index unions_tree_id_idx on public.unions (tree_id) where deleted_at is null;
create index unions_person_a_id_idx on public.unions (person_a_id) where deleted_at is null;
create index unions_person_b_id_idx on public.unions (person_b_id) where deleted_at is null;
create index unions_created_by_idx on public.unions (created_by);

create trigger unions_set_updated_at
  before update on public.unions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Privileges. Start from nothing; grant exactly the columns the app may write.
-- No DELETE anywhere: removing means setting deleted_at.
-- ---------------------------------------------------------------------------

revoke all on table public.persons from anon, authenticated;
grant select on table public.persons to authenticated;
grant insert (
  tree_id, given_names, family_name, birth_family_name, gender, is_living,
  birth_date, birth_date_precision, birth_date_end,
  death_date, death_date_precision, death_date_end,
  hidden_from_map, profile_media_id
) on table public.persons to authenticated;
grant update (
  given_names, family_name, birth_family_name, gender, is_living,
  birth_date, birth_date_precision, birth_date_end,
  death_date, death_date_precision, death_date_end,
  hidden_from_map, profile_media_id, deleted_at
) on table public.persons to authenticated;

revoke all on table public.person_names from anon, authenticated;
grant select on table public.person_names to authenticated;
grant insert (tree_id, person_id, name, kind, script) on table public.person_names to authenticated;
grant update (name, kind, script, deleted_at) on table public.person_names to authenticated;

revoke all on table public.parent_child from anon, authenticated;
grant select on table public.parent_child to authenticated;
grant insert (
  tree_id, parent_id, child_id, kind,
  start_date, start_date_precision, start_date_end,
  end_date, end_date_precision, end_date_end
) on table public.parent_child to authenticated;
grant update (
  kind,
  start_date, start_date_precision, start_date_end,
  end_date, end_date_precision, end_date_end,
  deleted_at
) on table public.parent_child to authenticated;

revoke all on table public.unions from anon, authenticated;
grant select on table public.unions to authenticated;
grant insert (
  tree_id, person_a_id, person_b_id, kind, status,
  start_date, start_date_precision, start_date_end,
  end_date, end_date_precision, end_date_end
) on table public.unions to authenticated;
grant update (
  kind, status,
  start_date, start_date_precision, start_date_end,
  end_date, end_date_precision, end_date_end,
  deleted_at
) on table public.unions to authenticated;

revoke execute on function
  public.can_edit_person(uuid),
  public.release_claims_in_tree(uuid, uuid),
  public.hide_person_from_map(uuid),
  public.mark_person_deceased(uuid, date, public.fuzzy_precision, date),
  public.persons_guard(),
  public.parent_child_prevent_cycle()
from public, anon, authenticated;
grant execute on function
  public.can_edit_person(uuid),
  public.hide_person_from_map(uuid),
  public.mark_person_deceased(uuid, date, public.fuzzy_precision, date)
to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
--
-- READ RULES AND SOFT DELETE: when an UPDATE sets deleted_at, Postgres re-checks the
-- updated row against the table's SELECT policy. So each SELECT policy lets live rows be
-- seen by every member, and soft-deleted rows only by whoever was allowed to remove
-- them. The UPDATE policies don't require deleted_at IS NULL, so those same people can
-- also restore a row. App queries still filter deleted_at IS NULL (rule 3).
-- ---------------------------------------------------------------------------

alter table public.persons enable row level security;
alter table public.person_names enable row level security;
alter table public.parent_child enable row level security;
alter table public.unions enable row level security;

-- persons ------------------------------------------------------------------

-- Everyone in a tree can see everyone in it. A removed person stays visible only to
-- those who could have removed them.
create policy "persons: members can read"
  on public.persons for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (
      deleted_at is null
      or (claimed_by_user_id is null and public.can_edit_tree(tree_id))
      or claimed_by_user_id = (select auth.uid())
    )
  );

-- Owners, admins and members can add people. New people are never pre-claimed.
create policy "persons: editors can add"
  on public.persons for insert to authenticated
  with check (public.can_edit_tree(tree_id) and claimed_by_user_id is null);

-- Unclaimed people are family-editable: any owner, admin or member can change them.
create policy "persons: editors can edit unclaimed people"
  on public.persons for update to authenticated
  using (claimed_by_user_id is null and public.can_edit_tree(tree_id))
  with check (claimed_by_user_id is null and public.can_edit_tree(tree_id));

-- A claimed person's details can only be changed by that person. Other members submit
-- a change request instead.
create policy "persons: claimed people edit themselves"
  on public.persons for update to authenticated
  using (
    claimed_by_user_id = (select auth.uid())
    and public.is_tree_member(tree_id)
  )
  with check (claimed_by_user_id = (select auth.uid()));

-- person_names ---------------------------------------------------------------

-- Everyone in a tree can see every name variant in it; removed ones only by those who
-- can edit the person.
create policy "person_names: members can read"
  on public.person_names for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (deleted_at is null or public.can_edit_person(person_id))
  );

-- Name variants follow the person's rules: family-editable if unclaimed, only the
-- person themselves if claimed.
create policy "person_names: whoever can edit the person can add"
  on public.person_names for insert to authenticated
  with check (public.can_edit_person(person_id));

create policy "person_names: whoever can edit the person can change"
  on public.person_names for update to authenticated
  using (public.can_edit_person(person_id))
  with check (public.can_edit_person(person_id));

-- parent_child -------------------------------------------------------------

-- Everyone in a tree can see its parent-child links; removed links only by editors.
create policy "parent_child: members can read"
  on public.parent_child for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (deleted_at is null or public.can_edit_tree(tree_id))
  );

-- Owners, admins and members can add links, including ones involving claimed people.
-- The counterweight: the claimed person is notified and can undo it (change_log migration).
create policy "parent_child: editors can add"
  on public.parent_child for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- Owners, admins and members can change or remove links (same counterweight applies).
create policy "parent_child: editors can change"
  on public.parent_child for update to authenticated
  using (public.can_edit_tree(tree_id))
  with check (public.can_edit_tree(tree_id));

-- unions -------------------------------------------------------------------

-- Everyone in a tree can see its marriages and partnerships; removed ones only by editors.
create policy "unions: members can read"
  on public.unions for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (deleted_at is null or public.can_edit_tree(tree_id))
  );

-- Owners, admins and members can add unions, including for claimed people (who are
-- notified and can undo).
create policy "unions: editors can add"
  on public.unions for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- Owners, admins and members can change or remove unions (same counterweight).
create policy "unions: editors can change"
  on public.unions for update to authenticated
  using (public.can_edit_tree(tree_id))
  with check (public.can_edit_tree(tree_id));
