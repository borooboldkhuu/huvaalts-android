-- Removes the deposit/collateral (`барьцаа хөрөнгө`) concept from the
-- product entirely, per a later product decision — Хуваалц no longer asks
-- owners to set a security deposit or renters to pay one. This migration
-- undoes every deposit-related piece introduced in 0001/0006/0012:
--   * `assets.deposit_amount` and `bookings.deposit_amount` columns
--   * the `bookings_total_matches_sum` check (now rental + platform fee +
--     delivery fee only)
--   * `'deposit'` as an allowed `booking_items.kind`
--   * `deposit_amount` in `asset_cards` / `booking_cards`
--   * all deposit computation/insertion inside `create_booking`
--
-- `wallet_transaction_type`'s `'deposit_release'` enum value is
-- deliberately NOT touched here — vanilla Postgres has no
-- `ALTER TYPE ... DROP VALUE`, so removing it would require recreating the
-- whole enum type (and every column/default/index that depends on it).
-- That value was already dead before this migration (nothing ever
-- inserted it — the actual pending -> available wallet release in
-- `advance_booking_on_condition_report`, 0010, uses `'adjustment'`), so
-- it's left in place as inert, harmless schema debris rather than forcing
-- a much riskier type-recreation migration for zero behavioral gain. The
-- Dart-side mirror (`WalletTransactionType`) has already dropped its
-- `depositRelease` case.

-- ---------------------------------------------------------------------
-- asset_cards / booking_cards must be redefined WITHOUT deposit_amount
-- *before* the columns themselves are dropped below — Postgres refuses
-- to drop a column that a view still references (view definitions are
-- tracked in pg_depend; plpgsql function bodies like create_booking's
-- are not, which is why only the views need to move, not the function
-- at the bottom of this file). Re-declared (0004, 0012, 0013) minus
-- deposit_amount — full column list required, see 0013's comment on why
-- this view can't be `alter`ed incrementally.
--
-- `create or replace view` can't do this by itself: Postgres only lets
-- `or replace` add columns or retype existing ones in place, never drop
-- one (`ERROR: cannot drop columns from view`, SQLSTATE 42P16) — since
-- `deposit_amount` disappears from the column list entirely here, the
-- view has to be dropped and recreated from scratch instead. Neither
-- view has any other view/function selecting from it, nor any
-- object-level grant of its own (checked across every migration) — both
-- rely on Supabase's default schema-level `authenticated`/`anon`
-- grants — so a plain drop + recreate loses nothing that needs
-- restoring afterward.
-- ---------------------------------------------------------------------
drop view if exists public.asset_cards;

create or replace view public.asset_cards
with (security_invoker = true)
as
select
  a.id,
  a.owner_id,
  a.category_id,
  a.title,
  a.price_per_hour,
  a.price_per_day,
  a.price_per_week,
  coalesce(a.price_per_day, a.price_per_hour, a.price_per_week) as display_price,
  a.currency,
  a.latitude,
  a.longitude,
  a.location_label,
  a.status,
  a.is_featured,
  a.view_count,
  a.favorite_count,
  a.created_at,
  p.display_name as owner_display_name,
  p.verification_level as owner_verification_level,
  (
    select ai.storage_path
    from public.asset_images ai
    where ai.asset_id = a.id
    order by ai.sort_order asc
    limit 1
  ) as primary_image_path,
  coalesce(
    (
      select avg(r.rating)::numeric(3, 2)
      from public.reviews r
      join public.bookings b on b.id = r.booking_id
      where b.asset_id = a.id
    ),
    0
  ) as asset_rating,
  (
    select count(*)
    from public.reviews r
    join public.bookings b on b.id = r.booking_id
    where b.asset_id = a.id
  ) as asset_review_count,
  a.moderation_note,
  a.search_vector
from public.assets a
join public.profiles p on p.user_id = a.owner_id;

comment on view public.asset_cards is
  'Read-optimized projection for browse/search cards, the admin '
  'moderation queue (Phase 11), and full-text search via search_vector. '
  'No longer carries deposit_amount (0015: deposit removed product-wide). '
  'Not writable — write through public.assets directly.';

-- ---------------------------------------------------------------------
-- booking_cards: re-declared (0006) minus deposit_amount. Same
-- drop-then-recreate reasoning as asset_cards above — `or replace`
-- can't drop deposit_amount from the column list on its own.
-- ---------------------------------------------------------------------
drop view if exists public.booking_cards;

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

-- ---------------------------------------------------------------------
-- Now that asset_cards/booking_cards no longer reference deposit_amount,
-- the underlying columns can actually be dropped.
--
-- bookings: drop the cross-column total check before dropping the column
-- it references, then re-add it without deposit_amount.
-- ---------------------------------------------------------------------
alter table public.bookings drop constraint bookings_total_matches_sum;

alter table public.bookings drop column deposit_amount;

alter table public.bookings
  add constraint bookings_total_matches_sum check (
    total_amount = rental_amount + platform_fee + delivery_fee
  );

-- ---------------------------------------------------------------------
-- assets: deposit_amount's own check (`deposit_amount >= 0`) is inline
-- and single-column, so dropping the column drops it automatically.
-- ---------------------------------------------------------------------
alter table public.assets drop column deposit_amount;

-- ---------------------------------------------------------------------
-- booking_items: 'deposit' is no longer a valid line-item kind.
-- ---------------------------------------------------------------------
alter table public.booking_items drop constraint booking_items_kind_check;

alter table public.booking_items
  add constraint booking_items_kind_check
  check (kind in ('rental', 'platform_fee', 'delivery_fee', 'tax', 'adjustment'));

-- ---------------------------------------------------------------------
-- create_booking: re-declared (0006, 0012) with every deposit
-- computation/insertion removed. Everything else (commission lookup,
-- overlap/availability checks, error codes) is unchanged from 0012.
-- ---------------------------------------------------------------------
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
  v_commission numeric(5, 2);
  v_rental_amount numeric(12, 2);
  v_platform_fee numeric(12, 2);
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

  if exists (
    select 1
    from public.asset_availability av
    where av.asset_id = p_asset_id
      and av.is_blocked = true
      and daterange(av.start_date, av.end_date, '[]') && daterange(p_start_date, p_end_date, '[]')
  ) then
    raise exception 'dates_unavailable';
  end if;

  select coalesce(commission_percent, 10) into v_commission from public.platform_settings where id = 1;
  if v_commission is null then
    v_commission := 10;
  end if;

  v_nights := greatest(p_end_date - p_start_date, 1);
  v_rental_amount := round(v_asset.price_per_day * v_nights, 2);
  v_platform_fee := round(v_rental_amount * v_commission / 100, 2);
  v_total := v_rental_amount + v_platform_fee;

  begin
    insert into public.bookings (
      asset_id, renter_id, owner_id, start_date, end_date, status,
      rental_amount, platform_fee, delivery_fee, total_amount, commission_percent
    ) values (
      p_asset_id, v_renter_id, v_asset.owner_id, p_start_date, p_end_date, 'pending',
      v_rental_amount, v_platform_fee, 0, v_total, v_commission
    )
    returning * into v_booking;
  exception
    when exclusion_violation then
      raise exception 'dates_unavailable';
  end;

  insert into public.booking_items (booking_id, kind, label, amount)
  values
    (v_booking.id, 'rental', 'rental', v_rental_amount),
    (v_booking.id, 'platform_fee', 'platform_fee', v_platform_fee);

  return v_booking;
end;
$$;

revoke all on function public.create_booking(uuid, date, date) from public;
grant execute on function public.create_booking(uuid, date, date) to authenticated;
