-- ============================================================
-- SuperDex: push notifications — device tokens
-- ============================================================
--
-- Each iPhone that allows notifications registers its APNs device
-- token here. The `send-push` Edge Function (supabase/functions/
-- send-push) reads this table with the service role to deliver pushes,
-- and deletes tokens Apple reports as dead.
--
-- Registration goes through SECURITY DEFINER functions rather than
-- direct table writes, so a phone that's signed out of one account and
-- into another simply moves its token to the new user.
--
-- `environment` is 'sandbox' for Xcode/debug builds and 'production'
-- for TestFlight/App Store — Apple uses different servers for each.
--
-- Run this first, then deploy the function and set up the webhook
-- (steps in supabase/functions/send-push/index.ts).
-- HOW TO DEPLOY: run in the Supabase SQL editor. Safe to re-run.
-- ============================================================

create table if not exists public.device_tokens (
    token        text primary key,
    user_id      uuid not null references auth.users (id) on delete cascade,
    platform     text not null default 'ios',
    environment  text not null default 'production',  -- sandbox | production
    updated_at   timestamptz not null default now()
);

-- If device_tokens already existed (an earlier setup had token, user_id,
-- environment, updated_at), bring it in line with what's used below.
alter table public.device_tokens add column if not exists platform text not null default 'ios';
alter table public.device_tokens add column if not exists environment text not null default 'production';
alter table public.device_tokens add column if not exists updated_at timestamptz not null default now();
-- register_device_token upserts on the token, which needs it to be unique.
create unique index if not exists device_tokens_token_key on public.device_tokens (token);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Users can see their own devices; all writes go through the functions below.
drop policy if exists "device_tokens: read own" on public.device_tokens;
create policy "device_tokens: read own" on public.device_tokens
    for select to authenticated using (user_id = auth.uid());

-- Register (or move) this device's token to the signed-in user.
create or replace function public.register_device_token(
    p_token text,
    p_environment text default 'production'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if coalesce(length(p_token), 0) < 32 then
    raise exception 'invalid token';
  end if;

  insert into public.device_tokens (token, user_id, platform, environment, updated_at)
  values (p_token, auth.uid(), 'ios',
          case when p_environment = 'sandbox' then 'sandbox' else 'production' end,
          now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        environment = excluded.environment,
        updated_at = now();
end;
$$;

-- Stop pushes to this device for the signed-in user (called on sign-out).
create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
$$;

revoke execute on function public.register_device_token(text, text) from anon, public;
revoke execute on function public.unregister_device_token(text) from anon, public;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;
