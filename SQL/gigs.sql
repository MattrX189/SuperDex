-- ============================================================
-- SuperDex: gig posts ("Requirements" on the Discover tab)
-- ============================================================
--
-- Users post requirements ("Looking for a UI/UX designer,
-- freelance, 1 month, up to ₹70k"); any signed-in user can apply.
-- The poster reviews applicants (masked cards, like the event
-- attendee list) and connects with the ones they like through the
-- existing contact-request flow.
--
-- HOW TO DEPLOY (dashboard only, no CLI needed):
--   Paste this whole file into the Supabase SQL editor and run it
--   once, BEFORE shipping the app build with the Gigs tab.
--
-- NOTE: the RPCs assume public.profiles has user_id / first_name /
-- last_name / avatar / job_role / company_name / bio / is_hidden
-- (verified against the live schema on 2026-07-04).
-- ============================================================

-- ------------------------------------------------------------
-- Table: one row per posted requirement.
-- category holds a ProfileCategory rawValue (same enum the app
-- uses for profiles), so the Discover category chips filter both
-- people and gigs. Budget/duration/location are free text in v1.
-- is_hidden is the developer's moderation kill-switch, mirroring
-- profiles.is_hidden.
-- ------------------------------------------------------------
create table if not exists public.gig_posts (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid not null references auth.users (id) on delete cascade,
    title         text not null,
    description   text not null,
    category      text not null,
    budget_text   text,
    duration_text text,
    location      text,
    status        text not null default 'open',   -- open | closed
    is_hidden     boolean not null default false,
    created_at    timestamptz not null default now(),
    expires_at    timestamptz not null default (now() + interval '30 days')
);

create index if not exists gig_posts_created_idx
    on public.gig_posts (created_at desc);
create index if not exists gig_posts_user_idx
    on public.gig_posts (user_id);

alter table public.gig_posts enable row level security;

-- Owners manage their own posts; everyone else reads the feed
-- through the get_gig_posts RPC (which joins the poster's masked
-- card and filters hidden/closed/expired posts).
drop policy if exists "users read own gig posts" on public.gig_posts;
create policy "users read own gig posts"
    on public.gig_posts
    for select
    to authenticated
    using (auth.uid() = user_id);

drop policy if exists "users insert own gig posts" on public.gig_posts;
create policy "users insert own gig posts"
    on public.gig_posts
    for insert
    to authenticated
    with check (auth.uid() = user_id);

drop policy if exists "users update own gig posts" on public.gig_posts;
create policy "users update own gig posts"
    on public.gig_posts
    for update
    to authenticated
    using (auth.uid() = user_id);

drop policy if exists "users delete own gig posts" on public.gig_posts;
create policy "users delete own gig posts"
    on public.gig_posts
    for delete
    to authenticated
    using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Table: one row per user per post. Writes go through the
-- apply_to_gig RPC so open/expired/own-post rules are enforced
-- server-side. status is reserved for a future accept/reject flow;
-- v1 connects poster and applicant via contact requests instead.
-- ------------------------------------------------------------
create table if not exists public.gig_applications (
    post_id      uuid not null references public.gig_posts (id) on delete cascade,
    applicant_id uuid not null references auth.users (id) on delete cascade,
    message      text,
    status       text not null default 'pending',   -- pending | accepted | rejected
    created_at   timestamptz not null default now(),
    primary key (post_id, applicant_id)
);

create index if not exists gig_applications_applicant_idx
    on public.gig_applications (applicant_id);

alter table public.gig_applications enable row level security;

-- Applicants see and can withdraw their own applications.
drop policy if exists "applicants read own applications" on public.gig_applications;
create policy "applicants read own applications"
    on public.gig_applications
    for select
    to authenticated
    using (auth.uid() = applicant_id);

drop policy if exists "applicants withdraw own applications" on public.gig_applications;
create policy "applicants withdraw own applications"
    on public.gig_applications
    for delete
    to authenticated
    using (auth.uid() = applicant_id);

-- Posters see and can update (accept/reject) applications to their
-- own posts. Applicant identity is masked via get_gig_applicants.
drop policy if exists "posters read applications to own posts" on public.gig_applications;
create policy "posters read applications to own posts"
    on public.gig_applications
    for select
    to authenticated
    using (exists (
        select 1 from public.gig_posts g
        where g.id = post_id and g.user_id = auth.uid()
    ));

drop policy if exists "posters update applications to own posts" on public.gig_applications;
create policy "posters update applications to own posts"
    on public.gig_applications
    for update
    to authenticated
    using (exists (
        select 1 from public.gig_posts g
        where g.id = post_id and g.user_id = auth.uid()
    ));

-- ------------------------------------------------------------
-- RPC: the gigs feed. Open, unexpired, unhidden posts (including
-- the caller's own, so they see their applicant counts) with the
-- poster's masked card, newest first.
-- ------------------------------------------------------------
-- (Dropped first because re-running this file after the return
-- type changed would otherwise fail.)
drop function if exists public.get_gig_posts();
create or replace function public.get_gig_posts()
returns table (
    id                  uuid,
    user_id             uuid,
    title               text,
    description         text,
    category            text,
    budget_text         text,
    duration_text       text,
    location            text,
    status              text,
    created_at          timestamptz,
    expires_at          timestamptz,
    poster_first_name   text,
    poster_last_name    text,
    poster_avatar       text,
    poster_job_role     text,
    poster_company_name text,
    poster_bio          text,
    applicant_count     bigint,
    has_applied         boolean
)
language sql
security definer
set search_path = public
as $$
    select g.id,
           g.user_id,
           g.title,
           g.description,
           g.category,
           g.budget_text,
           g.duration_text,
           g.location,
           g.status,
           g.created_at,
           g.expires_at,
           coalesce(p.first_name, '')   as poster_first_name,
           coalesce(p.last_name, '')    as poster_last_name,
           coalesce(p.avatar, '')       as poster_avatar,
           coalesce(p.job_role, '')     as poster_job_role,
           coalesce(p.company_name, '') as poster_company_name,
           coalesce(p.bio, '')          as poster_bio,
           (select count(*) from public.gig_applications a
             where a.post_id = g.id)    as applicant_count,
           exists (select 1 from public.gig_applications a
                    where a.post_id = g.id
                      and a.applicant_id = auth.uid()) as has_applied
    from public.gig_posts g
    join public.profiles p on p.user_id = g.user_id
    where g.status = 'open'
      and g.expires_at > now()
      and g.is_hidden = false
      and p.is_hidden = false
      and auth.uid() is not null
    order by g.created_at desc;
$$;

revoke execute on function public.get_gig_posts() from public, anon;
grant execute on function public.get_gig_posts() to authenticated;

-- ------------------------------------------------------------
-- RPC: apply to a gig. Enforces the rules server-side: signed in,
-- post open/unexpired/unhidden, not your own post. Idempotent —
-- re-applying keeps the original application. (To gate applying
-- behind Pro later: add `and p.is_premium_user` on the caller's
-- profile here — one line, no schema change.)
-- ------------------------------------------------------------
create or replace function public.apply_to_gig(p_post_id uuid, p_message text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid  uuid := auth.uid();
    v_post public.gig_posts%rowtype;
begin
    if v_uid is null then
        raise exception 'not signed in';
    end if;

    select * into v_post from public.gig_posts where id = p_post_id;
    if not found or v_post.status <> 'open'
       or v_post.expires_at <= now() or v_post.is_hidden then
        raise exception 'this gig is no longer open';
    end if;
    if v_post.user_id = v_uid then
        raise exception 'you cannot apply to your own gig';
    end if;

    insert into public.gig_applications (post_id, applicant_id, message)
    values (p_post_id, v_uid, nullif(trim(p_message), ''))
    on conflict (post_id, applicant_id) do nothing;
end;
$$;

revoke execute on function public.apply_to_gig(uuid, text) from public, anon;
grant execute on function public.apply_to_gig(uuid, text) to authenticated;

-- ------------------------------------------------------------
-- RPC: the applicant list for one of the caller's own posts.
-- Masked cards only (name, avatar, job title, company, bio) plus
-- the applicant's pitch message — same privacy rule as the event
-- attendee list; the full card unlocks via contact requests.
-- ------------------------------------------------------------
create or replace function public.get_gig_applicants(p_post_id uuid)
returns table (
    applicant_id uuid,
    first_name   text,
    last_name    text,
    avatar       text,
    job_role     text,
    company_name text,
    bio          text,
    message      text,
    status       text,
    applied_at   timestamptz
)
language sql
security definer
set search_path = public
as $$
    select a.applicant_id,
           coalesce(p.first_name, '')   as first_name,
           coalesce(p.last_name, '')    as last_name,
           coalesce(p.avatar, '')       as avatar,
           coalesce(p.job_role, '')     as job_role,
           coalesce(p.company_name, '') as company_name,
           coalesce(p.bio, '')          as bio,
           coalesce(a.message, '')      as message,
           a.status,
           a.created_at                 as applied_at
    from public.gig_applications a
    join public.profiles p on p.user_id = a.applicant_id
    where a.post_id = p_post_id
      and p.is_hidden = false
      and exists (select 1 from public.gig_posts g
                   where g.id = p_post_id and g.user_id = auth.uid())
    order by a.created_at asc;
$$;

revoke execute on function public.get_gig_applicants(uuid) from public, anon;
grant execute on function public.get_gig_applicants(uuid) to authenticated;

-- ------------------------------------------------------------
-- Schedule: daily tidy-up (extensions already installed by
-- events.sql). Closes posts past their expiry, then deletes posts
-- that have been closed/expired for 30 days.
-- ------------------------------------------------------------
select cron.unschedule('cleanup-gigs')
    where exists (select 1 from cron.job where jobname = 'cleanup-gigs');
select cron.schedule(
    'cleanup-gigs',
    '45 3 * * *',
    $$
    update public.gig_posts
       set status = 'closed'
     where status = 'open' and expires_at <= now();

    delete from public.gig_posts
     where expires_at < now() - interval '30 days';
    $$
);
