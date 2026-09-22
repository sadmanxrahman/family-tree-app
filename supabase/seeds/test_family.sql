-- TEST DATA ONLY — a realistic four-generation family for testing the tree renderer.
-- Not a migration: it never runs in production. Run it in the Supabase SQL Editor.
--
-- BEFORE RUNNING: replace the email on the marked line with the email you sign in to
-- the app with. You become the owner of a new tree called "Test Family (seed)".
--
-- What it contains (19 people, 4 generations):
--   Gen 1  Abdul Karim + Rahima Khatun (Sylhet, both deceased)
--          Harold Whitfield + Edith Whitfield née Clarke (Leeds, both deceased)
--   Gen 2  Mohammed Rahman (deceased) — also recorded as "Md. Rahman", "মোহাম্মদ রহমান", "Moni"
--            m1 Nasima née Chowdhury (deceased 1988, widowed)
--            m2 Margaret née Whitfield (REMARRIAGE, 1991)
--          Amina Begum (deceased), Mohammed's sister
--          David Hughes (deceased): m1 Margaret (divorced 1976), m2 Susan née Patel
--   Gen 3  Farid, Salma (Mohammed + Nasima); Margaret is their STEP-mother
--          Claire (David + Margaret); Mohammed is her STEP-father
--          Tom (David + Susan) — Claire's HALF-brother
--          Jamal (Amina; father UNKNOWN — no edge) — hidden from the map
--          Salma married her first cousin Jamal (COUSIN MARRIAGE: Abdul + Rahima appear
--          once, as grandparents on both sides)
--          Emma née Doyle married Farid
--   Gen 4  Aisha (Salma + Jamal)
--          Leo, ADOPTED by Farid + Emma in 2006; biological parents unknown
--          Maya (Claire; father unknown)
--
-- Every kind of fuzzy date appears at least once: exact, month, year, decade, about,
-- before, after, between.

-- Small helpers, only for this session.
create function pg_temp.person(
  p_tree uuid, p_owner uuid, p_given text, p_family text, p_birth_family text,
  p_gender public.person_gender, p_living boolean,
  p_birth date, p_birth_precision public.fuzzy_precision, p_birth_end date,
  p_death date, p_death_precision public.fuzzy_precision, p_death_end date,
  p_hidden boolean default false
) returns uuid language sql as $$
  insert into public.persons (
    tree_id, created_by, given_names, family_name, birth_family_name, gender, is_living,
    birth_date, birth_date_precision, birth_date_end,
    death_date, death_date_precision, death_date_end, hidden_from_map
  ) values (
    p_tree, p_owner, p_given, p_family, p_birth_family, p_gender, p_living,
    p_birth, p_birth_precision, p_birth_end, p_death, p_death_precision, p_death_end, p_hidden
  ) returning id;
$$;

create function pg_temp.parent(
  p_tree uuid, p_owner uuid, p_parent uuid, p_child uuid, p_kind public.parent_child_kind,
  p_start date default null, p_start_precision public.fuzzy_precision default null
) returns void language sql as $$
  insert into public.parent_child (tree_id, created_by, parent_id, child_id, kind, start_date, start_date_precision)
  values (p_tree, p_owner, p_parent, p_child, p_kind, p_start, p_start_precision);
$$;

create function pg_temp.married(
  p_tree uuid, p_owner uuid, p_a uuid, p_b uuid, p_status public.union_status,
  p_start date, p_start_precision public.fuzzy_precision,
  p_end date default null, p_end_precision public.fuzzy_precision default null
) returns void language sql as $$
  insert into public.unions (tree_id, created_by, person_a_id, person_b_id, kind, status,
                             start_date, start_date_precision, end_date, end_date_precision)
  values (p_tree, p_owner, p_a, p_b, 'marriage', p_status, p_start, p_start_precision, p_end, p_end_precision);
$$;

