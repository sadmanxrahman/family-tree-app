-- app_config: remote switches for anything risky (CLAUDE.md rule 5), so a feature can be
-- turned off without a store release. Edited by hand in the Supabase dashboard's Table
-- Editor, which runs as the postgres role and bypasses the RLS below.

create table public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  -- Every table gets deleted_at (CLAUDE.md rule 3). A soft-deleted flag is invisible to
  -- the app, which then falls back to that flag's safe default.
  deleted_at timestamptz
);

comment on table public.app_config is
  'Feature flags and remote config. Read by the app at startup; edited only in the dashboard.';

-- Reuses the trigger function from the app_users migration.
create trigger app_config_set_updated_at
  before update on public.app_config
  for each row execute function public.set_updated_at();

-- Every flag starts OFF. The app's built-in defaults are also off, so a failed fetch
-- and a fresh install behave the same way.
insert into public.app_config (key, value) values
  ('ads_enabled', 'false'),
  ('discovery_enabled', 'false'),
  ('live_location_enabled', 'false'),
  ('print_enabled', 'false');

-- ---------------------------------------------------------------------------
-- Privileges and RLS: any signed-in account can read; nobody can write through the API.
-- ---------------------------------------------------------------------------
revoke all on table public.app_config from anon, authenticated;
grant select on table public.app_config to authenticated;

alter table public.app_config enable row level security;

create policy "app_config: signed-in accounts can read"
  on public.app_config
  for select
  to authenticated
  using (deleted_at is null);

-- No INSERT, UPDATE or DELETE policies: writes happen only in the dashboard.
