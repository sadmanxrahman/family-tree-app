-- How accounts join trees (invitations), become a person in them (claims), and how
-- relatives propose edits to a claimed person (change_requests).

-- ---------------------------------------------------------------------------
-- invitations
-- ---------------------------------------------------------------------------

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  -- SHA-256 of the token in the invite link. The token itself is never stored, so a
  -- database leak can't be used to join trees. No email address is stored either.
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  role public.tree_role not null default 'member' check (role <> 'owner'),
  -- "You are Amy": accepting also claims this person, if still living and unclaimed.
  person_id uuid,
  max_uses integer not null default 1 check (max_uses between 1 and 50),
  use_count integer not null default 0,
  invited_by uuid not null references public.app_users (id) on delete restrict,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict,
  constraint invitations_use_count_in_range check (use_count between 0 and max_uses),
  -- A link that claims a specific person must be single-use.
  constraint invitations_person_links_single_use check (person_id is null or max_uses = 1)
);

comment on table public.invitations is
  'Invite links. Created by create_invitation(), accepted by accept_invitation().';

create index invitations_tree_id_idx on public.invitations (tree_id) where deleted_at is null;
create index invitations_person_id_idx on public.invitations (person_id);
create index invitations_invited_by_idx on public.invitations (invited_by);

create trigger invitations_set_updated_at
  before update on public.invitations
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- claims: "this person in the tree is me"
-- ---------------------------------------------------------------------------

