-- ХУВААЛЦ — bug-fix pass over the full schema (post-Phase-12 review).
--
-- Six concrete, verified defects found by re-reading every RPC/RLS policy
-- against its actual callers, none of them new features — each is a
-- narrow, targeted fix for a specific wrong behavior.

-- ---------------------------------------------------------------------
-- 1. cancel_booking: a 'confirmed' booking that has already been paid
--    (payments.status = 'paid') has already had credit_wallet_for_payment
--    move real money into the owner's pending_balance (0008). Plain
--    cancellation has no mechanism to reverse that credit or refund the
--    payment, so cancelling here silently left the owner permanently
--    credited for a rental that never happened, with no record anything
--    was wrong. Block that specific transition instead — a paid,
--    confirmed booking must go through the dispute flow
--    (validate_dispute_insert already allows 'confirmed' bookings, see
--    0010), which at least surfaces the problem to an admin.
-- ---------------------------------------------------------------------

create or replace function public.cancel_booking(p_booking_id uuid, p_reason text default null)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
  v_has_paid_payment boolean;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found';
  end if;
  if v_booking.renter_id != v_uid and v_booking.owner_id != v_uid then
    raise exception 'not_authorized';
  end if;
  if v_booking.status not in ('pending', 'confirmed') then
    raise exception 'invalid_status_transition';
  end if;

  if v_booking.status = 'confirmed' then
    select exists(
      select 1 from public.payments
      where booking_id = p_booking_id and status = 'paid'
    ) into v_has_paid_payment;
    if v_has_paid_payment then
      raise exception 'cannot_cancel_paid_booking';
    end if;
  end if;

  update public.bookings
  set status = 'cancelled', cancellation_reason = p_reason
  where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end;
$$;

-- ---------------------------------------------------------------------
-- 2. credit_wallet_for_payment: the "already credited?" check
--    (wallet_transactions existence) ran without locking anything first,
--    so two concurrent calls for the same payment (e.g. a duplicate
--    webhook delivery — mock-complete-payment's own comment already
--    flags this as best-effort/non-transactional) could both pass the
--    check before either had inserted its row, double-crediting the
--    owner's wallet. Lock the booking row up front so concurrent calls
--    for the same booking serialize on it instead.
-- ---------------------------------------------------------------------

create or replace function public.credit_wallet_for_payment(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments;
  v_booking public.bookings;
  v_owner_share numeric(12, 2);
  v_already_credited boolean;
begin
  select * into v_payment from public.payments where id = p_payment_id;
  if v_payment is null then
    raise exception 'payment_not_found';
  end if;
  if v_payment.status <> 'paid' then
    raise exception 'payment_not_paid';
  end if;

  select * into v_booking from public.bookings where id = v_payment.booking_id for update;
  if v_booking is null then
    raise exception 'booking_not_found';
  end if;

  select exists(
    select 1 from public.wallet_transactions
    where booking_id = v_payment.booking_id and type = 'booking_income'
  ) into v_already_credited;
  if v_already_credited then
    return; -- already credited for this booking; nothing to do
  end if;

  v_owner_share := v_booking.rental_amount + v_booking.delivery_fee;

  update public.wallets
    set pending_balance = pending_balance + v_owner_share,
        total_earned = total_earned + v_owner_share,
        updated_at = now()
    where user_id = v_booking.owner_id;

  if not found then
    raise exception 'owner_wallet_not_found';
  end if;

  insert into public.wallet_transactions (wallet_user_id, booking_id, type, amount, description)
  values (
    v_booking.owner_id,
    v_booking.id,
    'booking_income',
    v_owner_share,
    'Booking payment received (pending release)'
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 3. reviews_insert_participant: checked that the *reviewer* is a
--    participant on a completed booking, but never checked that
--    `reviewee_id` is actually the *other* participant on that same
--    booking. As written, any user with one completed booking could
--    insert a review naming any `reviewee_id` at all, which
--    update_profile_rating_on_review (0010) then folds straight into
--    that arbitrary user's public rating/review_count.
-- ---------------------------------------------------------------------

drop policy if exists reviews_insert_participant on public.reviews;

create policy reviews_insert_participant on public.reviews
  for insert with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.bookings b
      where b.id = reviews.booking_id
        and b.status = 'completed'
        and (
          (b.renter_id = auth.uid() and b.owner_id = reviews.reviewee_id)
          or (b.owner_id = auth.uid() and b.renter_id = reviews.reviewee_id)
        )
    )
  );

