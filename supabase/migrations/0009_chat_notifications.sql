-- ХУВААЛЦ — chat + notifications (Phase 8, spec sections 23, 24, 32).
--
-- `conversations`/`conversation_members`/`messages`/`notifications`
-- already existed with RLS from `0001`/`0002`. What was still missing:
--   1. A way to actually *create* a conversation — there's no client
--      insert policy on `conversations`/`conversation_members` (spec
--      section 32: only members can be added, and only in the shape the
--      backend allows — a client shouldn't be able to invite itself into
--      an arbitrary booking's conversation).
--   2. Server-side enforcement of `messages.flagged_for_review` (spec
--      section 23) — a client-set boolean on the client's own message is
--      not a signal anyone should trust.
--   3. Anything that actually populates `public.notifications` —
--      `notifications_select_own`/`_update_own` exist but there's no
--      insert policy at all (by design: notifications are backend-only,
--      same posture as `payments`), and nothing was writing to it yet.

-- ---------------------------------------------------------------------
-- 1. Conversation creation
-- ---------------------------------------------------------------------

-- A booking has at most one conversation. Nullable+unique (rather than
-- not-null+unique) because `conversations.asset_id`-only rows — a
-- pre-booking inquiry thread — are a plausible future use of this same
-- table that this constraint shouldn't block.
alter table public.conversations
  add constraint conversations_booking_id_unique unique (booking_id);

create or replace function public.get_or_create_conversation_for_booking(p_booking_id uuid)
returns public.conversations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
  v_conversation public.conversations;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id;
  if v_booking is null then
    raise exception 'booking_not_found';
  end if;
  if v_uid <> v_booking.renter_id and v_uid <> v_booking.owner_id then
    raise exception 'not_authorized';
  end if;

  select * into v_conversation from public.conversations where booking_id = p_booking_id;
  if v_conversation is not null then
    return v_conversation;
  end if;

  -- Two participants opening the chat for the first time at the same
  -- moment could both reach this point finding no existing conversation
  -- — the unique constraint above turns the loser's insert into a
  -- unique_violation instead of a duplicate row; catch it and just
  -- return what the winner created.
  begin
    insert into public.conversations (booking_id, asset_id)
    values (p_booking_id, v_booking.asset_id)
    returning * into v_conversation;
  exception when unique_violation then
    select * into v_conversation from public.conversations where booking_id = p_booking_id;
  end;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_conversation.id, v_booking.renter_id), (v_conversation.id, v_booking.owner_id)
  on conflict do nothing;

  return v_conversation;
end;
$$;

revoke all on function public.get_or_create_conversation_for_booking(uuid) from public;
grant execute on function public.get_or_create_conversation_for_booking(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Server-side message flagging
-- ---------------------------------------------------------------------

-- Heuristic only — a cheap, deterministic signal for a human reviewer to
-- prioritize, not a moderation system: a run of 7+ digits (phone
-- numbers) or a handful of common off-platform-contact/transfer
-- keywords. This will both miss real attempts to move a deal off-app and
-- occasionally flag an innocent message (someone sharing an address).
-- Always overwrites whatever the client sent, the same "never trust the
-- client" posture as everything money-shaped in this schema — see spec
-- section 23. A real classifier belongs in the Phase 10/11 AI layer.
create or replace function public.flag_suspicious_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.flagged_for_review := (
    new.body is not null
    and (
      new.body ~ '[0-9][0-9\-\s]{6,}[0-9]'
      or new.body ~* '(вотсап|whatsapp|wechat|messenger|данс(аар)?|шилжүүлэг|bank ?transfer|iban)'
    )
  );
  return new;
end;
$$;

drop trigger if exists flag_suspicious_message on public.messages;
create trigger flag_suspicious_message
  before insert on public.messages
  for each row execute function public.flag_suspicious_message();

-- ---------------------------------------------------------------------
-- 3. Notifications
-- ---------------------------------------------------------------------

-- `title`/`body` here are a plain-English fallback only — the Flutter
-- client renders localized copy keyed off `event_type` instead (same
-- pattern as `BookingStatus`/`PaymentStatus` → `AppLocalizations`) and
-- only falls back to these columns for an `event_type` it doesn't
-- recognize. Generating fully localized text server-side isn't possible
-- without knowing the recipient's language preference, which lives in
-- `LocalCacheService` on-device, not in this schema.
--
-- No push delivery: these rows only power the in-app notification
-- center. Actually delivering a push notification needs Firebase Cloud
-- Messaging, which needs a `flutterfire configure` run and platform
-- projects this scaffold doesn't have (see README "Known issues") — so
-- a notification here is only ever seen if the user opens the app and
-- checks, not delivered while it's closed. That gap is real and worth
-- flagging rather than pretending push works because the row exists.

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking_id uuid;
  v_preview text;
  v_member record;
begin
  select booking_id into v_booking_id from public.conversations where id = new.conversation_id;
  v_preview := left(coalesce(new.body, ''), 120);

  for v_member in
    select user_id from public.conversation_members
    where conversation_id = new.conversation_id
      and (new.sender_id is null or user_id <> new.sender_id)
  loop
    insert into public.notifications (user_id, event_type, title, body, deep_link)
    values (
      v_member.user_id,
      'new_message',
      'New message',
      v_preview,
      case when v_booking_id is not null then '/booking/' || v_booking_id || '/chat' else null end
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists notify_new_message on public.messages;
create trigger notify_new_message
  after insert on public.messages
  for each row execute function public.notify_new_message();

create or replace function public.notify_booking_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_recipient uuid;
  v_event_type text;
  v_title text;
begin
  if tg_op = 'INSERT' then
    -- The renter is always the one calling `create_booking` — notify the
    -- owner about the new request.
    v_recipient := new.owner_id;
    v_event_type := 'booking_pending';
    v_title := 'New booking request';
  else
    if new.status = old.status then
      return new;
    end if;
    v_event_type := 'booking_' || new.status;
    v_title := case new.status
      when 'confirmed' then 'Booking confirmed'
      when 'rejected' then 'Booking rejected'
      when 'cancelled' then 'Booking cancelled'
      else null
    end;
    if v_title is null then
      return new; -- no notification copy for statuses that aren't a distinct "event" yet
    end if;
    -- Notify whichever participant didn't just make this call; if we
    -- can't resolve an actor (e.g. a future background job), default to
    -- the renter, since owner-initiated transitions are the common case.
    if v_actor = new.owner_id then
      v_recipient := new.renter_id;
    else
      v_recipient := new.owner_id;
    end if;
  end if;

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  values (v_recipient, v_event_type, v_title, coalesce(new.cancellation_reason, ''), '/booking/' || new.id);

  return new;
end;
$$;

drop trigger if exists notify_booking_status_change on public.bookings;
create trigger notify_booking_status_change
  after insert or update on public.bookings
  for each row execute function public.notify_booking_status_change();
