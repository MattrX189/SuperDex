-- ============================================================
-- SuperDex: share your card back after a scan  (v2)
-- ============================================================
--
-- One scan, two decisions:
--   1. Rahul scans Abhinav's QR and saves him.
--   2. Rahul shares his card back — by tapping "Share my card", or
--      automatically if he turned on auto-share. Abhinav gets a
--      `card_shared` notification (pushed by the notifications webhook)
--      and taps Add or Not now.
--x
-- What lives here:
--   • card_shares            — the server's record of every share and how
--                              it was answered (pending / added / declined)
--   • share_card()           — called by the sharer's app
--   • accept_shared_card()   — receiver adds the sharer, in one step
--   • decline_shared_card()  — receiver says no; recorded, never revealed
--   • profiles.auto_share_card + a trigger that shares automatically
--     whenever that user adds someone (any way they add them)
--   • a nightly job pruning old read notifications
--
-- Privacy:
--   • You can only share with someone you've saved yourself (scanned).
--   • A decline is never shown to the sharer. They can't read
--     card_shares at all; share_card() answers "sent" either way. A
--     declined pair won't be re-notified for 30 days.
--   • Re-sharing a pending card within a day doesn't notify again.
--
-- Requires notifications.sql (for superdex_actor_data + notifications)
-- and the pg_cron extension (already used by events.sql).
-- HOW TO DEPLOY: run in the Supabase SQL editor. Safe to re-run;
-- replaces the v1 share_card().
-- ============================================================

-- 1) The record of shares ---------------------------------------------
create table if not exists public.card_shares (
    id            uuid primary key default gen_random_uuid(),
    sharer_id     uuid not null references auth.users (id) on delete cascade,
    receiver_id   uuid not null references auth.users (id) on delete cascade,
    status        text not null default 'pending',   -- pending | added | declined
    created_at    timestamptz not null default now(),
    responded_at  timestamptz,
    unique (sharer_id, receiver_id)
);

create index if not exists card_shares_receiver_idx on public.card_shares (receiver_id, status);

-- No policies: only the SECURITY DEFINER functions below touch this
-- table, so neither side can read the other's answer.
alter table public.card_shares enable row level security;

-- 2) Auto-share preference (follows the account across devices) -----
alter table public.profiles add column if not exists auto_share_card boolean not null default false;

