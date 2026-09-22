-- The family feed, and comments and reactions on memories.
--
-- Feed events are written only by triggers, never by the app, so nobody can post a fake
-- "X joined" or "Y added a memory".

create table public.feed_events (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null references public.trees (id) on delete restrict,
  kind public.feed_event_kind not null,
  -- Null when the change came from the dashboard or a server job.
  actor_user_id uuid references public.app_users (id) on delete restrict,
  person_id uuid,
  memory_id uuid,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, person_id) references public.persons (tree_id, id) on delete restrict,
  foreign key (tree_id, memory_id) references public.memories (tree_id, id) on delete restrict
);

comment on table public.feed_events is 'What happened in a tree, newest first. Written by triggers only.';

create index feed_events_tree_id_created_at_idx on public.feed_events (tree_id, created_at desc)
  where deleted_at is null;
create index feed_events_actor_user_id_idx on public.feed_events (actor_user_id);
create index feed_events_person_id_idx on public.feed_events (person_id);
create index feed_events_memory_id_idx on public.feed_events (memory_id);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  memory_id uuid not null,
  author_user_id uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  body text not null check (char_length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  foreign key (tree_id, memory_id) references public.memories (tree_id, id) on delete restrict
);

comment on table public.comments is 'Comments on memories.';

create index comments_memory_id_created_at_idx on public.comments (memory_id, created_at)
  where deleted_at is null;
create index comments_tree_id_idx on public.comments (tree_id) where deleted_at is null;
create index comments_author_user_id_idx on public.comments (author_user_id);

create trigger comments_set_updated_at
  before update on public.comments
  for each row execute function public.set_updated_at();

-- Admins may remove a comment for moderation, but never reword someone else's words.
create function public.comments_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.body is distinct from old.body
     and old.author_user_id is distinct from (select auth.uid())
     and (select auth.uid()) is not null then
    raise exception 'only_the_author_can_edit_a_comment' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger comments_guard
  before update on public.comments
  for each row execute function public.comments_guard();

create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  tree_id uuid not null,
  memory_id uuid not null,
  user_id uuid not null default auth.uid() references public.app_users (id) on delete restrict,
  kind public.reaction_kind not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Un-reacting sets this; reacting again creates a new row.
  deleted_at timestamptz,
  foreign key (tree_id, memory_id) references public.memories (tree_id, id) on delete restrict
);

comment on table public.reactions is 'Reactions on memories. One of each kind per account per memory.';

create unique index reactions_active_unique
  on public.reactions (memory_id, user_id, kind) where deleted_at is null;
create index reactions_tree_id_idx on public.reactions (tree_id) where deleted_at is null;
create index reactions_user_id_idx on public.reactions (user_id);

create trigger reactions_set_updated_at
  before update on public.reactions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Feed triggers
-- ---------------------------------------------------------------------------

create function public.feed_on_person_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.feed_events (tree_id, kind, actor_user_id, person_id)
    values (new.tree_id, 'person_added', coalesce((select auth.uid()), new.created_by), new.id);
    return null;
  end if;

  if old.is_living and not new.is_living then
    insert into public.feed_events (tree_id, kind, actor_user_id, person_id)
    values (new.tree_id, 'person_marked_deceased', (select auth.uid()), new.id);
  end if;

  if old.claimed_by_user_id is null and new.claimed_by_user_id is not null then
    insert into public.feed_events (tree_id, kind, actor_user_id, person_id)
    values (new.tree_id, 'person_claimed', new.claimed_by_user_id, new.id);
  end if;

  return null;
end;
$$;

create trigger persons_feed
  after insert or update of is_living, claimed_by_user_id on public.persons
  for each row execute function public.feed_on_person_change();

create function public.feed_on_memory_added()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.feed_events (tree_id, kind, actor_user_id, memory_id)
  values (new.tree_id, 'memory_added', coalesce((select auth.uid()), new.created_by), new.id);
  return null;
end;
$$;

create trigger memories_feed
  after insert on public.memories
  for each row execute function public.feed_on_memory_added();

create function public.feed_on_member_joined()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The owner "joining" their own new tree isn't news.
  if new.role <> 'owner' then
    insert into public.feed_events (tree_id, kind, actor_user_id)
    values (new.tree_id, 'member_joined', new.user_id);
  end if;
  return null;
end;
$$;

create trigger tree_members_feed
  after insert on public.tree_members
  for each row execute function public.feed_on_member_joined();

revoke execute on function
  public.comments_guard(),
  public.feed_on_person_change(),
  public.feed_on_memory_added(),
  public.feed_on_member_joined()
from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

revoke all on table public.feed_events from anon, authenticated;
grant select on table public.feed_events to authenticated;

revoke all on table public.comments from anon, authenticated;
grant select on table public.comments to authenticated;
grant insert (tree_id, memory_id, body) on table public.comments to authenticated;
grant update (body, deleted_at) on table public.comments to authenticated;

revoke all on table public.reactions from anon, authenticated;
grant select on table public.reactions to authenticated;
grant insert (tree_id, memory_id, kind) on table public.reactions to authenticated;
grant update (deleted_at) on table public.reactions to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
--
-- READ RULES AND SOFT DELETE: when an UPDATE sets deleted_at, Postgres re-checks the
-- updated row against the table's SELECT policy. So each SELECT policy lets live rows be
-- seen by every member, and soft-deleted rows only by whoever was allowed to remove
-- them. The UPDATE policies don't require deleted_at IS NULL, so those same people can
-- also restore a row. App queries still filter deleted_at IS NULL (rule 3).
-- ---------------------------------------------------------------------------

alter table public.feed_events enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;

-- Everyone in a tree sees its feed. Nobody can write to it (triggers do).
create policy "feed_events: members can read"
  on public.feed_events for select to authenticated
  using (deleted_at is null and public.is_tree_member(tree_id));

-- Everyone in a tree can read comments on its memories; a removed comment only its
-- author and admins.
create policy "comments: members can read"
  on public.comments for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (
      deleted_at is null
      or author_user_id = (select auth.uid())
      or public.is_tree_admin(tree_id)
    )
  );

-- Owners, admins and members can comment, as themselves. Viewers only read.
create policy "comments: editors can comment"
  on public.comments for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- Authors can edit or remove their own comments; owners and admins can remove any
-- comment (comments_guard stops them rewording it).
create policy "comments: author or admins can change"
  on public.comments for update to authenticated
  using (
    ((author_user_id = (select auth.uid()) and public.is_tree_member(tree_id))
         or public.is_tree_admin(tree_id))
  )
  with check (public.is_tree_member(tree_id));

-- Everyone in a tree can see reactions on its memories; a withdrawn one only its owner.
create policy "reactions: members can read"
  on public.reactions for select to authenticated
  using (
    public.is_tree_member(tree_id)
    and (deleted_at is null or user_id = (select auth.uid()))
  );

-- Owners, admins and members can react, as themselves.
create policy "reactions: editors can react"
  on public.reactions for insert to authenticated
  with check (public.can_edit_tree(tree_id));

-- You can take back your own reaction.
create policy "reactions: owner of the reaction can remove it"
  on public.reactions for update to authenticated
  using (user_id = (select auth.uid()) and public.is_tree_member(tree_id))
  with check (user_id = (select auth.uid()));
