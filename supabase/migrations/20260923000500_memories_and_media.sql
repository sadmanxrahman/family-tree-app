-- Memories (stories, photos, video, audio), the people in them, and their media files.
--
-- Files live in the private 'media' storage bucket under '<tree_id>/...', so storage
-- access is decided by the same tree membership as the rows.

create table public.memories (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  kind public.memory_kind not null,
  title text check (char_length(title) <= 200),
  body text check (char_length(body) <= 50000),
  -- When the memory happened, e.g. "summer 1962" as month or year precision.
  memory_date date,
  memory_date_precision public.fuzzy_precision,
  memory_date_end date,
  place_id uuid,
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint memories_tree_id_id_key unique (tree_id, id),
  foreign key (tree_id, place_id) references public.places (tree_id, id) on delete restrict,
  constraint memories_date_valid
    check (public.fuzzy_date_is_valid(memory_date, memory_date_precision, memory_date_end))
);

comment on table public.memories is 'A story, photo set, video or audio recording.';

create index memories_tree_id_created_at_idx on public.memories (tree_id, created_at desc)
  where deleted_at is null;
create index memories_place_id_idx on public.memories (place_id);
create index memories_created_by_idx on public.memories (created_by);

create trigger memories_set_updated_at
  before update on public.memories
  for each row execute function public.set_updated_at();

create table public.memory_people (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  memory_id uuid not null,
  person_id uuid not null,
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, memory_id) references public.memories (tree_id, id) on delete restrict,
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict
);

comment on table public.memory_people is 'Which persons a memory is about (tags).';

create unique index memory_people_active_unique
  on public.memory_people (memory_id, person_id) where deleted_at is null;
create index memory_people_tree_id_idx on public.memory_people (tree_id) where deleted_at is null;
create index memory_people_person_id_idx on public.memory_people (person_id) where deleted_at is null;
create index memory_people_created_by_idx on public.memory_people (created_by);

create trigger memory_people_set_updated_at
  before update on public.memory_people
  for each row execute function public.set_updated_at();

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  -- Null for files not attached to a memory, e.g. a profile photo.
  memory_id uuid,
  -- Paths inside the 'media' bucket; must start with '<tree_id>/'.
  storage_path text not null unique check (char_length(storage_path) <= 500),
  thumbnail_path text check (char_length(thumbnail_path) <= 500),
  mime_type text not null check (mime_type ~ '^(image|video|audio)/[a-z0-9.+-]+$'),
  byte_size bigint check (byte_size >= 0),
  width integer check (width > 0),
  height integer check (height > 0),
  duration_ms integer check (duration_ms >= 0),
  sort_order integer not null default 0,
  created_by uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint media_assets_tree_id_id_key unique (tree_id, id),
  foreign key (tree_id, memory_id) references public.memories (tree_id, id) on delete restrict,
  constraint media_assets_path_in_tree_folder
    check (storage_path like tree_id::text || '/%'
           and (thumbnail_path is null or thumbnail_path like tree_id::text || '/%'))
);

comment on table public.media_assets is
  'Files in the private media bucket. Compressed and thumbnailed on device before upload.';

create index media_assets_tree_id_idx on public.media_assets (tree_id) where deleted_at is null;
create index media_assets_memory_id_idx on public.media_assets (memory_id, sort_order)
  where deleted_at is null;
create index media_assets_created_by_idx on public.media_assets (created_by);

create trigger media_assets_set_updated_at
  before update on public.media_assets
  for each row execute function public.set_updated_at();

-- persons.profile_media_id was declared before media_assets existed.
alter table public.persons
  add constraint persons_profile_media_fkey
  foreign key (tree_id, profile_media_id) references public.media_assets (tree_id, id)
  on delete restrict;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

revoke all on table public.memories from anon, authenticated;
grant select on table public.memories to authenticated;
grant insert (tree_id, kind, title, body, memory_date, memory_date_precision, memory_date_end, place_id)
  on table public.memories to authenticated;
grant update (kind, title, body, memory_date, memory_date_precision, memory_date_end, place_id, deleted_at)
  on table public.memories to authenticated;

revoke all on table public.memory_people from anon, authenticated;
grant select on table public.memory_people to authenticated;
grant insert (tree_id, memory_id, person_id) on table public.memory_people to authenticated;
grant update (deleted_at) on table public.memory_people to authenticated;

