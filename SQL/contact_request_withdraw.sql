-- Withdraw (delete) a pending contact request the caller sent.
-- Run this in the Supabase SQL editor. Used by the "Pending" pill so
-- any user can cancel a connect request they sent.

create or replace function public.withdraw_contact_request(p_receiver_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.contact_requests
  where sender_id = auth.uid()
    and receiver_id = p_receiver_id
    and status = 'pending';
$$;

grant execute on function public.withdraw_contact_request(uuid) to authenticated;
