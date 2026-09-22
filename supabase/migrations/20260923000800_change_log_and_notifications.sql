-- change_log: every edit to family data, with before/after snapshots, for history and undo.
-- notifications: tells a claimed person when relatives change things that affect them.
--
-- The counterweight to "members can change relationships involving claimed people
-- freely" (estrangement is real): any relationship change touching a claimed person
-- (1) notifies that person, and (2) can be undone by that person themselves, not only by
-- an admin. The notification UI arrives in Phase 4; the data is recorded from now on.

create table public.change_log (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  table_name text not null,
  row_id uuid not null,
  action text not null check (action in ('insert', 'update', 'soft_delete', 'restore')),
  -- Null when the change came from the dashboard or a server job.
  actor_user_id uuid references public.app_users (id) on delete restrict,
  -- Why, when a function knows: 'marked_deceased_claim_released', 'claim:<id>',
  -- 'change_request:<id>', 'undo:<change id>'.
  reason text,
  before jsonb,
  after jsonb,
  -- Set on this entry when it has been undone, pointing at the entry that undid it.
  undone_by_change_id uuid references public.change_log (id) on delete restrict,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.change_log is
  'Append-only history of every change to family data. Written by triggers only.';

create index change_log_tree_id_created_at_idx on public.change_log (tree_id, created_at desc)
  where deleted_at is null;
create index change_log_row_idx on public.change_log (table_name, row_id, created_at desc);
create index change_log_actor_user_id_idx on public.change_log (actor_user_id);
create index change_log_undone_by_change_id_idx on public.change_log (undone_by_change_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  recipient_user_id uuid not null references public.app_users (id) on delete restrict,
  kind public.notification_kind not null,
  change_log_id uuid references public.change_log (id) on delete restrict,
  change_request_id uuid references public.change_requests (id) on delete restrict,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  -- Dismissed.
  deleted_at timestamptz
);

comment on table public.notifications is
  'Per-account notices. Written by triggers only; the recipient marks them read or dismisses them.';

create index notifications_recipient_idx on public.notifications (recipient_user_id, created_at desc)
  where deleted_at is null;
create index notifications_tree_id_idx on public.notifications (tree_id);
create index notifications_change_log_id_idx on public.notifications (change_log_id);
create index notifications_change_request_id_idx on public.notifications (change_request_id);

-- ---------------------------------------------------------------------------
-- Logging trigger
-- ---------------------------------------------------------------------------

-- The person ids a relationship row touches (both sides), from a before/after snapshot.
create function public.relationship_person_ids(p_table text, p_row jsonb)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select case
    when p_row is null then '{}'::uuid[]
    when p_table = 'parent_child' then
      array[(p_row ->> 'parent_id')::uuid, (p_row ->> 'child_id')::uuid]
    when p_table = 'unions' then
      array[(p_row ->> 'person_a_id')::uuid, (p_row ->> 'person_b_id')::uuid]
    else '{}'::uuid[]
  end;
$$;

create function public.log_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before jsonb;
  v_after jsonb := to_jsonb(new);
  v_action text;
  v_change_id uuid;
  v_actor uuid := (select auth.uid());
begin
  if tg_op = 'INSERT' then
    v_action := 'insert';
  else
    v_before := to_jsonb(old);
    -- Nothing but updated_at changed: not worth a history entry.
    if (v_before - 'updated_at') = (v_after - 'updated_at') then
      return null;
    end if;
    if v_before ->> 'deleted_at' is null and v_after ->> 'deleted_at' is not null then
      v_action := 'soft_delete';
    elsif v_before ->> 'deleted_at' is not null and v_after ->> 'deleted_at' is null then
      v_action := 'restore';
    else
      v_action := 'update';
    end if;
  end if;

  insert into public.change_log (tree_id, table_name, row_id, action, actor_user_id, reason, before, after)
  values (
    (v_after ->> 'tree_id')::uuid,
    tg_table_name,
    (v_after ->> 'id')::uuid,
    v_action,
    v_actor,
    nullif(current_setting('app.change_reason', true), ''),
    v_before,
    v_after
  )
  returning id into v_change_id;

  -- Relationship changes notify every claimed person involved, except whoever made it.
  if tg_table_name in ('parent_child', 'unions') then
    insert into public.notifications (tree_id, recipient_user_id, kind, change_log_id)
    select distinct (v_after ->> 'tree_id')::uuid, p.claimed_by_user_id,
      'relationship_changed'::public.notification_kind, v_change_id
    from public.persons p
    where p.id = any (
        public.relationship_person_ids(tg_table_name, v_before)
        || public.relationship_person_ids(tg_table_name, v_after)
      )
      and p.claimed_by_user_id is not null
      and p.claimed_by_user_id is distinct from v_actor;
  end if;

  return null;
end;
$$;

create trigger persons_log after insert or update on public.persons
  for each row execute function public.log_change();
create trigger person_names_log after insert or update on public.person_names
  for each row execute function public.log_change();
create trigger parent_child_log after insert or update on public.parent_child
  for each row execute function public.log_change();
create trigger unions_log after insert or update on public.unions
  for each row execute function public.log_change();
create trigger places_log after insert or update on public.places
  for each row execute function public.log_change();
create trigger person_places_log after insert or update on public.person_places
  for each row execute function public.log_change();
create trigger memories_log after insert or update on public.memories
  for each row execute function public.log_change();
create trigger memory_people_log after insert or update on public.memory_people
  for each row execute function public.log_change();
create trigger media_assets_log after insert or update on public.media_assets
  for each row execute function public.log_change();

-- A claimed person is told when someone proposes an edit to their profile.
create function public.notify_change_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (tree_id, recipient_user_id, kind, change_request_id)
  select new.tree_id, p.claimed_by_user_id, 'change_request_received'::public.notification_kind, new.id
  from public.persons p
  where p.id = new.person_id and p.claimed_by_user_id is not null;
  return null;
end;
$$;

create trigger change_requests_notify
  after insert on public.change_requests
  for each row execute function public.notify_change_request();

-- ---------------------------------------------------------------------------
-- Undo for relationship changes
-- ---------------------------------------------------------------------------

-- Reverses one parent_child or unions change. Allowed for owners and admins, and for any
-- claimed person the relationship touches (before or after the change) — so someone can
-- undo a link a relative drew to them without asking an admin. Refuses if the row has
-- changed since, so an undo never silently overwrites a later edit. Returns the id of
-- the change_log entry recording the undo.
create function public.undo_relationship_change(p_change_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_change public.change_log;
  v_user_id uuid := (select auth.uid());
  v_current jsonb;
  v_undo_id uuid;
begin
  select * into v_change from public.change_log
  where id = p_change_id and deleted_at is null
  for update;
  if not found
     or v_change.table_name not in ('parent_child', 'unions')
     or not public.is_tree_member(v_change.tree_id) then
    raise exception 'change_not_found' using errcode = 'P0002';
  end if;
  if v_change.undone_by_change_id is not null then
    raise exception 'change_already_undone' using errcode = 'P0001';
  end if;

  if not (
    public.is_tree_admin(v_change.tree_id)
    or exists (
      select 1 from public.persons p
      where p.id = any (
          public.relationship_person_ids(v_change.table_name, v_change.before)
          || public.relationship_person_ids(v_change.table_name, v_change.after)
        )
        and p.claimed_by_user_id = v_user_id
        and p.deleted_at is null
    )
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_change.table_name = 'parent_child' then
    select to_jsonb(pc) into v_current from public.parent_child pc where pc.id = v_change.row_id;
  else
    select to_jsonb(u) into v_current from public.unions u where u.id = v_change.row_id;
  end if;
  if (v_current - 'updated_at') is distinct from (v_change.after - 'updated_at') then
    raise exception 'changed_since' using errcode = 'P0001',
      detail = 'This relationship was changed again afterwards. Undo the later change first.';
  end if;

  perform set_config('app.change_reason', 'undo:' || p_change_id, true);

  if v_change.action in ('insert', 'restore') then
    -- Undo adding: remove it again.
    if v_change.table_name = 'parent_child' then
      update public.parent_child set deleted_at = now() where id = v_change.row_id;
    else
      update public.unions set deleted_at = now() where id = v_change.row_id;
    end if;
  elsif v_change.action = 'soft_delete' then
    -- Undo removing: bring it back.
    if v_change.table_name = 'parent_child' then
      update public.parent_child set deleted_at = null where id = v_change.row_id;
    else
      update public.unions set deleted_at = null where id = v_change.row_id;
    end if;
  else
    -- Undo an edit: put the editable fields back as they were.
    if v_change.table_name = 'parent_child' then
      update public.parent_child t set
        (kind, start_date, start_date_precision, start_date_end,
         end_date, end_date_precision, end_date_end) =
        (select r.kind, r.start_date, r.start_date_precision, r.start_date_end,
                r.end_date, r.end_date_precision, r.end_date_end
         from jsonb_populate_record(null::public.parent_child, v_change.before) r)
      where t.id = v_change.row_id;
    else
      update public.unions t set
        (kind, status, start_date, start_date_precision, start_date_end,
         end_date, end_date_precision, end_date_end) =
        (select r.kind, r.status, r.start_date, r.start_date_precision, r.start_date_end,
                r.end_date, r.end_date_precision, r.end_date_end
         from jsonb_populate_record(null::public.unions, v_change.before) r)
      where t.id = v_change.row_id;
    end if;
  end if;

  perform set_config('app.change_reason', '', true);

  select id into v_undo_id from public.change_log
  where table_name = v_change.table_name and row_id = v_change.row_id
    and reason = 'undo:' || p_change_id
  order by created_at desc
  limit 1;

  update public.change_log set undone_by_change_id = v_undo_id where id = p_change_id;
  return v_undo_id;
end;
$$;

revoke execute on function
  public.relationship_person_ids(text, jsonb),
  public.log_change(),
  public.notify_change_request(),
  public.undo_relationship_change(uuid)
from public, anon, authenticated;
grant execute on function public.undo_relationship_change(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Privileges and row-level security
-- ---------------------------------------------------------------------------

revoke all on table public.change_log from anon, authenticated;
grant select on table public.change_log to authenticated;

revoke all on table public.notifications from anon, authenticated;
grant select on table public.notifications to authenticated;
grant update (read_at, deleted_at) on table public.notifications to authenticated;

alter table public.change_log enable row level security;
alter table public.notifications enable row level security;

-- Everyone in a tree can see its history (that is what makes undo trustworthy).
-- Nobody can write to it: triggers do.
create policy "change_log: members can read"
  on public.change_log for select to authenticated
  using (deleted_at is null and public.is_tree_member(tree_id));

-- You see only your own notifications (including dismissed ones, which the app filters
-- out), and only for trees you still belong to.
create policy "notifications: recipient can read"
  on public.notifications for select to authenticated
  using (recipient_user_id = (select auth.uid()) and public.is_tree_member(tree_id));

-- You can mark your own notifications read or dismiss them.
create policy "notifications: recipient can mark read or dismiss"
  on public.notifications for update to authenticated
  using (recipient_user_id = (select auth.uid()))
  with check (recipient_user_id = (select auth.uid()));
