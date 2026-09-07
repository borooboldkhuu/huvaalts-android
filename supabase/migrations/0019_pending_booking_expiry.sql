-- ХУВААЛЦ — pending-booking auto-expiry (spec section 17 follow-up).
--
-- Why this migration exists: README's "Known issues" flagged that
-- nothing ever auto-cancels a `pending` booking the owner never responds
-- to. That matters because a `pending` booking isn't a passive record —
-- it counts toward `bookings_no_overlap` (0001's exclusion constraint)
-- and `asset_booked_ranges` (0007), so a forgotten or adversarial
-- request ties up an asset's dates indefinitely until someone explicitly
-- cancels it. This migration adds the sweep function that fixes that;
-- 0020 wires it to a schedule.
--
-- TTL: 48 hours from `bookings.created_at`. Hardcoded the same way
-- `create_booking`'s commission was hardcoded before Phase 11 added
-- `platform_settings` — an admin-configurable TTL is a reasonable future
-- follow-up (add a column to `platform_settings`, read it here instead
-- of the literal `interval '48 hours'` below), not required for this to
-- be correct.
create or replace function public.expire_stale_pending_bookings()
returns setof public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
begin
  -- `for update skip locked`: a booking currently being confirmed,
  -- rejected, or cancelled by a participant (which each take their own
  -- `select ... for update` lock — see 0006) is simply skipped this
  -- sweep rather than blocking on their lock; it'll be picked up next
  -- run if it's somehow still `pending` and still stale then.
  for v_booking in
    select * from public.bookings
    where status = 'pending'
      and created_at < now() - interval '48 hours'
    order by created_at
    for update skip locked
  loop
    update public.bookings
    set status = 'cancelled', cancellation_reason = 'expired_no_owner_response'
    where id = v_booking.id
    returning * into v_booking;
    return next v_booking;
  end loop;
  return;
end;
$$;

-- Deliberately NOT granted to `authenticated` — this walks and cancels
-- *other people's* bookings by design, which is a system/maintenance
-- operation, not something any signed-in user should be able to invoke
-- on demand. Only `service_role` (an Edge Function, if one ever calls
-- this directly) or a `pg_cron` job (runs as the scheduling role, which
-- bypasses grants) can call it — same pattern as
-- `credit_wallet_for_payment`/`credit_wallet_for_topup` (0008, 0017).
revoke all on function public.expire_stale_pending_bookings() from public;
grant execute on function public.expire_stale_pending_bookings() to service_role;

-- ---------------------------------------------------------------------
-- notify_booking_status_change fix: a system-initiated transition (no
-- `auth.uid()`, e.g. the sweep above) previously fell into the same
-- branch as "the renter acted" and only ever notified the owner — the
-- renter whose own booking just got auto-cancelled was never told.
-- Redefined so an unresolvable actor notifies BOTH participants instead
-- of arbitrarily picking one side; behavior for every existing
-- client-called RPC (which always has `auth.uid()` set) is unchanged.
-- ---------------------------------------------------------------------
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
    v_recipient := new.owner_id;
    v_event_type := 'booking_pending';
    v_title := 'New booking request';
    insert into public.notifications (user_id, event_type, title, body, deep_link)
    values (v_recipient, v_event_type, v_title, coalesce(new.cancellation_reason, ''), '/booking/' || new.id);
    return new;
  end if;

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

  if v_actor is null then
    insert into public.notifications (user_id, event_type, title, body, deep_link)
    values (new.owner_id, v_event_type, v_title, coalesce(new.cancellation_reason, ''), '/booking/' || new.id);
    insert into public.notifications (user_id, event_type, title, body, deep_link)
    values (new.renter_id, v_event_type, v_title, coalesce(new.cancellation_reason, ''), '/booking/' || new.id);
    return new;
  end if;

  -- Notify whichever participant didn't just make this call.
  if v_actor = new.owner_id then
    v_recipient := new.renter_id;
  else
    v_recipient := new.owner_id;
  end if;

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  values (v_recipient, v_event_type, v_title, coalesce(new.cancellation_reason, ''), '/booking/' || new.id);

  return new;
end;
$$;