create table public.claims (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  person_id uuid not null,
  user_id uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  status public.request_status not null default 'pending',
  -- Set when the claim came from an invitation naming this person (auto-approved).
  invitation_id uuid references public.invitations (id) on delete restrict,
  reviewed_by uuid references public.app_users (id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict
);

comment on table public.claims is
  'Requests to be linked to a person node. Approved by owners/admins via review_claim().';

-- One open claim per account per tree.
create unique index claims_one_pending_per_account_per_tree
  on public.claims (tree_id, user_id) where status = 'pending' and deleted_at is null;
create index claims_tree_id_idx on public.claims (tree_id) where deleted_at is null;
create index claims_person_id_idx on public.claims (person_id);
create index claims_user_id_idx on public.claims (user_id);
create index claims_invitation_id_idx on public.claims (invitation_id);
create index claims_reviewed_by_idx on public.claims (reviewed_by);

create trigger claims_set_updated_at
  before update on public.claims
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- change_requests: relatives' proposed edits to a claimed person
-- ---------------------------------------------------------------------------

-- The only person fields a change request may touch. Death, claim status and map
-- visibility have their own rules and never go through here.
create function public.change_request_fields_valid(p_changes jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_changes) = 'object'
    and p_changes <> '{}'::jsonb
    and not exists (
      select 1 from jsonb_object_keys(p_changes) as k
      where k not in (
        'given_names', 'family_name', 'birth_family_name', 'gender',
        'birth_date', 'birth_date_precision', 'birth_date_end'
      )
    );
$$;

create table public.change_requests (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  person_id uuid not null,
  requested_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  -- e.g. {"family_name": "Rahman", "birth_date": "1938-01-01", "birth_date_precision": "year"}
  proposed_changes jsonb not null check (public.change_request_fields_valid(proposed_changes)),
  status public.request_status not null default 'pending',
  reviewed_by uuid references public.app_users (id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict
);

comment on table public.change_requests is
  'Edits other members propose to a claimed person, applied only if that person approves.';

create index change_requests_tree_id_idx on public.change_requests (tree_id) where deleted_at is null;
create index change_requests_person_id_status_idx on public.change_requests (person_id, status)
  where deleted_at is null;
create index change_requests_requested_by_idx on public.change_requests (requested_by);
create index change_requests_reviewed_by_idx on public.change_requests (reviewed_by);

create trigger change_requests_set_updated_at
  before update on public.change_requests
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

-- Creates an invite link. Owners and admins only. Returns the token to put in the link;
-- it can never be retrieved again.
create function public.create_invitation(
  p_tree_id uuid,
  p_role public.tree_role default 'member',
  p_person_id uuid default null,
  p_max_uses integer default 1,
  p_valid_days integer default 14
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Two random UUIDs: 244 random bits.
  v_token text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if not public.is_tree_admin(p_tree_id) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_valid_days not between 1 and 90 then
    raise exception 'invalid_validity' using errcode = '22023';
  end if;
  if p_person_id is not null and not exists (
    select 1 from public.persons
    where id = p_person_id and tree_id = p_tree_id and deleted_at is null
      and is_living and claimed_by_user_id is null
  ) then
    raise exception 'person_not_claimable' using errcode = 'P0001';
  end if;

  insert into public.invitations (
    tree_id, token_hash, role, person_id, max_uses, invited_by, expires_at
  ) values (
    p_tree_id,
    encode(sha256(convert_to(v_token, 'UTF8')), 'hex'),
    p_role,
    p_person_id,
    p_max_uses,
    (select auth.uid()),
    now() + make_interval(days => p_valid_days)
  );

  return v_token;
end;
$$;

-- Accepts an invite link: joins the tree, and claims the named person if the link has
-- one. The invitee isn't a member yet so can't read the invitation row; this function
-- checks the token instead. Returns the tree id.
create function public.accept_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_invitation public.invitations;
  v_claim_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '42501';
  end if;
  if not public.is_confirmed_adult() then
    raise exception 'age_not_confirmed' using errcode = '42501';
  end if;

  select i.* into v_invitation
  from public.invitations i
  join public.trees t on t.id = i.tree_id and t.deleted_at is null
  where i.token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
    and i.deleted_at is null
  for update of i;

  if not found or v_invitation.revoked_at is not null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;
  if v_invitation.expires_at < now() then
    raise exception 'invitation_expired' using errcode = 'P0001';
  end if;

  -- Already a member: nothing to do, and the link isn't used up.
  if public.is_tree_member(v_invitation.tree_id) then
    return v_invitation.tree_id;
  end if;

  if v_invitation.use_count >= v_invitation.max_uses then
    raise exception 'invitation_used_up' using errcode = 'P0001';
  end if;

  insert into public.tree_members (tree_id, user_id, role, invited_by)
  values (v_invitation.tree_id, v_user_id, v_invitation.role, v_invitation.invited_by);

  update public.invitations set use_count = use_count + 1 where id = v_invitation.id;

  -- Auto-claim the named person when that is still possible.
  if v_invitation.person_id is not null
     and exists (
       select 1 from public.persons
       where id = v_invitation.person_id and deleted_at is null
         and is_living and claimed_by_user_id is null
     )
     and not exists (
       select 1 from public.persons
       where tree_id = v_invitation.tree_id and claimed_by_user_id = v_user_id
         and deleted_at is null
     )
  then
    insert into public.claims (tree_id, person_id, user_id, status, invitation_id, reviewed_at)
    values (v_invitation.tree_id, v_invitation.person_id, v_user_id, 'approved',
            v_invitation.id, now())
    returning id into v_claim_id;

    perform set_config('app.change_reason', 'claim:' || v_claim_id, true);
    update public.persons set claimed_by_user_id = v_user_id where id = v_invitation.person_id;
    perform set_config('app.change_reason', '', true);
  end if;

  return v_invitation.tree_id;
end;
$$;

-- Owners and admins approve or reject a claim.
create function public.review_claim(p_claim_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claim public.claims;
  v_user_id uuid := (select auth.uid());
begin
  select * into v_claim from public.claims
  where id = p_claim_id and deleted_at is null
  for update;
  if not found or not public.is_tree_admin(v_claim.tree_id) then
    raise exception 'claim_not_found' using errcode = 'P0002';
  end if;
  if v_claim.status <> 'pending' then
    raise exception 'claim_not_pending' using errcode = 'P0001';
  end if;

  if not p_approve then
    update public.claims
    set status = 'rejected', reviewed_by = v_user_id, reviewed_at = now()
    where id = p_claim_id;
    return;
  end if;

  if not exists (
    select 1 from public.persons
    where id = v_claim.person_id and deleted_at is null and is_living and claimed_by_user_id is null
  ) then
    raise exception 'person_not_claimable' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.tree_members
    where tree_id = v_claim.tree_id and user_id = v_claim.user_id and deleted_at is null
  ) then
    raise exception 'claimant_not_a_member' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.persons
    where tree_id = v_claim.tree_id and claimed_by_user_id = v_claim.user_id and deleted_at is null
  ) then
    raise exception 'claimant_already_claimed_someone' using errcode = 'P0001';
  end if;

  update public.claims
  set status = 'approved', reviewed_by = v_user_id, reviewed_at = now()
  where id = p_claim_id;

  -- Anyone else waiting to claim the same person is turned down.
  update public.claims
  set status = 'rejected', reviewed_by = v_user_id, reviewed_at = now()
  where person_id = v_claim.person_id and status = 'pending' and id <> p_claim_id;

  perform set_config('app.change_reason', 'claim:' || p_claim_id, true);
  update public.persons set claimed_by_user_id = v_claim.user_id where id = v_claim.person_id;
  perform set_config('app.change_reason', '', true);
end;
$$;

-- The claimed person approves or rejects a relative's proposed edit. Approval applies
-- exactly the proposed fields; a JSON null clears that field.
create function public.review_change_request(p_request_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.change_requests;
  v_user_id uuid := (select auth.uid());
  c jsonb;
begin
  select cr.* into v_request
  from public.change_requests cr
  join public.persons p on p.id = cr.person_id
  where cr.id = p_request_id and cr.deleted_at is null
    and p.claimed_by_user_id = v_user_id and p.deleted_at is null
  for update of cr;
  if not found or not public.is_tree_member(v_request.tree_id) then
    raise exception 'change_request_not_found' using errcode = 'P0002';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'change_request_not_pending' using errcode = 'P0001';
  end if;

  update public.change_requests
  set status = case when p_approve then 'approved'::public.request_status
                    else 'rejected'::public.request_status end,
      reviewed_by = v_user_id,
      reviewed_at = now()
  where id = p_request_id;

  if not p_approve then
    return;
  end if;

  c := v_request.proposed_changes;
  perform set_config('app.change_reason', 'change_request:' || p_request_id, true);
  update public.persons p set
    given_names = case when c ? 'given_names' then c ->> 'given_names' else p.given_names end,
    family_name = case when c ? 'family_name' then c ->> 'family_name' else p.family_name end,
    birth_family_name = case when c ? 'birth_family_name'
                             then c ->> 'birth_family_name' else p.birth_family_name end,
    gender = case when c ? 'gender'
                  then (c ->> 'gender')::public.person_gender else p.gender end,
    birth_date = case when c ? 'birth_date' then (c ->> 'birth_date')::date else p.birth_date end,
    birth_date_precision = case when c ? 'birth_date_precision'
                                then (c ->> 'birth_date_precision')::public.fuzzy_precision
                                else p.birth_date_precision end,
    birth_date_end = case when c ? 'birth_date_end'
                          then (c ->> 'birth_date_end')::date else p.birth_date_end end
  where p.id = v_request.person_id;
  perform set_config('app.change_reason', '', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

revoke all on table public.invitations from anon, authenticated;
grant select on table public.invitations to authenticated;
grant update (revoked_at) on table public.invitations to authenticated;

revoke all on table public.claims from anon, authenticated;
grant select on table public.claims to authenticated;
grant insert (tree_id, person_id) on table public.claims to authenticated;
grant update (status) on table public.claims to authenticated;

revoke all on table public.change_requests from anon, authenticated;
grant select on table public.change_requests to authenticated;
grant insert (tree_id, person_id, proposed_changes) on table public.change_requests to authenticated;
grant update (status) on table public.change_requests to authenticated;

revoke execute on function
  public.change_request_fields_valid(jsonb),
  public.create_invitation(uuid, public.tree_role, uuid, integer, integer),
  public.accept_invitation(text),
  public.review_claim(uuid, boolean),
  public.review_change_request(uuid, boolean)
from public, anon;
grant execute on function
  public.change_request_fields_valid(jsonb),
  public.create_invitation(uuid, public.tree_role, uuid, integer, integer),
  public.accept_invitation(text),
  public.review_claim(uuid, boolean),
  public.review_change_request(uuid, boolean)
to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.invitations enable row level security;
alter table public.claims enable row level security;
alter table public.change_requests enable row level security;

-- invitations ----------------------------------------------------------------

-- Only owners and admins can see a tree's invite links (they manage them).
create policy "invitations: admins can read"
  on public.invitations for select to authenticated
  using (deleted_at is null and public.is_tree_admin(tree_id));

-- Owners and admins can revoke an invite link.
create policy "invitations: admins can revoke"
  on public.invitations for update to authenticated
  using (deleted_at is null and public.is_tree_admin(tree_id))
  with check (public.is_tree_admin(tree_id));

-- claims ---------------------------------------------------------------------

-- You can see your own claims; owners and admins can see all claims in their tree.
create policy "claims: claimant or admins can read"
  on public.claims for select to authenticated
  using (
    deleted_at is null
    and public.is_tree_member(tree_id)
    and (user_id = (select auth.uid()) or public.is_tree_admin(tree_id))
  );

-- A member can claim a living, unclaimed person as themselves, if they haven't
-- claimed anyone else in this tree. It stays pending until an owner or admin reviews it.
create policy "claims: members can claim a living unclaimed person"
  on public.claims for insert to authenticated
  with check (
    public.is_tree_member(tree_id)
    and user_id = (select auth.uid())
    and status = 'pending'
    and exists (
      select 1 from public.persons p
      where p.id = person_id and p.deleted_at is null
        and p.is_living and p.claimed_by_user_id is null
    )
    and not exists (
      select 1 from public.persons p
      where p.tree_id = claims.tree_id and p.claimed_by_user_id = (select auth.uid())
        and p.deleted_at is null
    )
  );

-- You can withdraw your own pending claim (and nothing else: approval goes through
-- review_claim).
create policy "claims: claimant can withdraw"
  on public.claims for update to authenticated
  using (deleted_at is null and user_id = (select auth.uid()) and status = 'pending')
  with check (user_id = (select auth.uid()) and status = 'withdrawn');

-- change_requests ------------------------------------------------------------

-- The requester, the claimed person it's about, and owners/admins can see a request.
create policy "change_requests: requester, subject or admins can read"
  on public.change_requests for select to authenticated
  using (
    deleted_at is null
    and public.is_tree_member(tree_id)
    and (
      requested_by = (select auth.uid())
      or public.is_tree_admin(tree_id)
      or exists (
        select 1 from public.persons p
        where p.id = person_id and p.claimed_by_user_id = (select auth.uid())
      )
    )
  );

-- Owners, admins and members propose edits to someone else's claimed profile.
create policy "change_requests: editors can propose for claimed people"
  on public.change_requests for insert to authenticated
  with check (
    public.can_edit_tree(tree_id)
    and requested_by = (select auth.uid())
    and status = 'pending'
    and exists (
      select 1 from public.persons p
      where p.id = person_id and p.deleted_at is null
        and p.claimed_by_user_id is not null
        and p.claimed_by_user_id <> (select auth.uid())
    )
  );

-- The requester can withdraw their own pending request.
create policy "change_requests: requester can withdraw"
  on public.change_requests for update to authenticated
  using (deleted_at is null and requested_by = (select auth.uid()) and status = 'pending')
  with check (requested_by = (select auth.uid()) and status = 'withdrawn');
