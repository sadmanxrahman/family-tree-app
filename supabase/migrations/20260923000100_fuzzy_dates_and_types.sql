-- Shared types for the family tree schema: the fuzzy date convention and every enum.
--
-- FUZZY DATES (CLAUDE.md rule 4). Every genealogical date is three columns:
--   <name>_date            date                   the date, or the start of a range
--   <name>_date_precision  public.fuzzy_precision what the date means
--   <name>_date_end        date                   only for 'between': the end of the range
--
-- How each precision is stored (normalised so equal statements compare equal):
--   exact    any date                              "15 August 1947"
--   month    first day of the month                "August 1947"
--   year     1 January                             "1947"
--   decade   1 January of a year ending in 0       "1940s"
--   about    1 January (year-level)                "about 1947"
--   before   any date: the boundary                "before 15 August 1947"
--   after    any date: the boundary                "after 26 March 1971"
--   between  any start date, end date after it     "between 1918 and 1922"
--
-- before/after/between keep full precision because migration records state exact
-- boundaries. A year-level statement is stored as its boundary day — "before 1947" is
-- "before 1947-01-01", "after 1947" is "after 1947-12-31", "between 1918 and 1922" is
-- 1918-01-01..1922-12-31 — which mean exactly the same thing, so nothing is lost. The app
-- displays a year boundary as the year alone.

create type public.fuzzy_precision as enum (
  'exact', 'month', 'year', 'decade', 'about', 'before', 'after', 'between'
);

create function public.fuzzy_date_is_valid(
  p_date date,
  p_precision public.fuzzy_precision,
  p_end date
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    -- No date at all: all three columns empty.
    when p_date is null then p_precision is null and p_end is null
    -- A date always needs to say what it means.
    when p_precision is null then false
    when p_precision = 'between' then p_end is not null and p_end > p_date
    -- Only 'between' has an end date.
    when p_end is not null then false
    when p_precision = 'month' then extract(day from p_date) = 1
    when p_precision in ('year', 'about') then
      extract(month from p_date) = 1 and extract(day from p_date) = 1
    when p_precision = 'decade' then
      extract(month from p_date) = 1 and extract(day from p_date) = 1
      and extract(year from p_date)::int % 10 = 0
    else true -- exact, before, after
  end;
$$;

comment on function public.fuzzy_date_is_valid(date, public.fuzzy_precision, date) is
  'Check-constraint helper enforcing the fuzzy date convention described in this migration.';

-- Membership roles, most to least powerful.
create type public.tree_role as enum ('owner', 'admin', 'member', 'viewer');

create type public.person_gender as enum ('female', 'male', 'other');

create type public.name_kind as enum ('nickname', 'variant', 'married', 'other');

create type public.parent_child_kind as enum (
  'biological', 'adoptive', 'step', 'foster', 'guardian'
);

create type public.union_kind as enum ('marriage', 'civil_partnership', 'partnership');

create type public.union_status as enum (
  'current', 'divorced', 'widowed', 'separated', 'annulled'
);

-- No street-address type on purpose: no precise locations (CLAUDE.md privacy rules).
create type public.place_type as enum (
  'city', 'town', 'village', 'region', 'country', 'cemetery', 'place_of_worship'
);

create type public.person_place_kind as enum (
  'birth', 'death', 'burial', 'residence', 'home_city'
);

create type public.memory_kind as enum ('story', 'photo', 'video', 'audio');

-- Shared by claims and change_requests.
create type public.request_status as enum ('pending', 'approved', 'rejected', 'withdrawn');

create type public.feed_event_kind as enum (
  'person_added', 'person_claimed', 'person_marked_deceased', 'memory_added', 'member_joined'
);

-- 'candle' is for remembering someone who has died.
create type public.reaction_kind as enum ('heart', 'hug', 'smile', 'candle');

create type public.notification_kind as enum (
  'relationship_changed', 'change_request_received'
);
