-- ============================================================
-- SuperDex: add location + link to groups
-- ============================================================
-- Run once in the Supabase SQL editor BEFORE shipping the app
-- build that adds location/link to groups — the app writes these
-- columns on every group save, so saves fail until they exist.
-- Existing rows are unaffected (both columns are nullable).
-- ============================================================

alter table public.groups
    add column if not exists location text,
    add column if not exists link text;
