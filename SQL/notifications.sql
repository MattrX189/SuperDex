-- ============================================================
-- SuperDex: in-app notifications
-- ============================================================
--
-- Fills public.notifications (already in the project: id, user_id,
-- actor_id, type, title, body, data, read_at, created_at) from the
-- events that matter, via triggers — so every client sees the same
-- feed and nothing depends on the sender's app being open.
--
--   type              to                 when
--   connect_request   the receiver       a connect request is sent
--   request_accepted  the sender         their request is accepted
--   gig_application   the gig's poster   someone applies to their gig
--
-- `data` carries what the app needs to render and act without another
-- lookup: actor_name, actor_avatar, actor_username, plus request_id or
-- post_id. The app reads its own rows, marks them read, and listens for
-- inserts over Realtime to show the in-app banner.
--
-- Idempotent and safe to re-run. HOW TO DEPLOY: run this in the
-- Supabase SQL editor.
--
-- NOTE: if you already have other triggers writing into notifications,
-- remove them, or you'll get duplicates.
-- ============================================================

-- 1) Table (no-op if it exists) + the columns the app relies on ----------
create table if not exists public.notifications (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    actor_id    uuid references auth.users (id) on delete cascade,
    type        text not null,
    title       text not null,
    body        text,
    data        jsonb not null default '{}'::jsonb,
    read_at     timestamptz,
    created_at  timestamptz not null default now()
);
alter table public.notifications add column if not exists dedupe_key text;

create index if not exists notifications_user_created_idx
    on public.notifications (user_id, created_at desc);
-- One notification per underlying event, even if a trigger re-fires.
create unique index if not exists notifications_dedupe_idx
    on public.notifications (dedupe_key) where dedupe_key is not null;

-- 2) Access: each user reads and marks read only their own ----------------
alter table public.notifications enable row level security;

drop policy if exists "notifications: read own" on public.notifications;
create policy "notifications: read own" on public.notifications
    for select to authenticated using (user_id = auth.uid());

drop policy if exists "notifications: update own" on public.notifications;
create policy "notifications: update own" on public.notifications
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "notifications: delete own" on public.notifications;
create policy "notifications: delete own" on public.notifications
    for delete to authenticated using (user_id = auth.uid());
-- No insert policy: only the SECURITY DEFINER triggers below write rows.

-- 3) Helper: who did it, for display ---------------------------------------
create or replace function public.superdex_actor_data(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
      'actor_name', trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')),
      'actor_avatar', coalesce(nullif(p.avatar, ''), 'memoji1'),
      'actor_username', coalesce(p.username, '')
  )
  from public.profiles p
  where p.user_id = p_user_id;
$$;

-- 4) Connect requests: sent → receiver; accepted → sender -----------------
create or replace function public.superdex_notify_contact_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor jsonb;
  actor_name text;
  became_pending boolean := false;
  became_accepted boolean := false;
begin
  -- Branch on the operation first: OLD doesn't exist on INSERT.
  if tg_op = 'INSERT' then
    became_pending := new.status = 'pending';
  elsif tg_op = 'UPDATE' then
    became_pending := new.status = 'pending' and old.status is distinct from 'pending';
    became_accepted := new.status = 'accepted' and old.status is distinct from 'accepted';
  end if;

  if became_pending then
    actor := coalesce(public.superdex_actor_data(new.sender_id), '{}'::jsonb);
    actor_name := coalesce(nullif(actor->>'actor_name', ''), 'Someone');
    insert into public.notifications (user_id, actor_id, type, title, body, data, dedupe_key)
    values (
      new.receiver_id, new.sender_id, 'connect_request',
      actor_name || ' wants to connect',
      'Accept to swap cards and add each other to contacts.',
      actor || jsonb_build_object('request_id', new.id),
      'connect_request:' || new.id || ':' || extract(epoch from now())::bigint
    )
    on conflict do nothing;
  end if;

  if became_accepted then
    actor := coalesce(public.superdex_actor_data(new.receiver_id), '{}'::jsonb);
    actor_name := coalesce(nullif(actor->>'actor_name', ''), 'Someone');
    insert into public.notifications (user_id, actor_id, type, title, body, data, dedupe_key)
    values (
      new.sender_id, new.receiver_id, 'request_accepted',
      actor_name || ' accepted your request',
      'You''re connected — their card is in your contacts.',
      actor || jsonb_build_object('request_id', new.id),
      'request_accepted:' || new.id
    )
    on conflict do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists superdex_notify_contact_request on public.contact_requests;
create trigger superdex_notify_contact_request
    after insert or update of status on public.contact_requests
    for each row execute function public.superdex_notify_contact_request();

-- 5) Gig applications → the poster -----------------------------------------
create or replace function public.superdex_notify_gig_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  poster uuid;
  gig_title text;
  actor jsonb;
begin
  select user_id, title into poster, gig_title from public.gig_posts where id = new.post_id;
  if poster is null or poster = new.applicant_id then
    return new;
  end if;
  actor := coalesce(public.superdex_actor_data(new.applicant_id), '{}'::jsonb);
  insert into public.notifications (user_id, actor_id, type, title, body, data, dedupe_key)
  values (
    poster, new.applicant_id, 'gig_application',
    coalesce(nullif(actor->>'actor_name', ''), 'Someone') || ' applied to your gig',
    gig_title,
    actor || jsonb_build_object('post_id', new.post_id),
    'gig_application:' || new.post_id || ':' || new.applicant_id
  )
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists superdex_notify_gig_application on public.gig_applications;
create trigger superdex_notify_gig_application
    after insert on public.gig_applications
    for each row execute function public.superdex_notify_gig_application();

-- 6) Backfill: requests already waiting get a notification ---------------
insert into public.notifications (user_id, actor_id, type, title, body, data, created_at, dedupe_key)
select
  r.receiver_id, r.sender_id, 'connect_request',
  coalesce(nullif(public.superdex_actor_data(r.sender_id)->>'actor_name', ''), 'Someone') || ' wants to connect',
  'Accept to swap cards and add each other to contacts.',
  coalesce(public.superdex_actor_data(r.sender_id), '{}'::jsonb) || jsonb_build_object('request_id', r.id),
  r.created_at,
  'connect_request:' || r.id || ':backfill'
from public.contact_requests r
where r.status = 'pending'
  and not exists (
    select 1 from public.notifications n
    where n.type = 'connect_request' and n.data->>'request_id' = r.id::text
  )
on conflict do nothing;

-- 7) Realtime, so the app can show a banner the moment one arrives -------
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
end;
$$;
