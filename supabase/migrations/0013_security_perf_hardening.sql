-- ХУВААЛЦ — Phase 12 (security / performance / testing / release) backend
-- pieces. This phase is a hardening pass, not a new feature area, so it's
-- deliberately narrow: two concrete, verifiable things found by re-reading
-- the schema with a security/perf lens, not a speculative rewrite.
--
-- 1. Security: `promotions_admin_write` (0002) was the one remaining
--    direct-RLS admin-write path flagged (but explicitly left out of
--    scope) in Phase 11's own README — a write to `public.promotions`
--    through that policy never touched `audit_logs`, unlike every other
--    admin mutation as of `0012_admin_dashboard.sql`. This migration
--    closes it the same way Phase 11 closed `disputes_update_admin`:
--    audited RPCs + dropping the direct-write policy. `promotions` itself
--    has had zero Flutter code touching it since Phase 0 — no consumer-
--    facing "apply a promo code" flow exists yet, so this only closes the
--    admin-authoring side; applying a promotion at booking time remains a
--    real, separate, un-started feature (see README "Known issues").
-- 2. Performance: two gaps found by re-reading every table's indexes
--    against how the app actually queries them —
--    a. `public.payouts` was indexed on `user_id` only; the Phase 11
--       admin payout queue (`getPendingPayouts`) filters on `status`
--       with no supporting index.
--    b. Asset search (`SupabaseAssetRepository.search`) has done a plain
--       `title`-only `ILIKE '%query%'` since Phase 2 — no index can make
--       a leading-wildcard `ILIKE` fast, and it never looked at
--       `description`/`brand`/`model` at all. A generated `tsvector`
--       column + GIN index lets Postgres actually use an index for text
--       search, and searches all four fields instead of just the title.

-- ---------------------------------------------------------------------
-- Promotions: audited admin RPCs, replacing the direct-RLS-write policy
-- ---------------------------------------------------------------------

drop policy if exists promotions_admin_write on public.promotions;
-- `promotions_select_active` (0002) is untouched — reading an active
-- promotion isn't a "sensitive admin action" spec section 30 means by
-- that phrase, only writing one is.

-- One upsert-shaped RPC rather than separate create/update functions:
-- unlike assets/disputes/payouts/reports, a promotion has no meaningful
-- state machine to enforce (no "only from status X" rule) — an admin
-- editing any field of an existing promotion, or creating a new one, is
-- the same validation either way. `p_id null` creates; `p_id` set updates
-- that row (raising `promotion_not_found` if it doesn't exist, rather
-- than silently upserting a caller-chosen id into existence).
create or replace function public.admin_upsert_promotion(
  p_id uuid,
  p_code text,
  p_title text,
  p_description text,
  p_discount_percent numeric,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_is_active boolean
)
returns public.promotions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.promotions;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_title is null or length(trim(p_title)) = 0 then
    raise exception 'title_required';
  end if;
  if p_discount_percent is not null and (p_discount_percent < 0 or p_discount_percent > 100) then
    raise exception 'invalid_discount_percent';
  end if;
  if p_ends_at <= p_starts_at then
    raise exception 'invalid_date_range';
  end if;

  if p_id is null then
    insert into public.promotions (
      code, title, description, discount_percent, starts_at, ends_at, is_active
    )
    values (p_code, p_title, p_description, p_discount_percent, p_starts_at, p_ends_at, p_is_active)
    returning * into v_row;
    perform public.log_admin_action('promotion.create', 'promotion', v_row.id, '{}'::jsonb);
  else
    update public.promotions
    set code = p_code,
        title = p_title,
        description = p_description,
        discount_percent = p_discount_percent,
        starts_at = p_starts_at,
        ends_at = p_ends_at,
        is_active = p_is_active
    where id = p_id
    returning * into v_row;
    if not found then
      raise exception 'promotion_not_found';
    end if;
    perform public.log_admin_action('promotion.update', 'promotion', v_row.id, '{}'::jsonb);
  end if;

  return v_row;
end;
$$;

revoke all on function public.admin_upsert_promotion(
  uuid, text, text, text, numeric, timestamptz, timestamptz, boolean
) from public;
grant execute on function public.admin_upsert_promotion(
  uuid, text, text, text, numeric, timestamptz, timestamptz, boolean
) to authenticated;

-- A dedicated action (rather than routing every deactivation through
-- `admin_upsert_promotion` with every other field re-sent) for the same
-- reason `admin_suspend_asset` is its own RPC next to `admin_reject_asset`
-- — one clear, specifically-logged action for the single most common
-- promotion-management action, not just "some fields changed".
create or replace function public.admin_deactivate_promotion(p_id uuid)
returns public.promotions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.promotions;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;

  update public.promotions
  set is_active = false
  where id = p_id
  returning * into v_row;

  if not found then
    raise exception 'promotion_not_found';
  end if;

  perform public.log_admin_action('promotion.deactivate', 'promotion', v_row.id, '{}'::jsonb);
  return v_row;
end;
$$;

revoke all on function public.admin_deactivate_promotion(uuid) from public;
grant execute on function public.admin_deactivate_promotion(uuid) to authenticated;

-- Admins also need to see inactive/expired promotions (the public
-- `promotions_select_active` policy already gives them that per its own
-- `or public.is_admin(auth.uid())` clause — no new policy needed here).

-- ---------------------------------------------------------------------
-- Performance: missing index on payouts.status
-- ---------------------------------------------------------------------

create index if not exists payouts_status_idx on public.payouts (status);

-- ---------------------------------------------------------------------
-- Performance: full-text search for assets
-- ---------------------------------------------------------------------
--
-- `to_tsvector('simple', ...)` — deliberately the 'simple' text search
-- configuration, not 'english' or a Mongolian-specific one: Postgres
-- ships no Mongolian dictionary, and 'english' stemming rules are simply
-- wrong for Mongolian/Cyrillic text. 'simple' still tokenizes and
-- lowercases (a real improvement over `ILIKE`'s leading-wildcard scan —
-- this can actually use the GIN index below), it just does no linguistic
-- stemming for either language. Genuine language-aware Mongolian search
-- would need a custom dictionary/configuration this schema doesn't have
-- and isn't pretending to.
alter table public.assets
  add column if not exists search_vector tsvector
  generated always as (
    to_tsvector(
      'simple',
      coalesce(title, '') || ' ' ||
      coalesce(description, '') || ' ' ||
      coalesce(brand, '') || ' ' ||
      coalesce(model, '')
    )
  ) stored;

create index if not exists assets_search_vector_idx on public.assets using gin (search_vector);

-- `asset_cards` (0004, re-declared by 0012) re-declared again, identical
-- except for one new trailing column — same "why re-declare the whole
-- view for one column" tradeoff every earlier phase touching this view
-- already made, kept for the same reason: `create or replace view` needs
-- the full column list, and PostgREST/Supabase views can't be `alter`ed
-- like a table.
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
  ) as asset_review_count,
  a.moderation_note,
  a.search_vector
from public.assets a
join public.profiles p on p.user_id = a.owner_id;

comment on view public.asset_cards is
  'Read-optimized projection for browse/search cards, the admin '
  'moderation queue (Phase 11), and now (Phase 12) full-text search via '
  'search_vector. Not writable — write through public.assets directly.';
