-- =============================================================================
-- SuperDex — Phone-number contact matching ("From Phone" in the Contacts tab)
-- Run this once in the Supabase SQL editor.
--
-- Powers the section that shows the user's device address book and marks who
-- is already on SuperDex. The app sends only normalized digit keys (never
-- names, emails, or the contacts themselves) and gets back identity-only rows.
--
-- Adds:
--   1. superdex_phone_key()      — the shared normalization rule
--   2. profiles.phone_key        — generated column + index, so lookups are
--                                  an index scan rather than a table scan
--   3. find_profiles_by_phone()  — the RPC the app calls
-- =============================================================================


-- 1) -------------------------------------------------------------------------
-- Normalization. Numbers arrive in every shape people type them — "+91 98765
-- 43210", "098765-43210", "(555) 100-2001" — so reduce to digits and keep the
-- last 10. Ten is the significant-digit length for the markets SuperDex ships
-- in, and dropping the country code is the point: that's the part that differs
-- between how someone saved a number and how its owner typed it.
--
-- PhoneKey.make(from:) in Models/DeviceContact.swift applies the same rule
-- client-side. Change one and you MUST change the other, or matching silently
-- stops working.
create or replace function public.superdex_phone_key(raw text)
returns text
language sql
immutable
strict
parallel safe
set search_path = public
as $$
  select case
    when length(regexp_replace(raw, '\D', '', 'g')) > 10
      then right(regexp_replace(raw, '\D', '', 'g'), 10)
    else nullif(regexp_replace(raw, '\D', '', 'g'), '')
  end;
$$;


-- 2) -------------------------------------------------------------------------
-- Stored key + index. Generated, so it can never drift from profiles.phone
-- and no app change is needed to keep it current.
--
-- Non-destructive: existing rows get their key computed on add, exactly like
-- whitelisted (whitelist.sql) and is_hidden (moderation.sql).
alter table public.profiles
    add column if not exists phone_key text
    generated always as (public.superdex_phone_key(phone)) stored;

create index if not exists profiles_phone_key_idx
    on public.profiles (phone_key)
    where phone_key is not null;


-- 3) -------------------------------------------------------------------------
-- The lookup.
--
-- PRIVACY: this returns IDENTITY ONLY — name, username, avatar, role, company,
-- category. No phone, no email, no links, no bio. Having someone's number in
-- your address book says nothing about whether they want to share their card
-- with you, so the match is only ever enough to recognize a face and press
-- Connect; the full card arrives through the normal request flow, masked by
-- get_contact_profiles as it always was.
--
-- Also honours the existing suppression rules:
--   • is_hidden       — moderation (moderation.sql)
--   • job/company     — masked for premium users per their qr_visible settings,
--                       matching how ProfileCard.masked(for: .qr) behaves
--                       client-side (privacy controls are premium-only)
--   • the caller      — never matches themselves
create or replace function public.find_profiles_by_phone(phone_keys text[])
returns table (
    match_key       text,
    user_id         uuid,
    first_name      text,
    last_name       text,
    username        text,
    company_name    text,
    job_role        text,
    avatar          text,
    theme_index     int,
    is_premium_user boolean,
    categories      text[]
)
language sql
security definer
stable
set search_path = public
as $$
  with keys as (
    -- Cap the batch so a caller can't turn this into a directory dump.
    select distinct k
    from unnest(phone_keys) as k
    where k is not null and k <> ''
    limit 500
  )
  select
      p.phone_key                                   as match_key,
      p.user_id,
      coalesce(p.first_name, '')                    as first_name,
      coalesce(p.last_name, '')                     as last_name,
      coalesce(p.username, '')                      as username,
      case
        when is_pro and not qr_shows_company then ''
        else coalesce(p.company_name, '')
      end                                           as company_name,
      case
        when is_pro and not qr_shows_role then ''
        else coalesce(p.job_role, '')
      end                                           as job_role,
      coalesce(p.avatar, 'memoji1')                 as avatar,
      coalesce(p.theme_index, 0)                    as theme_index,
      is_pro                                        as is_premium_user,
      case
        when is_pro and not qr_shows_category then array[]::text[]
        else coalesce(p.categories, array[]::text[])
      end                                           as categories
  from public.profiles p
  join keys on keys.k = p.phone_key
  cross join lateral (
    select
      (coalesce(p.is_premium_user, false) or coalesce(p.whitelisted, false)) as is_pro,
      coalesce(p.qr_visible, array[]::text[]) @> array['company']  as qr_shows_company,
      coalesce(p.qr_visible, array[]::text[]) @> array['jobTitle'] as qr_shows_role,
      coalesce(p.qr_visible, array[]::text[]) @> array['category'] as qr_shows_category
  ) flags
  where p.phone_key is not null
    and coalesce(p.is_hidden, false) = false
    and p.user_id <> auth.uid();
$$;

grant execute on function public.find_profiles_by_phone(text[]) to authenticated;
grant execute on function public.superdex_phone_key(text) to authenticated;
