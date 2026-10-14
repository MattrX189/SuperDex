-- ============================================================
-- SuperDex: server-side events pipeline
-- ============================================================
--
-- Companion to the `scrape-events` Edge Function
-- (supabase/functions/scrape-events/index.ts). The function scrapes
-- Luma / Eventbrite / Ticketmaster / SeatGeek / Meetup listing pages
-- and upserts into public.events; the iOS app reads this table
-- instead of scraping on-device.
--
-- HOW TO DEPLOY (dashboard only, no CLI needed):
--   1. Dashboard -> Edge Functions -> Deploy a new function ->
--      name it exactly `scrape-events`, paste index.ts, deploy.
--   2. Paste this whole file into the SQL editor and run it.
--   3. Seed once: run the "manual trigger" statement at the bottom
--      of this file (or use the function's Test button) and check
--      that rows appear in public.events.
--   4. Ship the app build that reads from the table.
--
-- The Authorization header below uses the project's *anon* key —
-- the same public key already shipped inside the iOS app binary.
-- The function writes with its own service-role env internally.
-- ============================================================

-- Extensions used by the schedules (both ship with Supabase).
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ------------------------------------------------------------
-- Table: one row per scraped event, deduped by registration URL
-- (the same event can appear on multiple scraped pages).
-- Columns mirror the app's AppEvent model; category/source hold the
-- exact rawValue strings of the app's EventCategory/EventSource enums.
-- ------------------------------------------------------------
create table if not exists public.events (
    id uuid primary key default gen_random_uuid(),
    registration_url text not null unique,
    title text not null,
    description text,
    -- tech | ai | crypto | climate | fitness | wellness | music | arts
    -- | food | business | networking | sports | other
    category text not null default 'other',
    city text not null,
    venue text,
    start_date timestamptz,          -- null when the site omitted it
    image_url text,
    price_text text,
    -- luma | eventbrite | ticketmaster | seatgeek | meetup
    source text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    -- Bumped on every scrape run that still sees the event; lets the
    -- cleanup job drop events that vanished from the listing pages.
    last_seen_at timestamptz not null default now()
);

-- The app queries upcoming events ordered by date, filtered by
-- city/category client-side.
create index if not exists events_start_date_idx
    on public.events (start_date);
create index if not exists events_city_category_idx
    on public.events (city, category);

-- ------------------------------------------------------------
-- RLS: events are public data — anyone with the app can read them.
-- No insert/update/delete policies: only the Edge Function writes,
-- via the service-role key (which bypasses RLS).
-- ------------------------------------------------------------
alter table public.events enable row level security;

drop policy if exists "anyone can read events" on public.events;
create policy "anyone can read events"
    on public.events
    for select
    to anon, authenticated
    using (true);

-- ------------------------------------------------------------
-- Schedule 1: scrape every 6 hours.
-- pg_net posts to the Edge Function asynchronously; the function does
-- the scraping and upserting. 55s timeout is pg_net's ceiling — the
-- function keeps running server-side even if the HTTP wait times out.
-- ------------------------------------------------------------
select cron.unschedule('scrape-events')
    where exists (select 1 from cron.job where jobname = 'scrape-events');
select cron.schedule(
    'scrape-events',
    '0 */6 * * *',
    $$
    select net.http_post(
        url := 'https://krgighgbudwalorlbsrs.supabase.co/functions/v1/scrape-events',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyZ2lnaGdidWR3YWxvcmxic3JzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDMzNTEsImV4cCI6MjA5MjAxOTM1MX0.hd1Lbgw7zhKfVJYK-dTii23NvPNSa6Wgji9mTLXeX_0'
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 55000
    );
    $$
);

-- ------------------------------------------------------------
-- Schedule 2: daily cleanup.
--   * events whose date has passed (same 1-day grace the app used)
--   * undated events not seen on any listing page for 7 days
--     (the event vanished from the sites)
-- ------------------------------------------------------------
select cron.unschedule('cleanup-events')
    where exists (select 1 from cron.job where jobname = 'cleanup-events');
select cron.schedule(
    'cleanup-events',
    '30 3 * * *',
    $$
    delete from public.events
    where (start_date is not null and start_date < now() - interval '1 day')
       or (start_date is null and last_seen_at < now() - interval '7 days');
    $$
);

-- ------------------------------------------------------------
-- Manual trigger (run this once after deploying to seed the table,
-- then check:  select count(*), source from public.events group by source; )
-- ------------------------------------------------------------
-- select net.http_post(
--     url := 'https://krgighgbudwalorlbsrs.supabase.co/functions/v1/scrape-events',
--     headers := jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyZ2lnaGdidWR3YWxvcmxic3JzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDMzNTEsImV4cCI6MjA5MjAxOTM1MX0.hd1Lbgw7zhKfVJYK-dTii23NvPNSa6Wgji9mTLXeX_0'
--     ),
--     body := '{}'::jsonb,
--     timeout_milliseconds := 55000
-- );
