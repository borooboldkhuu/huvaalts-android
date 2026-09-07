-- ХУВААЛЦ — pickup/return flow, review eligibility, and dispute lifecycle
-- (Phase 9, spec sections 17, 20, 25, 26, 27, 34).
--
-- This migration closes three gaps that earlier phases deliberately left
-- open and documented:
--
-- 1. Nothing ever moved a booking to 'active' or 'completed'. Those two
--    `booking_status` enum values have existed since `0001_init_schema.sql`
--    but no code path ever set them — `0006_booking_rpc.sql`'s own header
--    comment on `cancel_booking` calls this out explicitly ("that's spec
--    section 26 territory (Phase 9), not this function"). Below, a
--    pickup condition report (confirmed by both parties) moves a booking
--    `confirmed` -> `active`, and a return condition report (also
--    confirmed by both parties) moves it `active` -> `completed`.
-- 2. `0008_wallet_credit_rpc.sql`'s `credit_wallet_for_payment` credits the
--    owner's `pending_balance` and explicitly documents that moving it to
--    `available_balance` "is supposed to happen once a booking is
--    confirmed *returned* — a condition report / return flow that doesn't
--    exist until Phase 9." That release happens below, the moment a
--    return condition report reaches both-parties-confirmed.
-- 3. `reviews_insert_participant` (0002) has required `booking.status =
--    'completed'` since Phase 0/1, but nothing could ever reach that
--    status — so the reviews table has been structurally unreachable
--    until this migration. Likewise `profiles.rating`/`review_count`
--    have sat at their default of 0 for every user because nothing
--    populated them; a trigger below finally does.
--
-- Also: `disputes` gets an actual lifecycle (raising one flips the
-- booking to 'disputed' and blocks new condition reports on it;
-- resolving/rejecting one restores whatever status the booking had
-- before) — the table existed with working RLS since Phase 0/1 but,
-- like reviews, was disconnected from the booking state machine.

-- ---------------------------------------------------------------------
-- Schema additions
-- ---------------------------------------------------------------------

alter table public.bookings
  add column if not exists payout_released_at timestamptz,
  add column if not exists pre_dispute_status booking_status;

comment on column public.bookings.payout_released_at is
  'Set once, the moment the owner''s pending_balance for this booking is '
  'moved to available_balance (see advance_booking_on_condition_report '
  'below). Guards against releasing the same booking''s payout twice.';

comment on column public.bookings.pre_dispute_status is
  'The booking''s status immediately before a dispute flipped it to '
  '''disputed'' (see mark_booking_disputed) — restored by '
  'restore_booking_status_after_dispute_resolution once the dispute is '
  'resolved or rejected. Null whenever the booking isn''t disputed.';

-- Wallet balances were never actually constrained to be non-negative.
-- Every existing mutator (credit_wallet_for_payment, the release logic
-- below) only ever adds to pending_balance/available_balance or moves an
-- exact amount between them, so this should never trip in practice — but
-- "should never" isn't the same guarantee as a database-level constraint,
-- and spec section 34 asks for wallet balance to never be client-trusted
-- *or* silently wrong.
alter table public.wallets
  add constraint wallets_available_balance_non_negative check (available_balance >= 0),
  add constraint wallets_pending_balance_non_negative check (pending_balance >= 0);

-- One condition report per booking per stage — a pickup report and a
-- return report, not an unbounded log of edits. If a submitted report
-- needs correcting, that's dispute territory (or a Phase 11 admin fix),
-- not a second insert.
alter table public.condition_reports
  add constraint condition_reports_booking_stage_unique unique (booking_id, stage);

-- Only one *active* dispute per booking at a time — belt-and-suspenders
-- alongside validate_dispute_insert's friendlier 'dispute_already_open'
-- error below (this index is what actually enforces it under
-- concurrency; the trigger just gives a nicer message in the common
-- non-racing case).
create unique index disputes_one_open_per_booking_idx on public.disputes (booking_id)
  where status in ('open', 'under_review', 'escalated');

-- ---------------------------------------------------------------------
-- Condition reports: submission validation + auto-confirmation
-- ---------------------------------------------------------------------
--
-- `condition_reports_insert_participant` (0002) already lets a booking
-- participant insert their own report directly — this trigger adds the
-- business rules RLS alone can't express (booking must be in the right
-- status, pickup requires an actual paid payment first) and auto-confirms
-- the row on behalf of whoever just submitted it, since submitting *is*
-- attesting to it. The other participant confirms separately via
-- confirm_condition_report below.
create or replace function public.validate_and_autoconfirm_condition_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_has_paid_payment boolean;
begin
  select * into v_booking from public.bookings where id = new.booking_id for update;
  if v_booking is null then
    raise exception 'booking_not_found';
  end if;
  if new.submitted_by != v_booking.renter_id and new.submitted_by != v_booking.owner_id then
    raise exception 'not_authorized';
  end if;
  if v_booking.status = 'disputed' then
    raise exception 'booking_disputed';
  end if;

  if new.stage = 'pickup' then
    if v_booking.status != 'confirmed' then
      raise exception 'invalid_status_for_pickup_report';
    end if;
    select exists(
      select 1 from public.payments
      where booking_id = v_booking.id and status = 'paid'
    ) into v_has_paid_payment;
    if not v_has_paid_payment then
      raise exception 'payment_required_before_pickup';
    end if;
  elsif new.stage = 'return' then
    if v_booking.status != 'active' then
      raise exception 'invalid_status_for_return_report';
    end if;
  end if;

  if new.submitted_by = v_booking.renter_id then
    new.confirmed_by_renter_at := now();
  elsif new.submitted_by = v_booking.owner_id then
    new.confirmed_by_owner_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists validate_and_autoconfirm_condition_report on public.condition_reports;
create trigger validate_and_autoconfirm_condition_report
  before insert on public.condition_reports
  for each row execute function public.validate_and_autoconfirm_condition_report();

-- The *other* participant's confirmation. condition_reports has no client
-- update policy at all (see 0002) — this SECURITY DEFINER function is the
-- only way `confirmed_by_renter_at`/`confirmed_by_owner_at` ever change
-- after insert. Idempotent: calling it again once your own side is
-- already confirmed (or after the booking has already advanced) just
-- returns the row as-is rather than erroring, so a double-tap in the UI
-- is harmless.
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

revoke all on function public.confirm_condition_report(uuid) from public;
grant execute on function public.confirm_condition_report(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Condition reports: advancing the booking once both sides confirm
-- ---------------------------------------------------------------------
--
-- Fires after both the insert (submitter's own auto-confirmation) and
-- every update (the other party's confirm_condition_report call) — the
-- both-non-null check means it only ever *acts* on the transition that
-- actually completes both confirmations, regardless of which statement
-- triggered it.
create or replace function public.advance_booking_on_condition_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_owner_share numeric(12, 2);
begin
  if new.confirmed_by_renter_at is null or new.confirmed_by_owner_at is null then
    return new;
  end if;

  if new.stage = 'pickup' then
    update public.bookings set status = 'active', updated_at = now()
      where id = new.booking_id and status = 'confirmed';
    return new;
  end if;

  if new.stage = 'return' then
    update public.bookings set status = 'completed', updated_at = now()
      where id = new.booking_id and status = 'active'
      returning * into v_booking;

    if not found then
      return new; -- already completed (or in some other state) — nothing to do
    end if;

    -- Release the owner's earned share from pending_balance to
    -- available_balance — see this migration's header comment and
    -- 0008_wallet_credit_rpc.sql's for why this couldn't happen until now.
    if v_booking.payout_released_at is null then
      select amount into v_owner_share
        from public.wallet_transactions
        where booking_id = v_booking.id and type = 'booking_income'
        limit 1;

      if v_owner_share is not null then
        update public.wallets
          set pending_balance = pending_balance - v_owner_share,
              available_balance = available_balance + v_owner_share,
              updated_at = now()
          where user_id = v_booking.owner_id;

        insert into public.wallet_transactions (wallet_user_id, booking_id, type, amount, description)
        values (
          v_booking.owner_id,
          v_booking.id,
          'adjustment',
          v_owner_share,
          'Pending balance released to available (booking confirmed returned)'
        );
      end if;
      -- v_owner_share is null when the booking was somehow marked
      -- returned without ever having a credited payment (shouldn't
      -- happen — pickup requires a paid payment — but this is not the
      -- place to raise and roll back a booking someone just confirmed
      -- physically returned; it's logged as a no-op release instead).

      update public.bookings set payout_released_at = now() where id = v_booking.id;
    end if;

    update public.profiles set completed_rentals_count = completed_rentals_count + 1, updated_at = now()
      where user_id in (v_booking.renter_id, v_booking.owner_id);
  end if;

  return new;
end;
$$;

drop trigger if exists advance_booking_on_condition_report on public.condition_reports;
create trigger advance_booking_on_condition_report
  after insert or update on public.condition_reports
  for each row execute function public.advance_booking_on_condition_report();

-- ---------------------------------------------------------------------
-- Reviews: keep profiles.rating / review_count in sync
-- ---------------------------------------------------------------------
--
-- These two columns have existed on public.profiles since 0001 but
-- nothing ever wrote to them, because nothing could insert a review
-- before a booking could reach 'completed'. Recomputed from every review
-- the reviewee has ever received rather than incrementally adjusted —
-- reviews can't be edited or deleted this phase, so this is equivalent
-- to an incremental update but simpler to reason about and self-healing
-- if it's ever re-run by hand.
create or replace function public.update_profile_rating_on_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric(3, 2);
  v_count int;
begin
  select round(avg(rating)::numeric, 2), count(*)
    into v_avg, v_count
    from public.reviews
    where reviewee_id = new.reviewee_id;

  update public.profiles
    set rating = coalesce(v_avg, 0), review_count = v_count, updated_at = now()
    where user_id = new.reviewee_id;

  return new;
end;
$$;

drop trigger if exists update_profile_rating_on_review on public.reviews;
create trigger update_profile_rating_on_review
  after insert on public.reviews
  for each row execute function public.update_profile_rating_on_review();

-- ---------------------------------------------------------------------
-- Disputes: booking lifecycle side effects
-- ---------------------------------------------------------------------

create or replace function public.validate_dispute_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id = new.booking_id;
  if v_booking is null then
    raise exception 'booking_not_found';
  end if;
  if v_booking.status = 'disputed' then
    raise exception 'dispute_already_open';
  end if;
  if v_booking.status not in ('confirmed', 'active', 'completed') then
    raise exception 'booking_not_disputable';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_dispute_insert on public.disputes;
create trigger validate_dispute_insert
  before insert on public.disputes
  for each row execute function public.validate_dispute_insert();

-- Raising a dispute flips the booking to 'disputed' (blocking new
-- condition reports on it — see validate_and_autoconfirm_condition_report
-- above) and remembers what status to restore on resolution.
create or replace function public.mark_booking_disputed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_recipient uuid;
begin
  update public.bookings
    set pre_dispute_status = status, status = 'disputed', updated_at = now()
    where id = new.booking_id
    returning * into v_booking;

  if not found then
    return new;
  end if;

  v_recipient := case when new.raised_by = v_booking.owner_id then v_booking.renter_id else v_booking.owner_id end;

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  values (
    v_recipient,
    'dispute_opened',
    'A dispute was opened',
    left(new.description, 120),
    '/booking/' || v_booking.id
  );

  return new;
end;
$$;

drop trigger if exists mark_booking_disputed on public.disputes;
create trigger mark_booking_disputed
  after insert on public.disputes
  for each row execute function public.mark_booking_disputed();

-- Resolving/rejecting a dispute (currently only possible via
-- disputes_update_admin — direct table access, since the admin
-- dashboard's own moderation UI is Phase 11) restores the booking to
-- whatever status it had before the dispute and notifies both
-- participants. Transitions between 'open'/'under_review'/'escalated'
-- (still an active dispute, just changing sub-state) deliberately don't
-- touch the booking at all.
create or replace function public.restore_booking_status_after_dispute_resolution()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_event text;
  v_title text;
begin
  if new.status = old.status then
    return new;
  end if;
  if old.status not in ('open', 'under_review', 'escalated') then
    return new;
  end if;
  if new.status not in ('resolved', 'rejected') then
    return new;
  end if;

  update public.bookings
    set status = coalesce(pre_dispute_status, 'completed'), pre_dispute_status = null, updated_at = now()
    where id = new.booking_id and status = 'disputed'
    returning * into v_booking;

  if not found then
    return new; -- booking status already moved on some other way — don't clobber it
  end if;

  v_event := case new.status when 'resolved' then 'dispute_resolved' else 'dispute_rejected' end;
  v_title := case new.status when 'resolved' then 'Dispute resolved' else 'Dispute rejected' end;

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  select p, v_event, v_title, coalesce(new.resolution_notes, ''), '/booking/' || new.booking_id
  from unnest(array[v_booking.renter_id, v_booking.owner_id]) as p;

  return new;
end;
$$;

drop trigger if exists restore_booking_status_after_dispute_resolution on public.disputes;
create trigger restore_booking_status_after_dispute_resolution
  after update on public.disputes
  for each row execute function public.restore_booking_status_after_dispute_resolution();

-- ---------------------------------------------------------------------
-- notify_booking_status_change (0009): add copy for the two statuses
-- this migration finally makes reachable. 'disputed' and reversion out
-- of it deliberately stay uncovered here — mark_booking_disputed /
-- restore_booking_status_after_dispute_resolution above send their own,
-- more specific dispute_* notifications instead.
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
  else
    if new.status = old.status then
      return new;
    end if;
    v_event_type := 'booking_' || new.status;
    v_title := case new.status
      when 'confirmed' then 'Booking confirmed'
      when 'rejected' then 'Booking rejected'
      when 'cancelled' then 'Booking cancelled'
      when 'active' then 'Rental started'
      when 'completed' then 'Rental completed'
      else null
    end;
    if v_title is null then
      return new;
    end if;
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

-- ---------------------------------------------------------------------
-- Storage: dispute evidence photos (spec section 26), same private +
-- participant-scoped shape as the condition-reports bucket from
-- 0005_storage_buckets.sql. Admins also get read access — resolving a
-- dispute (Phase 11's moderation UI, or a direct DB action until then)
-- needs to see the evidence, and public.is_admin(auth.uid()) is the same
-- check every other admin-facing policy in this schema uses.
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('dispute-evidence', 'dispute-evidence', false)
on conflict (id) do nothing;

create policy "dispute_evidence_participant_write"
on storage.objects
for all
using (
  bucket_id = 'dispute-evidence'
  and (
    exists (
      select 1 from public.bookings b
      where b.id::text = (storage.foldername(name))[1]
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
    or public.is_admin(auth.uid())
  )
)
with check (
  bucket_id = 'dispute-evidence'
  and exists (
    select 1 from public.bookings b
    where b.id::text = (storage.foldername(name))[1]
      and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
  )
);
