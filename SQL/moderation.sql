-- =============================================================================
-- SuperDex — Moderation migration (App Store Review Guideline 1.2)
-- Run this once in the Supabase SQL editor.
--
-- Adds:
--   1. content_reports        — user reports + block events (your review queue)
--   2. profiles.is_hidden      — flag to remove a user from Discover for everyone
--   3. (manual) a one-line change to the get_discover_profiles RPC so hidden
--      users stop appearing in the feed.
-- =============================================================================

-- 1) -------------------------------------------------------------------------
-- Reports table. Every "Report" and every "Block" in the app inserts a row here.
-- This is what you (the developer) watch and act on within 24 hours.
create table if not exists public.content_reports (
    id                uuid primary key default gen_random_uuid(),
    reporter_id       uuid not null references auth.users (id) on delete cascade,
    reported_user_id  uuid not null,
    reason            text not null,   -- spam | harassment | inappropriate | impersonation | other | blocked
    details           text,
    created_at        timestamptz not null default now()
);

create index if not exists content_reports_reported_idx
    on public.content_reports (reported_user_id);
create index if not exists content_reports_created_idx
    on public.content_reports (created_at desc);

alter table public.content_reports enable row level security;

-- A signed-in user may only insert reports as themselves.
drop policy if exists "users insert own reports" on public.content_reports;
create policy "users insert own reports"
    on public.content_reports
    for insert
    with check (auth.uid() = reporter_id);

-- (No select policy for regular users: reports are private to the developer.
--  Review them in the Supabase dashboard / Table editor, which uses the
--  service role and bypasses RLS.)


-- 2) -------------------------------------------------------------------------
-- Hide flag on profiles. Flip to true to pull a user out of Discover for
-- everyone (use this when you action a report). Defaults to visible.
alter table public.profiles
    add column if not exists is_hidden boolean not null default false;


-- 3) -------------------------------------------------------------------------
-- IMPORTANT — update the Discover RPC so hidden users are excluded.
--
-- The get_discover_profiles function isn't recreated here because its body is
-- maintained in your project. Edit it in the SQL editor and add this predicate
-- to the WHERE clause of its main query:
--
--     AND p.is_hidden = false
--
-- e.g. if it currently reads:
--
--     ...
--     WHERE p.is_premium_user = true
--       AND p.user_id <> requesting_user_id
--     ...
--
-- change it to:
--
--     ...
--     WHERE p.is_premium_user = true
--       AND p.user_id <> requesting_user_id
--       AND p.is_hidden = false
--     ...
--
-- (Adjust the table alias / column names to match your actual function.)
-- =============================================================================
