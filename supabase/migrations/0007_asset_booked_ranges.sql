-- ХУВААЛЦ — asset_booked_ranges: which date ranges are already spoken for
-- on a published asset, with none of the participant/amount detail that
-- makes `public.bookings` private (spec section 32).
--
-- Why this can't just be `booking_cards` with security_invoker: the
-- booking request screen needs to show a renter which dates are blocked
-- *before* they've booked anything — including dates blocked by other
-- renters' bookings they have no right to read individually
-- (`bookings_select_participant` only lets someone read bookings they're
-- a party to). A security_invoker view would inherit that same
-- restriction and come back empty for everyone else's bookings, which is
-- exactly the data this view needs to expose (just the date range, never
-- who or how much).
--
-- So this is deliberately a *plain* view (no `security_invoker`) — it
-- runs with its owner's privileges, the same way `create_booking` and the
-- other RPCs in 0006 do, and it curates down to only `asset_id` +
-- `start_date`/`end_date` from bookings that are still active-ish, unioned
-- with owner-declared blackout ranges from `asset_availability`. The
-- `published`-only filter is enforced inside the view itself (not by
-- RLS, since this view doesn't participate in the underlying tables'
-- RLS) so it can't be used to probe scheduling data for draft/unpublished
-- listings.
create or replace view public.asset_booked_ranges as
select b.asset_id, b.start_date, b.end_date
from public.bookings b
join public.assets a on a.id = b.asset_id and a.status = 'published'
where b.status in ('pending', 'confirmed', 'active')
union all
select av.asset_id, av.start_date, av.end_date
from public.asset_availability av
join public.assets a on a.id = av.asset_id and a.status = 'published'
where av.is_blocked = true;

comment on view public.asset_booked_ranges is
  'Which date ranges are unavailable on a published asset (from active '
  'bookings + owner blackout ranges), with no participant or amount '
  'detail. Intentionally not security_invoker — see this file''s header '
  'comment for why. Read-only; nothing writes through this view.';

revoke all on public.asset_booked_ranges from public, anon;
grant select on public.asset_booked_ranges to authenticated;
