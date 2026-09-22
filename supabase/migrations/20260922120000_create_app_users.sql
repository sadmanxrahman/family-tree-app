-- app_users: the public-schema profile for each account (a row in auth.users).
--
-- auth.users is owned by Supabase Auth and is not reachable through the API, so app
-- data that needs to reference "the account" references this table instead.
--
-- Deliberately NOT mirrored: email, phone, provider details. They stay in auth.users,
-- where only the account holder and the service role can read them. Copying them here
-- would make it too easy for a future policy to leak them to relatives.

create table public.app_users (
  -- ON DELETE RESTRICT rather than CASCADE: nothing is hard-deleted (CLAUDE.md rule 3).
  -- Account deletion will anonymize this row through its own flow; until that exists,
  -- deleting an auth user out from under it should fail loudly, not silently cascade.
  id uuid primary key references auth.users (id) on delete restrict,
  display_name text check (char_length(display_name) <= 100),
  -- When the account holder confirmed they are 18 or older (no under-18 accounts in v1.0).
  -- Set only through public.confirm_adult(), so the client cannot choose the value.
  age_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.app_users is
  'Public profile for each account. One row per auth.users row, created by trigger on signup.';

-- ---------------------------------------------------------------------------
-- Keep updated_at honest without trusting the client to send it.
-- ---------------------------------------------------------------------------
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger app_users_set_updated_at
  before update on public.app_users
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Create the profile row whenever Supabase Auth creates an account.
-- SECURITY DEFINER because the signing-up user has no INSERT permission here; the
-- empty search_path stops anyone shadowing public.app_users with their own object.
-- ---------------------------------------------------------------------------
create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.app_users (id, display_name)
  values (
    new.id,
    -- Google sends full_name/name. Apple's native flow sends neither, so the app fills
    -- the name in after sign-in. Truncated so an odd provider value can never block signup.
    left(
      nullif(
        trim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')),
        ''
      ),
      100
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ---------------------------------------------------------------------------
-- Record the 18+ confirmation. Idempotent: the first confirmation time is kept.
-- ---------------------------------------------------------------------------
create function public.confirm_adult()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.app_users
  set age_confirmed_at = now()
  where id = (select auth.uid())
    and age_confirmed_at is null
    and deleted_at is null;
$$;

-- ---------------------------------------------------------------------------
-- Privileges. Supabase grants broad default privileges to the API roles, so start
-- from nothing and add back exactly what the app needs.
-- ---------------------------------------------------------------------------
revoke all on table public.app_users from anon, authenticated;
grant select on table public.app_users to authenticated;
-- Only display_name is editable by the account holder; id, timestamps and
-- deleted_at are not.
grant update (display_name) on table public.app_users to authenticated;

revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;
revoke execute on function public.confirm_adult() from public, anon;
grant execute on function public.confirm_adult() to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security. For now an account can see and edit only its own row.
-- When trees exist, a separate policy will let members of the same tree read
-- each other's display names.
-- ---------------------------------------------------------------------------
alter table public.app_users enable row level security;

create policy "app_users: account holder can read own row"
  on public.app_users
  for select
  to authenticated
  using (id = (select auth.uid()) and deleted_at is null);

create policy "app_users: account holder can update own row"
  on public.app_users
  for update
  to authenticated
  using (id = (select auth.uid()) and deleted_at is null)
  with check (id = (select auth.uid()));

-- No INSERT policy: rows are created only by the trigger above.
-- No DELETE policy: nothing is hard-deleted.
