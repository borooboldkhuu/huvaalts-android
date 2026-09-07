-- ХУВААЛЦ — booking creation + status-transition RPCs (Phase 4, spec
-- sections 17, 18, 34).
--
-- Why this migration exists: 0002_rls_policies.sql shipped with a
-- deliberately-flagged stopgap — `bookings_insert_renter` let an
-- authenticated renter insert a `bookings` row directly, with only the
-- CHECK/exclusion constraints from 0001 as a backstop, and
-- `bookings_update_participant` let either participant UPDATE *any*
-- column on a booking they're part of (status, amounts, dates — nothing
-- stopped a renter PATCHing their own booking to `status = 'confirmed'`
-- or rewriting `total_amount` via a raw PostgREST request). Both policies'
-- own comments said "created via a backend RPC ... in production" — this
-- migration is that RPC layer, so the two policies below are dropped and
-- replaced with SECURITY DEFINER functions that are the *only* way to
-- create or transition a booking from the client. Reads are untouched
-- (`bookings_select_participant` stays).

drop policy if exists bookings_insert_renter on public.bookings;
drop policy if exists bookings_update_participant on public.bookings;

-- ---------------------------------------------------------------------
-- create_booking — authoritative price calculation + availability check.
-- ---------------------------------------------------------------------
--
-- Deliberately narrow for this phase: daily pricing only (an asset
-- without `price_per_day` can't be booked through this function yet —
-- hourly/weekly booking math is a follow-up once there's a UI for picking
-- something other than a date range). Delivery fee is always 0 — the
-- schema has no per-asset delivery pricing yet, only the
-- `delivery_available` boolean, so there's nothing authoritative to
-- charge for it. Commission is a hardcoded 10% matching
-- `AppConstants.defaultCommissionPercent` client-side — TODO(Phase 11):
-- source this from an admin-configurable settings table once one exists,
-- per spec section 20 ("Default platform commission — overridable by
-- Admin").
create or replace function public.create_booking(
  p_asset_id uuid,
  p_start_date date,
  p_end_date date
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_renter_id uuid := auth.uid();
  v_asset public.assets%rowtype;
  v_nights int;
  v_commission numeric(5, 2) := 10;
  v_rental_amount numeric(12, 2);
  v_platform_fee numeric(12, 2);
  v_deposit numeric(12, 2);
  v_total numeric(12, 2);
  v_booking public.bookings;
begin
  if v_renter_id is null then
    raise exception 'auth_required';
  end if;

  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'invalid_date_range';
  end if;

  if p_start_date < current_date then
    raise exception 'invalid_date_range';
  end if;

  -- Lock the asset row for the duration of this transaction so a
  -- concurrent price edit by the owner can't race a booking computed
  -- against the pre-edit price.
  select * into v_asset from public.assets where id = p_asset_id and status = 'published' for update;
  if not found then
    raise exception 'asset_not_found';
  end if;

  if v_asset.owner_id = v_renter_id then
    raise exception 'cannot_book_own_asset';
  end if;

  if v_asset.price_per_day is null then
    raise exception 'asset_missing_daily_price';
  end if;

  -- Owner-declared blackout ranges. The exclusion constraint on
  -- `bookings` (see 0001) independently guards against overlapping
  -- *bookings*; this guards against dates the owner blocked out that
  -- never had a booking on them at all.
  if exists (
    select 1
    from public.asset_availability av
    where av.asset_id = p_asset_id
      and av.is_blocked = true
      and daterange(av.start_date, av.end_date, '[]') && daterange(p_start_date, p_end_date, '[]')
  ) then
    raise exception 'dates_unavailable';
  end if;

  -- Nights are priced exclusive of the end date (checkout day), matching
  -- how the date-range picker presents start/end to the renter. Note this
  -- is intentionally *not* the same inclusive-both-ends semantics the
  -- `bookings_no_overlap` exclusion constraint uses for blocking (0001) —
  -- that's a stricter same-day-turnover-proof guard, this is pricing.
  v_nights := greatest(p_end_date - p_start_date, 1);
  v_rental_amount := round(v_asset.price_per_day * v_nights, 2);
  v_platform_fee := round(v_rental_amount * v_commission / 100, 2);
  v_deposit := coalesce(v_asset.deposit_amount, 0);
  v_total := v_rental_amount + v_platform_fee + v_deposit;

  begin
    insert into public.bookings (
      asset_id, renter_id, owner_id, start_date, end_date, status,
      rental_amount, platform_fee, delivery_fee, deposit_amount, total_amount, commission_percent
    ) values (
      p_asset_id, v_renter_id, v_asset.owner_id, p_start_date, p_end_date, 'pending',
      v_rental_amount, v_platform_fee, 0, v_deposit, v_total, v_commission
    )
    returning * into v_booking;
  exception
    when exclusion_violation then
      raise exception 'dates_unavailable';
  end;

  insert into public.booking_items (booking_id, kind, label, amount)
  values
    (v_booking.id, 'rental', 'rental', v_rental_amount),
    (v_booking.id, 'platform_fee', 'platform_fee', v_platform_fee),
    (v_booking.id, 'deposit', 'deposit', v_deposit);

  return v_booking;
end;
$$;

revoke all on function public.create_booking(uuid, date, date) from public;
grant execute on function public.create_booking(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------------
-- Status-transition RPCs — each re-checks who's calling and what state
-- the booking is currently in server-side, rather than trusting the
-- client to only ever call the "right" one at the "right" time.
-- ---------------------------------------------------------------------

create or replace function public.confirm_booking(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found';
  end if;
  if v_booking.owner_id != v_uid then
    raise exception 'not_authorized';
  end if;
  if v_booking.status != 'pending' then
    raise exception 'invalid_status_transition';
  end if;

  update public.bookings set status = 'confirmed' where id = p_booking_id returning * into v_booking;
  return v_booking;
end;
$$;

revoke all on function public.confirm_booking(uuid) from public;
grant execute on function public.confirm_booking(uuid) to authenticated;

create or replace function public.reject_booking(p_booking_id uuid, p_reason text default null)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found';
  end if;
  if v_booking.owner_id != v_uid then
    raise exception 'not_authorized';
  end if;
  if v_booking.status != 'pending' then
    raise exception 'invalid_status_transition';
  end if;

  update public.bookings
  set status = 'rejected', cancellation_reason = p_reason
  where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end;
$$;

revoke all on function public.reject_booking(uuid, text) from public;
grant execute on function public.reject_booking(uuid, text) to authenticated;

-- Either participant may cancel while the booking hasn't started yet.
-- Cancelling an 'active' (already picked up) booking is a dispute-shaped
-- problem, not a plain cancellation — that's spec section 26 territory
-- (Phase 9), not this function.
create or replace function public.cancel_booking(p_booking_id uuid, p_reason text default null)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
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

  update public.bookings
  set status = 'cancelled', cancellation_reason = p_reason
  where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end;
$$;

revoke all on function public.cancel_booking(uuid, text) from public;
grant execute on function public.cancel_booking(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- booking_cards — read-optimized projection for list screens (spec
-- section 15's booking lists, both as renter and as owner), the same
-- pattern as `asset_cards` from 0004: one query instead of N+1 lookups
-- per booking for the asset's title/photo and the counterparty's name.
--
-- `security_invoker = true` means this view enforces RLS using the
-- *querying* user's permissions on the underlying tables, not the view
-- creator's — matching `asset_cards`. Left joins (not inner joins) are
-- deliberate: if an asset is later archived/unpublished, or somehow a
-- profile row is missing, the booking row should still come back with
-- null asset/counterparty fields rather than silently disappearing from
-- someone's booking list just because a join target became invisible or
-- absent.
create or replace view public.booking_cards
with (security_invoker = true) as
select
  b.id,
  b.asset_id,
  b.renter_id,
  b.owner_id,
  b.start_date,
  b.end_date,
  b.status,
  b.rental_amount,
  b.platform_fee,
  b.delivery_fee,
  b.deposit_amount,
  b.total_amount,
  b.commission_percent,
  b.cancellation_reason,
  b.created_at,
  a.title as asset_title,
  (
    select ai.storage_path
    from public.asset_images ai
    where ai.asset_id = a.id
    order by ai.sort_order asc
    limit 1
  ) as asset_image_path,
  renter_p.display_name as renter_display_name,
  owner_p.display_name as owner_display_name
from public.bookings b
left join public.assets a on a.id = b.asset_id
left join public.profiles renter_p on renter_p.user_id = b.renter_id
left join public.profiles owner_p on owner_p.user_id = b.owner_id;
