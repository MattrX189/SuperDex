-- ============================================================
-- SuperDex: event registrations ("who's going")
-- ============================================================
--
-- Companion to events.sql. Until now the "Registered" mark lived
-- only in UserDefaults on each device; this table mirrors it
-- server-side so the event page can show which SuperDex users are
-- attending an event.
--
-- HOW TO DEPLOY (dashboard only, no CLI needed):
--   Paste this whole file into the Supabase SQL editor and run it
--   once, BEFORE shipping the app build that shows attendees.
--
-- NOTE: get_event_attendees below assumes public.profiles has the
-- columns user_id / first_name / last_name / avatar / job_role /
-- company_name / bio / is_hidden (the same ones the discover and
-- viewer RPCs return). Adjust the join if your column names differ.
-- ============================================================

-- One row per user per event. Event ids are the public.events row
-- ids, which stay stable across scrape runs (upserts keep the row);
-- the cascade cleans registrations up when the daily cleanup job
-- deletes past events.
create table if not exists public.event_registrations (
    event_id   uuid not null references public.events (id) on delete cascade,
    user_id    uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (event_id, user_id)
);

create index if not exists event_registrations_user_idx
    on public.event_registrations (user_id);

alter table public.event_registrations enable row level security;

-- Users manage only their own rows. Reading other people's
-- registrations goes through the get_event_attendees RPC below,
-- which masks profiles down to card basics.
drop policy if exists "users read own registrations" on public.event_registrations;
create policy "users read own registrations"
    on public.event_registrations
    for select
    to authenticated
    using (auth.uid() = user_id);

drop policy if exists "users insert own registrations" on public.event_registrations;
create policy "users insert own registrations"
    on public.event_registrations
    for insert
    to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "users delete own registrations" on public.event_registrations;
create policy "users delete own registrations"
    on public.event_registrations
    for delete
    to authenticated
    using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- RPC: the attendee list for one event, earliest registration
-- first. Every signed-in user (pro or not) can call it. security
-- definer so it can read other users' registration rows and
-- profiles, but it returns ONLY name, avatar, job title, company
-- and bio — never phone/email/links. The full card stays gated
-- behind an accepted connect request (existing contacts flow).
-- Hidden users (moderation) are excluded.
-- ------------------------------------------------------------
create or replace function public.get_event_attendees(p_event_id uuid)
returns table (
    user_id       uuid,
    first_name    text,
    last_name     text,
    avatar        text,
    job_role      text,
    company_name  text,
    bio           text,
    registered_at timestamptz
)
language sql
security definer
set search_path = public
as $$
    select p.user_id,
           coalesce(p.first_name, '')   as first_name,
           coalesce(p.last_name, '')    as last_name,
           coalesce(p.avatar, '')       as avatar,
           coalesce(p.job_role, '')     as job_role,
           coalesce(p.company_name, '') as company_name,
           coalesce(p.bio, '')          as bio,
           r.created_at                 as registered_at
    from public.event_registrations r
    join public.profiles p on p.user_id = r.user_id
    where r.event_id = p_event_id
      and p.is_hidden = false
      and auth.uid() is not null
    order by r.created_at asc;
$$;

revoke execute on function public.get_event_attendees(uuid) from public, anon;
grant execute on function public.get_event_attendees(uuid) to authenticated;