create function pg_temp.place(
  p_tree uuid, p_owner uuid, p_name text, p_type public.place_type, p_country text,
  p_lat double precision, p_lng double precision
) returns uuid language sql as $$
  insert into public.places (tree_id, created_by, name, place_type, country_code, latitude, longitude)
  values (p_tree, p_owner, p_name, p_type, p_country, p_lat, p_lng)
  returning id;
$$;

create function pg_temp.at(
  p_tree uuid, p_owner uuid, p_person uuid, p_place uuid, p_kind public.person_place_kind,
  p_start date default null, p_start_precision public.fuzzy_precision default null,
  p_end date default null, p_end_precision public.fuzzy_precision default null
) returns void language sql as $$
  insert into public.person_places (tree_id, created_by, person_id, place_id, kind,
                                    start_date, start_date_precision, end_date, end_date_precision)
  values (p_tree, p_owner, p_person, p_place, p_kind, p_start, p_start_precision, p_end, p_end_precision);
$$;

do $$
declare
  -- ▼▼▼ REPLACE WITH THE EMAIL YOU SIGN IN TO THE APP WITH ▼▼▼
  v_email constant text := 'you@example.com';
  -- ▲▲▲ ─────────────────────────────────────────────────────── ▲▲▲

  o uuid;  -- owner (you)
  t uuid;  -- tree

  abdul uuid; rahima uuid; harold uuid; edith uuid;
  mohammed uuid; amina uuid; nasima uuid; margaret uuid; david uuid; susan uuid;
  farid uuid; salma uuid; jamal uuid; claire uuid; tom uuid; emma uuid;
  aisha uuid; leo uuid; maya uuid;

  sylhet uuid; bradford uuid; leeds uuid; london uuid; birmingham uuid;
  undercliffe uuid; lawnswood uuid;

  m1 uuid; m2 uuid; m3 uuid;
