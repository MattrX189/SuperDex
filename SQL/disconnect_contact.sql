-- ============================================================
-- SuperDex: disconnect from someone you're connected with
-- ============================================================
--
-- The undo for a connect request. Accepting a request saves the two
-- people into each other's contacts (respond_to_contact_request); this
-- removes both of those contact rows and any request between them, so
-- neither keeps the other's full card and either can send a fresh
-- connect request later.
--
-- Interactions (the meetings table) and deck members are left alone — they're the
-- caller's own notes.
--
-- Used by the "Connected" pill → Disconnect (Contacts → From Phone,
-- Discover).
--
-- HOW TO DEPLOY: run this in the Supabase SQL editor.
-- ============================================================

create or replace function public.disconnect_contact(p_other_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  delete from public.contacts
  where (user_id = auth.uid() and contact_user_id = p_other_id)
     or (user_id = p_other_id and contact_user_id = auth.uid());

  delete from public.contact_requests
  where (sender_id = auth.uid() and receiver_id = p_other_id)
     or (sender_id = p_other_id and receiver_id = auth.uid());
end;
$$;

revoke execute on function public.disconnect_contact(uuid) from anon, public;
grant execute on function public.disconnect_contact(uuid) to authenticated;