-- 3) Core: share sharer's card with receiver ---------------------------
-- Internal — no auth checks; callers below do them.
create or replace function public.superdex_share_card(p_sharer uuid, p_receiver uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  existing public.card_shares;
  actor jsonb;
  actor_name text;
  first_name text;
begin
  if p_sharer is null or p_receiver is null or p_sharer = p_receiver then
    return 'invalid';
  end if;

  -- They already have the sharer's card: nothing to do.
  if exists (
    select 1 from public.contacts
    where user_id = p_receiver and contact_user_id = p_sharer
  ) then
    return 'already_connected';
  end if;

  select * into existing from public.card_shares
  where sharer_id = p_sharer and receiver_id = p_receiver;

  if found then
    -- Declined recently: answer as if sent, but don't bother them.
    if existing.status = 'declined' and existing.responded_at > now() - interval '30 days' then
      return 'sent';
    end if;
    -- Already waiting on them from today: don't notify twice.
    if existing.status = 'pending' and existing.created_at > now() - interval '1 day' then
      return 'sent';
    end if;
    update public.card_shares
       set status = 'pending', created_at = now(), responded_at = null
     where id = existing.id;
  else
    insert into public.card_shares (sharer_id, receiver_id) values (p_sharer, p_receiver);
  end if;

  actor := coalesce(public.superdex_actor_data(p_sharer), '{}'::jsonb);
  actor_name := coalesce(nullif(actor->>'actor_name', ''), 'Someone');
  select nullif(trim(p.first_name), '') into first_name
  from public.profiles p where p.user_id = p_sharer;

  -- Replace any older card_shared notice from this sharer.
  delete from public.notifications
  where user_id = p_receiver and actor_id = p_sharer and type = 'card_shared';

  insert into public.notifications (user_id, actor_id, type, title, body, data, dedupe_key)
  values (
    p_receiver, p_sharer, 'card_shared',
    actor_name || ' shared their card with you',
    'You just met — add ' || coalesce(first_name, 'them') || ' to your SuperDex contacts.',
    actor || jsonb_build_object('sharer_id', p_sharer),
    'card_shared:' || p_sharer || ':' || p_receiver || ':' || extract(epoch from now())::bigint
  )
  on conflict do nothing;

  return 'sent';
end;
$$;

revoke execute on function public.superdex_share_card(uuid, uuid) from anon, authenticated, public;

-- 4) App-facing: share my card with someone I've saved ------------------
create or replace function public.share_card(p_receiver_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  -- Only after you've saved them yourself.
  if not exists (
    select 1 from public.contacts
    where user_id = auth.uid() and contact_user_id = p_receiver_id
  ) then
    raise exception 'save_them_first';
  end if;
  return public.superdex_share_card(auth.uid(), p_receiver_id);
end;
$$;

-- 5) Receiver: add the person who shared ---------------------------------
-- Adds them to your contacts only if they actually shared with you.
-- Returns 'added', 'already_connected' or 'no_share'.
create or replace function public.accept_shared_card(p_sharer_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  has_share boolean;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.contacts where user_id = me and contact_user_id = p_sharer_id) then
    update public.card_shares set status = 'added', responded_at = now()
     where sharer_id = p_sharer_id and receiver_id = me and status = 'pending';
    return 'already_connected';
  end if;

  select exists (
    select 1 from public.card_shares
    where sharer_id = p_sharer_id and receiver_id = me and status = 'pending'
  ) or exists (
    -- Shares sent before card_shares existed only left a notification.
    select 1 from public.notifications
    where user_id = me and actor_id = p_sharer_id and type = 'card_shared'
  ) into has_share;

  if not has_share then
    return 'no_share';
  end if;

  insert into public.contacts (id, user_id, contact_user_id)
  values (gen_random_uuid(), me, p_sharer_id)
  on conflict do nothing;

  insert into public.card_shares (sharer_id, receiver_id, status, responded_at)
  values (p_sharer_id, me, 'added', now())
  on conflict (sharer_id, receiver_id) do update
    set status = 'added', responded_at = now();

  -- Keep the notification as history, marked read.
  update public.notifications set read_at = coalesce(read_at, now())
   where user_id = me and actor_id = p_sharer_id and type = 'card_shared';

  return 'added';
end;
$$;

-- 6) Receiver: "Not now" — recorded, never revealed ---------------------
create or replace function public.decline_shared_card(p_sharer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  insert into public.card_shares (sharer_id, receiver_id, status, responded_at)
  values (p_sharer_id, me, 'declined', now())
  on conflict (sharer_id, receiver_id) do update
    set status = 'declined', responded_at = now();

  delete from public.notifications
  where user_id = me and actor_id = p_sharer_id and type = 'card_shared';
end;
$$;

revoke execute on function public.share_card(uuid) from anon, public;
revoke execute on function public.accept_shared_card(uuid) from anon, public;
revoke execute on function public.decline_shared_card(uuid) from anon, public;
grant execute on function public.share_card(uuid) to authenticated;
grant execute on function public.accept_shared_card(uuid) to authenticated;
grant execute on function public.decline_shared_card(uuid) to authenticated;

-- 7) Auto-share: when someone with auto-share on adds a contact ---------
-- Deferred to the end of the transaction, so a connect-request accept
-- (which adds both people) is already two-way by the time this runs and
-- nothing is sent.
create or replace function public.superdex_auto_share_on_contact()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.profiles
    where user_id = new.user_id and auto_share_card
  ) then
    perform public.superdex_share_card(new.user_id, new.contact_user_id);
  end if;
  return null;
end;
$$;

drop trigger if exists superdex_auto_share_on_contact on public.contacts;
create constraint trigger superdex_auto_share_on_contact
    after insert on public.contacts
    deferrable initially deferred
    for each row execute function public.superdex_auto_share_on_contact();

-- 8) Housekeeping: drop read notifications after 90 days ----------------
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'superdex-prune-notifications';
  perform cron.schedule(
    'superdex-prune-notifications',
    '30 3 * * *',  -- daily, 03:30 UTC
    $job$
      delete from public.notifications
      where read_at is not null and created_at < now() - interval '90 days';
    $job$
  );
exception
  when undefined_table or invalid_schema_name or undefined_function then
    raise notice 'pg_cron not enabled — skipping the cleanup job (enable it under Database → Extensions and re-run).';
end;
$$;
