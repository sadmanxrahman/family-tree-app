-- get_tree_graph: everything the tree renderer needs, in one round trip.
--
-- SECURITY INVOKER on purpose: it runs with the caller's own row-level security, so a
-- non-member gets empty lists rather than someone else's family. Soft-deleted persons
-- are left out, and so is any edge whose person on either end is soft-deleted.
--
-- Shape (see src/types/treeGraph.ts):
--   { tree_id, persons: [...], parent_child: [...], unions: [...] }
-- Fuzzy dates are returned as { date, precision, end } objects, or null.

create function public.fuzzy_date_json(p_date date, p_precision public.fuzzy_precision, p_end date)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when p_date is null then null
    else jsonb_build_object('date', p_date, 'precision', p_precision, 'end', p_end)
  end;
$$;

create function public.get_tree_graph(p_tree_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with live_persons as (
    select * from public.persons
    where tree_id = p_tree_id and deleted_at is null
  )
  select jsonb_build_object(
    'tree_id', p_tree_id,
    'persons', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'given_names', p.given_names,
          'family_name', p.family_name,
          'birth_family_name', p.birth_family_name,
          'gender', p.gender,
          'is_living', p.is_living,
          'birth', public.fuzzy_date_json(p.birth_date, p.birth_date_precision, p.birth_date_end),
          'death', public.fuzzy_date_json(p.death_date, p.death_date_precision, p.death_date_end),
          'is_claimed', p.claimed_by_user_id is not null,
          'profile_media_id', p.profile_media_id
        )
        order by p.birth_date nulls last, p.id
      )
      from live_persons p
    ), '[]'::jsonb),
    'parent_child', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', pc.id,
          'parent_id', pc.parent_id,
          'child_id', pc.child_id,
          'kind', pc.kind,
          'start', public.fuzzy_date_json(pc.start_date, pc.start_date_precision, pc.start_date_end),
          'end', public.fuzzy_date_json(pc.end_date, pc.end_date_precision, pc.end_date_end)
        )
        order by pc.id
      )
      from public.parent_child pc
      where pc.tree_id = p_tree_id
        and pc.deleted_at is null
        and pc.parent_id in (select id from live_persons)
        and pc.child_id in (select id from live_persons)
    ), '[]'::jsonb),
    'unions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', u.id,
          'person_a_id', u.person_a_id,
          'person_b_id', u.person_b_id,
          'kind', u.kind,
          'status', u.status,
          'start', public.fuzzy_date_json(u.start_date, u.start_date_precision, u.start_date_end),
          'end', public.fuzzy_date_json(u.end_date, u.end_date_precision, u.end_date_end)
        )
        order by u.start_date nulls last, u.id
      )
      from public.unions u
      where u.tree_id = p_tree_id
        and u.deleted_at is null
        and u.person_a_id in (select id from live_persons)
        and u.person_b_id in (select id from live_persons)
    ), '[]'::jsonb)
  );
$$;

comment on function public.get_tree_graph(uuid) is
  'All live persons, parent-child edges and unions of a tree, as JSON. Empty for non-members.';

revoke execute on function public.fuzzy_date_json(date, public.fuzzy_precision, date) from public, anon;
grant execute on function public.fuzzy_date_json(date, public.fuzzy_precision, date) to authenticated;
revoke execute on function public.get_tree_graph(uuid) from public, anon;
grant execute on function public.get_tree_graph(uuid) to authenticated;