revoke all on table public.media_assets from anon, authenticated;
grant select on table public.media_assets to authenticated;
grant insert (
  tree_id, memory_id, storage_path, thumbnail_path, mime_type,
  byte_size, width, height, duration_ms, sort_order
) on table public.media_assets to authenticated;
grant update (memory_id, sort_order, deleted_at) on table public.media_assets to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
--
-- READ RULES AND SOFT DELETE: when an UPDATE sets deleted_at, Postgres re-checks the
-- updated row against the table's SELECT policy. So each SELECT policy lets live rows be
-- seen by every member, and soft-deleted rows only by whoever was allowed to remove
-- them. The UPDATE policies don't require deleted_at IS NULL, so those same people can
-- also restore a row. App queries still filter deleted_at IS NULL (rule 3).
-- ---------------------------------------------------------------------------

alter table public.memories enable row level security;
alter table public.memory_people enable row level security;
alter table public.media_assets enable row level security;

-- Everyone in a tree can see its memories; a removed memory only its author and admins.
create policy "memories: members can read"
  on public.memories for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (
      deleted_at is null
      or created_by = (select auth.uid())
      or public.is_tree_admin(tree_id)
    )
  );

-- Owners, admins and members can add memories, as themselves.
create policy "memories: editors can add"
  on public.memories for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- A memory is someone's own telling: only its author can edit it. Owners and admins can
-- also change it (e.g. to remove it) for moderation.
create policy "memories: author or admins can change"
  on public.memories for update to authenticated
  using (
    ((created_by = (select auth.uid()) and public.can_edit_tree(tree_id))
         or public.is_tree_admin(tree_id))
  )
  with check (public.is_tree_member(tree_id));

-- Everyone in a tree can see who is tagged in its memories; removed tags only editors
-- and the person who was tagged.
create policy "memory_people: members can read"
  on public.memory_people for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (
      deleted_at is null
      or public.can_edit_tree(tree_id)
      or exists (
        select 1 from public.persons p
        where p.id = person_id and p.claimed_by_user_id = (select auth.uid())
      )
    )
  );

-- Owners, admins and members can tag anyone in a memory.
create policy "memory_people: editors can tag"
  on public.memory_people for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- A tag can be removed by whoever added it, the memory's author, owners and admins —
-- and by the tagged person themselves if they have claimed their profile.
create policy "memory_people: taggers, authors, admins or the person can untag"
  on public.memory_people for update to authenticated
  using (
    public.is_tree_member(tree_id)
    and (
      created_by = (select auth.uid())
      or public.is_tree_admin(tree_id)
      or exists (
        select 1 from public.memories m
        where m.id = memory_id and m.created_by = (select auth.uid())
      )
      or exists (
        select 1 from public.persons p
        where p.id = person_id and p.claimed_by_user_id = (select auth.uid())
      )
    )
  )
  with check (public.is_tree_member(tree_id));

-- Everyone in a tree can see its media records; removed ones only the uploader and admins.
create policy "media_assets: members can read"
  on public.media_assets for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (
      deleted_at is null
      or created_by = (select auth.uid())
      or public.is_tree_admin(tree_id)
    )
  );

-- Owners, admins and members can add media, as themselves.
create policy "media_assets: editors can add"
  on public.media_assets for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- Whoever uploaded a file, and owners and admins, can reorder or remove it.
create policy "media_assets: uploader or admins can change"
  on public.media_assets for update to authenticated
  using (
    ((created_by = (select auth.uid()) and public.can_edit_tree(tree_id))
         or public.is_tree_admin(tree_id))
  )
  with check (public.is_tree_member(tree_id));

-- ---------------------------------------------------------------------------
-- Storage: the private 'media' bucket
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media', 'media', false,
  -- Video is the largest; images are compressed to ~300 KB on device (CLAUDE.md rule 8).
  52428800,
  array['image/*', 'video/*', 'audio/*']
)
on conflict (id) do nothing;

-- The tree a storage object belongs to: its first folder, when that is a UUID.
create function public.tree_id_from_storage_path(p_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid
  end;
$$;

revoke execute on function public.tree_id_from_storage_path(text) from public, anon;
grant execute on function public.tree_id_from_storage_path(text) to authenticated;

-- Members of a tree can download the files in its folder.
create policy "media bucket: tree members can read"
  on storage.objects for select to authenticated
  using (bucket_id = 'media' and public.is_tree_member(public.tree_id_from_storage_path(name)));

-- Owners, admins and members can upload into their tree's folder.
create policy "media bucket: tree editors can upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.can_edit_tree(public.tree_id_from_storage_path(name)));

-- No update or delete policies: files are never overwritten or hard-deleted from the app.
-- Removing a photo soft-deletes its media_assets row.
