-- ХУВААЛЦ — asset_cards: a read-optimized view for browse/search surfaces
-- (Home sections, Search results — spec sections 11/12). Joins assets to
-- their owner's public profile and primary image so the client can render
-- a card in one query instead of N+1 requests.
--
-- `security_invoker = true` (Postgres 15+, supported by Supabase) makes
-- this view enforce RLS as the *querying* user, not the view owner — so it
-- inherits exactly the same "published, or your own" visibility as
-- `public.assets` (spec section 32). It does not bypass RLS; it's a
-- convenience projection over already-RLS-protected tables.

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
  -- Single comparable price for sort/filter (cheapest, most expensive,
  -- "under 50,000₮"): prefer per-day, then per-hour, then per-week, since
  -- per-day is the most common rental unit in this catalog. Card UI still
  -- reads the three raw price_per_* columns to show the actual unit.
  coalesce(a.price_per_day, a.price_per_hour, a.price_per_week) as display_price,
  a.deposit_amount,
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
  ) as asset_review_count
from public.assets a
join public.profiles p on p.user_id = a.owner_id;

comment on view public.asset_cards is
  'Read-optimized projection for browse/search cards. Not writable — write '
  'through public.assets directly. Respects RLS of the querying user via '
  'security_invoker.';
