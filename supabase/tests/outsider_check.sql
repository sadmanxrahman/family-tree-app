-- ACCEPTANCE CHECK: a signed-in account that is NOT a member of any tree must see zero
-- rows in every family-data table, zero storage files, and an empty get_tree_graph().
--
-- Safe to run against the live project: everything happens in one transaction that is
-- ROLLED BACK at the end, including the throwaway outsider account.
--
-- Run:  npx supabase db query --linked -f supabase/tests/outsider_check.sql
-- Needs the seed family (supabase/seeds/test_family.sql) so the tables aren't empty —
-- otherwise "0 rows" would prove nothing. The total_rows column shows that.

begin;

-- A real new account through Supabase Auth's own table; the signup trigger gives it an
-- app_users row. Confirmed adult, so the 18+ gate isn't what hides anything.
insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-4000-8000-00000000abcd', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'outsider-check@example.invalid', '{}'::jsonb, now(), now());
update public.app_users set age_confirmed_at = now()
where id = '00000000-0000-4000-8000-00000000abcd';

-- The seed has no invitations, claims, change requests, notifications, media or files,
-- and "0 rows from an empty table" proves nothing. Add one of each to the seed tree
-- (rolled back with everything else).
do $$
declare
  v_tree uuid;
  v_owner uuid;
  v_person uuid;
  v_claimed uuid;
  v_memory uuid;
begin
  select id, created_by into v_tree, v_owner from public.trees
  where name = 'Test Family (seed)' and deleted_at is null limit 1;
  if v_tree is null then
    raise exception 'Seed tree not found: run supabase/seeds/test_family.sql first.';
  end if;
  select id into v_person from public.persons
  where tree_id = v_tree and is_living and claimed_by_user_id is null and deleted_at is null
  order by birth_date limit 1;
  select id into v_memory from public.memories where tree_id = v_tree limit 1;

  insert into public.invitations (tree_id, token_hash, invited_by, expires_at)
  values (v_tree, encode(sha256('outsider-check'::bytea), 'hex'), v_owner, now() + interval '1 day');

  -- The owner claims one living person, so a relative's change request can target them.
  update public.persons set claimed_by_user_id = v_owner where id = v_person;
  v_claimed := v_person;
  insert into public.claims (tree_id, person_id, user_id, status)
  values (v_tree, v_claimed, v_owner, 'approved');
  insert into public.change_requests (tree_id, person_id, requested_by, proposed_changes)
  values (v_tree, v_claimed, v_owner, '{"family_name": "Check"}');  -- also creates a notification

  insert into storage.objects (bucket_id, name) values ('media', v_tree || '/outsider-check.jpg');
  insert into public.media_assets (tree_id, memory_id, storage_path, mime_type, created_by)
  values (v_tree, v_memory, v_tree || '/outsider-check.jpg', 'image/jpeg', v_owner);
end;
$$;

create temp table outsider_check (
  check_name text primary key,
  total_rows bigint,      -- what really exists (database owner's view)
  outsider_sees bigint,   -- what the outsider's API session can read
  result text
) on commit drop;
grant select, insert, update on outsider_check to authenticated;

-- Ground truth, as the database owner.
do $$
declare
  t text;
  n bigint;
begin
  foreach t in array array[
    'trees', 'tree_members', 'persons', 'person_names', 'parent_child', 'unions', 'places',
    'person_places', 'memories', 'memory_people', 'media_assets', 'invitations', 'claims',
    'change_requests', 'feed_events', 'comments', 'reactions', 'change_log', 'notifications'
  ] loop
    execute format('select count(*) from public.%I', t) into n;
    insert into outsider_check (check_name, total_rows) values ('public.' || t, n);
  end loop;
end;
$$;
insert into outsider_check (check_name, total_rows)
select 'storage.objects (media bucket)', count(*) from storage.objects where bucket_id = 'media';
insert into outsider_check (check_name, total_rows)
select 'get_tree_graph(seed tree): persons', count(*)
from public.persons p join public.trees t on t.id = p.tree_id
where t.name = 'Test Family (seed)' and p.deleted_at is null;

-- Remember the seed tree's id before switching identity (the outsider can't look it up).
select set_config('check.seed_tree_id',
  coalesce((select id::text from public.trees where name = 'Test Family (seed)' limit 1), ''), true);

-- Become the outsider exactly as PostgREST does for a signed-in request.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000abcd","role":"authenticated","aud":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-00000000abcd', true);

update outsider_check set outsider_sees = (select count(*) from public.trees) where check_name = 'public.trees';
update outsider_check set outsider_sees = (select count(*) from public.tree_members) where check_name = 'public.tree_members';
update outsider_check set outsider_sees = (select count(*) from public.persons) where check_name = 'public.persons';
update outsider_check set outsider_sees = (select count(*) from public.person_names) where check_name = 'public.person_names';
update outsider_check set outsider_sees = (select count(*) from public.parent_child) where check_name = 'public.parent_child';
update outsider_check set outsider_sees = (select count(*) from public.unions) where check_name = 'public.unions';
update outsider_check set outsider_sees = (select count(*) from public.places) where check_name = 'public.places';
update outsider_check set outsider_sees = (select count(*) from public.person_places) where check_name = 'public.person_places';
update outsider_check set outsider_sees = (select count(*) from public.memories) where check_name = 'public.memories';
update outsider_check set outsider_sees = (select count(*) from public.memory_people) where check_name = 'public.memory_people';
update outsider_check set outsider_sees = (select count(*) from public.media_assets) where check_name = 'public.media_assets';
update outsider_check set outsider_sees = (select count(*) from public.invitations) where check_name = 'public.invitations';
update outsider_check set outsider_sees = (select count(*) from public.claims) where check_name = 'public.claims';
update outsider_check set outsider_sees = (select count(*) from public.change_requests) where check_name = 'public.change_requests';
update outsider_check set outsider_sees = (select count(*) from public.feed_events) where check_name = 'public.feed_events';
update outsider_check set outsider_sees = (select count(*) from public.comments) where check_name = 'public.comments';
update outsider_check set outsider_sees = (select count(*) from public.reactions) where check_name = 'public.reactions';
update outsider_check set outsider_sees = (select count(*) from public.change_log) where check_name = 'public.change_log';
update outsider_check set outsider_sees = (select count(*) from public.notifications) where check_name = 'public.notifications';
update outsider_check set outsider_sees = (select count(*) from storage.objects where bucket_id = 'media')
  where check_name = 'storage.objects (media bucket)';
update outsider_check
  set outsider_sees = coalesce(jsonb_array_length(
        public.get_tree_graph(nullif(current_setting('check.seed_tree_id', true), '')::uuid) -> 'persons'), -1),
      result = public.get_tree_graph(nullif(current_setting('check.seed_tree_id', true), '')::uuid)::text
  where check_name = 'get_tree_graph(seed tree): persons';

reset role;

update outsider_check
set result = case
  when outsider_sees = 0 and total_rows > 0 then 'PASS'
  when outsider_sees = 0 and total_rows = 0 then 'EMPTY TABLE (proves nothing)'
  else 'FAIL'
end || coalesce(' ' || result, '');

select check_name, total_rows, outsider_sees, result from outsider_check order by check_name;

rollback;
