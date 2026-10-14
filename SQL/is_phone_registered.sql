-- ============================================================
-- SuperDex: block duplicate phone numbers during onboarding
-- ============================================================
--
-- Onboarding calls this before letting a new user continue, so the
-- same person can't create a second account (e.g. via Sign in with
-- Apple + "Hide My Email") with a number that's already registered.
--
-- profiles.phone is stored as "<code> <number>" (e.g. "+91 9099816821"),
-- so both sides are compared as digits only. The caller's own row is
-- excluded so re-entering your own number is fine.
--
-- SECURITY DEFINER so it can check every profile without exposing any
-- phone numbers — it only ever returns true/false.
--
-- HOW TO DEPLOY: run this in the Supabase SQL editor.
-- ============================================================

create or replace function public.is_phone_registered(target_phone text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.user_id <> auth.uid()
      and length(regexp_replace(target_phone, '\D', '', 'g')) >= 7
      and regexp_replace(p.phone, '\D', '', 'g') = regexp_replace(target_phone, '\D', '', 'g')
  );
$$;

revoke execute on function public.is_phone_registered(text) from anon, public;
grant execute on function public.is_phone_registered(text) to authenticated;