-- ---------------------------------------------------------------------
-- 4. assets_update_own: `enforce_asset_status_transition` (0012) already
--    stops a non-admin owner from PATCHing `status` directly, but nothing
--    stopped the same owner from PATCHing `is_featured` directly via
--    PostgREST — a column that's admin-only in intent (it's read by the
--    "Closest"/browse sort ordering in the client) but had no
--    server-side guard at all. Extend the same trigger to cover it,
--    rather than adding a second one.
-- ---------------------------------------------------------------------

create or replace function public.enforce_asset_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'pending_review';
    new.is_featured := false;
    return new;
  end if;

  -- tg_op = 'UPDATE'
  if new.status is distinct from old.status then
    if public.is_admin(auth.uid()) then
      null;
    elsif auth.uid() = old.owner_id and old.status = 'draft' and new.status = 'pending_review' then
      null;
    else
      raise exception 'not_authorized_status_change';
    end if;
  end if;

  if new.is_featured is distinct from old.is_featured and not public.is_admin(auth.uid()) then
    raise exception 'not_authorized_featured_change';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. conversation_members_update_own: RLS only checked `user_id =
--    auth.uid()`, which is correct for the column this policy actually
--    exists for (`last_read_at`, self-updated on read), but it also let
--    a member freely rewrite their own `is_blocked` flag — the one
--    column on this table that's explicitly meant to be set by something
--    *other* than the member themselves (a moderation action), and whose
--    entire point (gating `messages_insert_member`, see 0002) is defeated
--    if the blocked party can just clear it themselves. RLS alone can't
--    express "this column, not that one" — use a column-level GRANT.
-- ---------------------------------------------------------------------

revoke update on public.conversation_members from authenticated;
grant update (last_read_at) on public.conversation_members to authenticated;

-- ---------------------------------------------------------------------
-- 6. confirm_condition_report: didn't check the booking's current status
--    at all. If a dispute is raised on a 'confirmed' booking mid-pickup
--    (one side already submitted+auto-confirmed the pickup report, the
--    other hasn't confirmed yet), the other side could still call
--    confirm_condition_report while the booking sits at 'disputed'. That
--    completes both-sides-confirmed on the report, firing
--    advance_booking_on_condition_report — but its `where status =
--    'confirmed'` guard silently no-ops because the booking is
--    'disputed', not 'confirmed'. The report is now permanently fully
--    confirmed with no further insert/update ever coming to re-fire that
--    trigger, so once the dispute resolves and the booking status is
--    restored, it can never advance past 'confirmed' again. Block
--    confirming while disputed, matching the same check
--    validate_and_autoconfirm_condition_report already applies to new
--    report submissions.
-- ---------------------------------------------------------------------

create or replace function public.confirm_condition_report(p_report_id uuid)
returns public.condition_reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_report public.condition_reports;
  v_booking public.bookings;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;

  select * into v_report from public.condition_reports where id = p_report_id for update;
  if not found then
    raise exception 'report_not_found';
  end if;

  select * into v_booking from public.bookings where id = v_report.booking_id;
  if v_booking is null then
    raise exception 'booking_not_found';
  end if;
  if v_booking.renter_id != v_uid and v_booking.owner_id != v_uid then
    raise exception 'not_authorized';
  end if;
  if v_booking.status = 'disputed' then
    raise exception 'booking_disputed';
  end if;

  if v_uid = v_booking.renter_id and v_report.confirmed_by_renter_at is null then
    update public.condition_reports set confirmed_by_renter_at = now()
      where id = p_report_id returning * into v_report;
  elsif v_uid = v_booking.owner_id and v_report.confirmed_by_owner_at is null then
    update public.condition_reports set confirmed_by_owner_at = now()
      where id = p_report_id returning * into v_report;
  end if;
  -- else: this party already confirmed (or was the original submitter,
  -- auto-confirmed at insert time) — nothing to do, return as-is.

  return v_report;
end;
$$;
