-- ============================================================
-- SuperDex: whitelisted members show everything by default
-- ============================================================
--
-- Whitelisted members are treated as Pro, and Pro privacy controls
-- store the fields that are VISIBLE (discover_visible / qr_visible).
-- Paying users set these when they upgrade, but whitelisted members
-- never go through that flow — so their lists are empty and Discover
-- hides their role, company, bio, links, etc.
--
-- This backfills every whitelisted member whose lists are still empty
-- to "everything visible". It never touches anyone who has already
-- chosen settings (either list non-empty).
--
-- The app does the same on its own the next time such a member opens
-- it (UserProfileViewModel.load → ProfileVisibility.everythingVisible);
-- this just fixes Discover right away. Keep the key list in sync with
-- ProfileField.allGroups in Models/ProfileVisibility.swift.
--
-- Safe to re-run. HOW TO DEPLOY: run once in the Supabase SQL editor.
-- ============================================================

with all_keys as (
  select array[
    -- identity / contact / profile
    'jobTitle', 'company', 'bio', 'phone', 'email', 'category', 'portfolio',
    -- social links
    'link.whatsapp', 'link.instagram', 'link.linkedin', 'link.x', 'link.facebook',
    'link.youtube', 'link.telegram', 'link.snapchat', 'link.discord', 'link.reddit',
    'link.threads',
    -- business links
    'link.customLink', 'link.calendly', 'link.appStore', 'link.behance', 'link.dribbble',
    'link.github', 'link.medium', 'link.linktree', 'link.figma', 'link.spotify',
    'link.vimeo', 'link.pinterest'
  ]::text[] as keys
)
update public.profiles p
set discover_visible = all_keys.keys,
    qr_visible = all_keys.keys
from all_keys
where coalesce(p.whitelisted, false) = true
  and coalesce(array_length(p.discover_visible, 1), 0) = 0
  and coalesce(array_length(p.qr_visible, 1), 0) = 0;
