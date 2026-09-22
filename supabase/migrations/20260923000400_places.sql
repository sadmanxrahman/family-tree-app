-- Places and which people are connected to them.
--
-- Places belong to one tree (private, like everything else). canonical_place_id holds the
-- geocoding provider's ID for the same real-world place, so relative discovery (v1.2) can
-- match ancestors across families on name + year + place without exposing any family's
-- own rows or needing a migration.
--
-- Privacy (CLAUDE.md): no street addresses (see place_type), no GPS. Coordinates are the
-- place's own centre as returned by the geocoder — a city, a cemetery — never a person's
-- position.

create table public.places (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 200),
  place_type public.place_type not null default 'city',
  -- ISO 3166-1 alpha-2, e.g. GB, BD.
  country_code text check (country_code ~ '^[A-Z]{2}$'),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  -- '<provider>:<id>', e.g. 'geonames:2654993'. Null until geocoded.
  canonical_place_id text check (char_length(canonical_place_id) <= 200),
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint places_tree_id_id_key unique (tree_id, id),
  constraint places_coordinates_together check ((latitude is null) = (longitude is null))
);

comment on table public.places is
  'A tree''s own places. canonical_place_id links to the geocoder''s shared ID for later matching.';

create index places_tree_id_idx on public.places (tree_id) where deleted_at is null;
create index places_canonical_place_id_idx on public.places (canonical_place_id)
  where canonical_place_id is not null and deleted_at is null;
create index places_created_by_idx on public.places (created_by);

create trigger places_set_updated_at
  before update on public.places
  for each row execute function public.set_updated_at();

create table public.person_places (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  person_id uuid not null,
  place_id uuid not null,
  kind public.person_place_kind not null,
  -- e.g. when someone lived somewhere. Birth/death/burial dates live on persons.
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
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict,
  foreign key (tree_id, place_id) references public.places (tree_id, id) on delete restrict,
  constraint person_places_start_date_valid
    check (public.fuzzy_date_is_valid(start_date, start_date_precision, start_date_end)),
  constraint person_places_end_date_valid
    check (public.fuzzy_date_is_valid(end_date, end_date_precision, end_date_end))
);

comment on table public.person_places is
  'Birth, death, burial, residence and home-city places. The map hides persons.hidden_from_map.';

-- A person has at most one current hometown.
create unique index person_places_one_home_city
  on public.person_places (person_id) where kind = 'home_city' and deleted_at is null;
create index person_places_tree_id_idx on public.person_places (tree_id) where deleted_at is null;
create index person_places_person_id_idx on public.person_places (person_id) where deleted_at is null;
create index person_places_place_id_idx on public.person_places (place_id) where deleted_at is null;
create index person_places_created_by_idx on public.person_places (created_by);

create trigger person_places_set_updated_at
  before update on public.person_places
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

revoke all on table public.places from anon, authenticated;
grant select on table public.places to authenticated;
grant insert (tree_id, name, place_type, country_code, latitude, longitude, canonical_place_id)
  on table public.places to authenticated;
grant update (name, place_type, country_code, latitude, longitude, canonical_place_id, deleted_at)
  on table public.places to authenticated;

revoke all on table public.person_places from anon, authenticated;
grant select on table public.person_places to authenticated;
grant insert (
  tree_id, person_id, place_id, kind,
  start_date, start_date_precision, start_date_end,
  end_date, end_date_precision, end_date_end
) on table public.person_places to authenticated;
grant update (
  place_id, kind,
  start_date, start_date_precision, start_date_end,
  end_date, end_date_precision, end_date_end,
  deleted_at
) on table public.person_places to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
--
-- READ RULES AND SOFT DELETE: when an UPDATE sets deleted_at, Postgres re-checks the
-- updated row against the table's SELECT policy. So each SELECT policy lets live rows be
-- seen by every member, and soft-deleted rows only by whoever was allowed to remove
-- them. The UPDATE policies don't require deleted_at IS NULL, so those same people can
-- also restore a row. App queries still filter deleted_at IS NULL (rule 3).
-- ---------------------------------------------------------------------------

alter table public.places enable row level security;
alter table public.person_places enable row level security;

-- Everyone in a tree can see its places; removed ones only by editors.
create policy "places: members can read"
  on public.places for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (deleted_at is null or public.can_edit_tree(tree_id))
  );

-- Owners, admins and members can add places to the tree.
create policy "places: editors can add"
  on public.places for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- Owners, admins and members can correct or remove places.
create policy "places: editors can change"
  on public.places for update to authenticated
  using (public.can_edit_tree(tree_id))
  with check (public.can_edit_tree(tree_id));

-- Everyone in a tree can see who is connected to which place. (The map itself also
-- leaves out people with hidden_from_map set.)
create policy "person_places: members can read"
  on public.person_places for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (deleted_at is null or public.can_edit_person(person_id))
  );

-- Same rule as the person's details: family members can set places (including a
-- city-level hometown) for unclaimed people; a claimed person's places are theirs alone.
-- When someone claims their profile the app shows them any hometown already set so they
-- can change or clear it.
create policy "person_places: whoever can edit the person can add"
  on public.person_places for insert to authenticated
  with check (public.can_edit_person(person_id));

create policy "person_places: whoever can edit the person can change"
  on public.person_places for update to authenticated
  using (public.can_edit_person(person_id))
  with check (public.can_edit_person(person_id));