begin
  select u.id into o
  from auth.users au
  join public.app_users u on u.id = au.id
  where lower(au.email) = lower(v_email);
  if o is null then
    raise exception 'No account found for %. Sign in to the app with that email first, then edit v_email.', v_email;
  end if;

  if exists (
    select 1 from public.trees
    where created_by = o and name = 'Test Family (seed)' and deleted_at is null
  ) then
    raise exception 'You already have a "Test Family (seed)" tree. Rename or delete it first.';
  end if;

  insert into public.trees (name, created_by) values ('Test Family (seed)', o) returning id into t;
  insert into public.tree_members (tree_id, user_id, role) values (t, o, 'owner');

  -- Places ------------------------------------------------------------------
  sylhet      := pg_temp.place(t, o, 'Sylhet', 'city', 'BD', 24.8949, 91.8687);
  bradford    := pg_temp.place(t, o, 'Bradford', 'city', 'GB', 53.7960, -1.7594);
  leeds       := pg_temp.place(t, o, 'Leeds', 'city', 'GB', 53.8008, -1.5491);
  london      := pg_temp.place(t, o, 'London', 'city', 'GB', 51.5072, -0.1276);
  birmingham  := pg_temp.place(t, o, 'Birmingham', 'city', 'GB', 52.4862, -1.8904);
  undercliffe := pg_temp.place(t, o, 'Undercliffe Cemetery', 'cemetery', 'GB', 53.8076, -1.7390);
  lawnswood   := pg_temp.place(t, o, 'Lawnswood Cemetery', 'cemetery', 'GB', 53.8478, -1.6006);

  -- Generation 1 --------------------------------------------------------------
  abdul  := pg_temp.person(t, o, 'Abdul', 'Karim', null, 'male', false,
                           '1900-01-01', 'decade', null,                 -- born in the 1900s
                           '1968-01-01', 'between', '1972-12-31');       -- died between 1968 and 1972
  rahima := pg_temp.person(t, o, 'Rahima', 'Khatun', null, 'female', false,
                           '1910-01-01', 'about', null,                  -- born about 1910
                           '1985-01-01', 'year', null);
  harold := pg_temp.person(t, o, 'Harold', 'Whitfield', null, 'male', false,
                           '1915-04-12', 'exact', null,
                           '1990-11-01', 'month', null);                 -- died November 1990
  edith  := pg_temp.person(t, o, 'Edith', 'Whitfield', 'Clarke', 'female', false,
                           '1918-01-01', 'year', null,
                           '2003-02-07', 'exact', null);

  perform pg_temp.married(t, o, abdul, rahima, 'widowed', '1932-01-01', 'about');
  perform pg_temp.married(t, o, harold, edith, 'widowed', '1940-06-15', 'exact', '1990-11-01', 'month');

  -- Generation 2 --------------------------------------------------------------
  mohammed := pg_temp.person(t, o, 'Mohammed', 'Rahman', null, 'male', false,
                             '1938-01-01', 'year', null, '2009-09-14', 'exact', null);
  amina    := pg_temp.person(t, o, 'Amina', 'Begum', null, 'female', false,
                             '1942-01-01', 'about', null, '2015-01-01', 'year', null);
  nasima   := pg_temp.person(t, o, 'Nasima', 'Rahman', 'Chowdhury', 'female', false,
                             '1944-01-01', 'year', null, '1988-03-03', 'exact', null);
  margaret := pg_temp.person(t, o, 'Margaret', 'Rahman', 'Whitfield', 'female', true,
                             '1945-08-20', 'exact', null, null, null, null);
  david    := pg_temp.person(t, o, 'David', 'Hughes', null, 'male', false,
                             '1943-01-01', 'year', null, '2001-05-30', 'exact', null);
  susan    := pg_temp.person(t, o, 'Susan', 'Hughes', 'Patel', 'female', true,
                             '1950-01-01', 'year', null, null, null, null);

  perform pg_temp.parent(t, o, abdul, mohammed, 'biological');
  perform pg_temp.parent(t, o, rahima, mohammed, 'biological');
  perform pg_temp.parent(t, o, abdul, amina, 'biological');
  perform pg_temp.parent(t, o, rahima, amina, 'biological');
  perform pg_temp.parent(t, o, harold, margaret, 'biological');
  perform pg_temp.parent(t, o, edith, margaret, 'biological');

  -- The same man, as different relatives wrote him down.
  insert into public.person_names (tree_id, person_id, created_by, name, kind, script) values
    (t, mohammed, o, 'Md. Rahman', 'variant', 'Latn'),
    (t, mohammed, o, 'মোহাম্মদ রহমান', 'variant', 'Beng'),
    (t, mohammed, o, 'Moni', 'nickname', 'Latn'),
    (t, rahima, o, 'রহিমা খাতুন', 'variant', 'Beng'),
    (t, margaret, o, 'Margaret Hughes', 'married', 'Latn');

  perform pg_temp.married(t, o, mohammed, nasima, 'widowed', '1963-01-01', 'year', '1988-03-03', 'exact');
  perform pg_temp.married(t, o, david, margaret, 'divorced', '1970-05-02', 'exact', '1976-01-01', 'year');
  -- REMARRIAGE: both had been married before.
  perform pg_temp.married(t, o, mohammed, margaret, 'widowed', '1991-07-13', 'exact', '2009-09-14', 'exact');
  perform pg_temp.married(t, o, david, susan, 'widowed', '1978-01-01', 'year', '2001-05-30', 'exact');

  -- Generation 3 --------------------------------------------------------------
  farid  := pg_temp.person(t, o, 'Farid', 'Rahman', null, 'male', true,
                           '1966-02-11', 'exact', null, null, null, null);
  salma  := pg_temp.person(t, o, 'Salma', 'Uddin', 'Rahman', 'female', true,
                           '1970-10-01', 'month', null, null, null, null);   -- born October 1970
  jamal  := pg_temp.person(t, o, 'Jamal', 'Uddin', null, 'male', true,
                           '1968-01-01', 'year', null, null, null, null,
                           true);                                            -- hidden from the map
  claire := pg_temp.person(t, o, 'Claire', 'Hughes', null, 'female', true,
                           '1972-01-30', 'exact', null, null, null, null);
  tom    := pg_temp.person(t, o, 'Tom', 'Hughes', null, 'male', true,
                           '1980-06-09', 'exact', null, null, null, null);
  emma   := pg_temp.person(t, o, 'Emma', 'Rahman', 'Doyle', 'female', true,
                           '1969-01-01', 'year', null, null, null, null);

  perform pg_temp.parent(t, o, mohammed, farid, 'biological');
  perform pg_temp.parent(t, o, nasima, farid, 'biological');
  perform pg_temp.parent(t, o, mohammed, salma, 'biological');
  perform pg_temp.parent(t, o, nasima, salma, 'biological');
  -- UNKNOWN PARENTAGE: Jamal's father is not recorded, so he has one parent edge.
  perform pg_temp.parent(t, o, amina, jamal, 'biological');
  perform pg_temp.parent(t, o, david, claire, 'biological');
  perform pg_temp.parent(t, o, margaret, claire, 'biological');
  -- HALF-SIBLINGS: Tom shares only his father with Claire.
  perform pg_temp.parent(t, o, david, tom, 'biological');
  perform pg_temp.parent(t, o, susan, tom, 'biological');
  -- STEP-PARENTS from the 1991 remarriage.
  perform pg_temp.parent(t, o, margaret, farid, 'step', '1991-07-13', 'exact');
  perform pg_temp.parent(t, o, margaret, salma, 'step', '1991-07-13', 'exact');
  perform pg_temp.parent(t, o, mohammed, claire, 'step', '1991-07-13', 'exact');

  -- COUSIN MARRIAGE: Salma (Mohammed's daughter) and Jamal (Amina's son) are first cousins.
  perform pg_temp.married(t, o, salma, jamal, 'current', '1994-12-20', 'exact');
  perform pg_temp.married(t, o, farid, emma, 'current', '1998-01-01', 'year');

  -- Generation 4 --------------------------------------------------------------
  aisha := pg_temp.person(t, o, 'Aisha', 'Uddin', null, 'female', true,
                          '1996-04-02', 'exact', null, null, null, null);
  leo   := pg_temp.person(t, o, 'Leo', 'Rahman', null, 'male', true,
                          '2004-03-15', 'exact', null, null, null, null);
  maya  := pg_temp.person(t, o, 'Maya', 'Hughes', null, 'female', true,
                          '2001-01-01', 'year', null, null, null, null);

  perform pg_temp.parent(t, o, salma, aisha, 'biological');
  perform pg_temp.parent(t, o, jamal, aisha, 'biological');
  -- ADOPTION: Leo's adoptive parents; his biological parents are unknown.
  perform pg_temp.parent(t, o, farid, leo, 'adoptive', '2006-09-01', 'exact');
  perform pg_temp.parent(t, o, emma, leo, 'adoptive', '2006-09-01', 'exact');
  perform pg_temp.parent(t, o, claire, maya, 'biological');

  -- Where people were born, lived and are buried --------------------------------
  perform pg_temp.at(t, o, abdul, sylhet, 'birth');
  perform pg_temp.at(t, o, rahima, sylhet, 'birth');
  perform pg_temp.at(t, o, amina, sylhet, 'birth');
  perform pg_temp.at(t, o, amina, bradford, 'death');
  perform pg_temp.at(t, o, mohammed, sylhet, 'birth');
  -- "Left Sylhet before 26 March 1971": a full-precision 'before' boundary.
  perform pg_temp.at(t, o, mohammed, sylhet, 'residence', null, null, '1971-03-26', 'before');
  -- "Arrived in Bradford after June 1962."
  perform pg_temp.at(t, o, mohammed, bradford, 'residence', '1962-06-30', 'after');
  perform pg_temp.at(t, o, mohammed, bradford, 'death');
  perform pg_temp.at(t, o, mohammed, undercliffe, 'burial');
  perform pg_temp.at(t, o, harold, leeds, 'birth');
  perform pg_temp.at(t, o, harold, lawnswood, 'burial');
  perform pg_temp.at(t, o, edith, lawnswood, 'burial');
  perform pg_temp.at(t, o, margaret, leeds, 'birth');
  perform pg_temp.at(t, o, farid, bradford, 'birth');
  -- City-level hometowns for living relatives (the map). Jamal's is set but he is
  -- hidden from the map.
  perform pg_temp.at(t, o, margaret, leeds, 'home_city');
  perform pg_temp.at(t, o, farid, london, 'home_city');
  perform pg_temp.at(t, o, salma, birmingham, 'home_city');
  perform pg_temp.at(t, o, jamal, birmingham, 'home_city');
  perform pg_temp.at(t, o, claire, leeds, 'home_city');

  -- Memories -------------------------------------------------------------------
  insert into public.memories (tree_id, created_by, kind, title, body,
                               memory_date, memory_date_precision, place_id)
  values (t, o, 'story', 'How Abba came to Bradford',
          'He arrived with one suitcase and an address written on the back of an envelope. '
          || 'The first winter he wore every jumper he owned at once.',
          '1962-01-01', 'year', bradford)
  returning id into m1;
  insert into public.memories (tree_id, created_by, kind, title, body, memory_date, memory_date_precision)
  values (t, o, 'story', 'Grandma Edith''s Sunday dinners',
          'Every Sunday, twelve people round a table built for six.',
          '1950-01-01', 'decade')
  returning id into m2;
  insert into public.memories (tree_id, created_by, kind, title, body,
                               memory_date, memory_date_precision, place_id)
  values (t, o, 'story', 'Salma and Jamal''s wedding',
          'Two families who already knew each other far too well, in one hall in Birmingham.',
          '1994-12-20', 'exact', birmingham)
  returning id into m3;

  insert into public.memory_people (tree_id, created_by, memory_id, person_id) values
    (t, o, m1, mohammed), (t, o, m1, farid), (t, o, m1, salma),
    (t, o, m2, edith), (t, o, m2, harold), (t, o, m2, margaret),
    (t, o, m3, salma), (t, o, m3, jamal), (t, o, m3, amina);

  insert into public.comments (tree_id, memory_id, author_user_id, body)
  values (t, m1, o, 'I still have that envelope somewhere.');
  insert into public.reactions (tree_id, memory_id, user_id, kind)
  values (t, m1, o, 'candle'), (t, m3, o, 'heart');

  raise notice 'Created "Test Family (seed)" with id %', t;
end;
$$;

-- ---------------------------------------------------------------------------
-- Queries to check the result (run them after the block above succeeds)
-- ---------------------------------------------------------------------------
--
-- Every parent-child link, with names and kind:
--
--   select p.given_names || ' ' || p.family_name as parent, pc.kind,
--          c.given_names || ' ' || c.family_name as child
--   from parent_child pc
--   join persons p on p.id = pc.parent_id
--   join persons c on c.id = pc.child_id
--   join trees t on t.id = pc.tree_id and t.name = 'Test Family (seed)'
--   where pc.deleted_at is null
--   order by pc.kind, parent;
--
-- Every union, including the remarriages:
--
--   select a.given_names as a, b.given_names as b, u.status,
--          u.start_date, u.start_date_precision, u.end_date, u.end_date_precision
--   from unions u
--   join persons a on a.id = u.person_a_id
--   join persons b on b.id = u.person_b_id
--   join trees t on t.id = u.tree_id and t.name = 'Test Family (seed)'
--   order by u.start_date;
--
-- The whole graph in the shape the app receives (the SQL Editor bypasses RLS):
--
--   select public.get_tree_graph(id) from trees where name = 'Test Family (seed)';
