-- ХУВААЛЦ — security/consistency hardening pass (full-codebase review,
-- Aug 2026). Every change below fixes a concrete, independently-verified
-- defect found by re-reading every RLS policy and money-moving RPC
-- against its actual callers — same spirit as 0014_bug_fixes.sql, just a
-- second pass now that the wallet/wire.mn top-up feature (0017) exists
-- too. Grouped by defect, each with the same reasoning the original
-- schema/RLS comments use elsewhere in this project.

-- ---------------------------------------------------------------------
-- 1. profiles_update_own / users_update_own had no column restriction,
--    so any authenticated user could PATCH their own row's
--    verification_level/rating/review_count/completed_rentals_count/
--    assets_count directly via PostgREST — columns that are meant to be
--    written exclusively by security-definer triggers/functions
--    (update_profile_rating_on_review, dan-callback, etc). This is the
--    same class of bug 0014 already fixed twice (assets.is_featured,
--    conversation_members.is_blocked) via a column-level GRANT — RLS
--    alone can't express "this column, not that one". The Flutter client
--    only ever writes profiles.display_name (see
--    SupabaseProfileRepository.updateDisplayName) and never writes to
--    public.users at all, so neither restriction changes any real
--    behavior — it only closes a direct-API bypass.
-- ---------------------------------------------------------------------

revoke update on public.profiles from authenticated;
grant update (display_name, avatar_url, bio) on public.profiles to authenticated;

revoke update on public.users from authenticated;
-- No columns re-granted: phone/email are the Supabase Auth identity
-- (never client-editable independently of it) and is_active/deleted_at
-- are moderation-only fields with no legitimate client writer today.

-- ---------------------------------------------------------------------
-- 2. identity_verifications_insert_own had no restriction on `status`,
--    so a client could insert a row with status='verified' directly,
--    bypassing DAN entirely. Impact was bounded (profiles.verification_
--    level is only ever set by the dan-callback Edge Function using the
--    service-role key, so this couldn't produce a durable fake verified
--    badge) but it defeats the point of this table being a tamper-
--    resistant audit trail. dan-verify (the only real inserter) always
--    inserts status='pending' already — this changes nothing for it.
-- ---------------------------------------------------------------------

drop policy if exists identity_verifications_insert_own on public.identity_verifications;

create policy identity_verifications_insert_own on public.identity_verifications
  for insert with check (user_id = auth.uid() and status = 'pending');

-- ---------------------------------------------------------------------
-- 3. messages.body had no length limit anywhere in the stack (DB,
--    repository, or UI) — a participant could insert arbitrarily large
--    message bodies repeatedly via direct API access (RLS only checks
--    membership, not size), an unbounded storage-growth/abuse vector.
--    2000 chars comfortably covers any real chat message.
-- ---------------------------------------------------------------------

alter table public.messages
  add constraint messages_body_length check (body is null or char_length(body) <= 2000);

-- ---------------------------------------------------------------------
-- 4. condition-reports storage bucket policy was participant-only,
--    unlike the near-identical dispute-evidence bucket (0010) which
--    also grants admins read access. An admin resolving a dispute may
--    need to see the original pickup/return photos, not just evidence
--    attached to the dispute itself.
-- ---------------------------------------------------------------------

drop policy if exists "condition_reports_participant_write" on storage.objects;

create policy "condition_reports_participant_write"
on storage.objects
for all
using (
  bucket_id = 'condition-reports'
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
  bucket_id = 'condition-reports'
  and exists (
    select 1 from public.bookings b
    where b.id::text = (storage.foldername(name))[1]
      and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
  )
);

-- ---------------------------------------------------------------------
-- 5. asset_images had no server-side cap — kMaxAssetPhotos
--    (asset_create_controller.dart, = 8) is a client-only limit, so a
--    direct API caller could insert unlimited rows/uploads for one
--    asset. Mirror the client's own cap server-side.
-- ---------------------------------------------------------------------

create or replace function public.enforce_asset_image_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  select count(*) into v_count from public.asset_images where asset_id = new.asset_id;
  if v_count >= 8 then
    raise exception 'asset_image_limit_reached';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_asset_image_limit_trigger on public.asset_images;
create trigger enforce_asset_image_limit_trigger
  before insert on public.asset_images
  for each row execute function public.enforce_asset_image_limit();

-- ---------------------------------------------------------------------
-- 6. assets.view_count / favorite_count were declared in 0001 and read
--    by asset_cards (driving Home's "Popular"/"Trending" sort options)
--    but nothing anywhere — client or SQL — ever incremented either one,
--    so both sat at 0 forever and those two Home sections silently
--    sorted by nothing. favorite_count is now kept in sync by a trigger
--    on the table that already records favorites (no client change
--    needed — SupabaseFavoritesRepository already inserts/deletes rows
--    there for the existing favorite/unfavorite feature). view_count
--    gets a dedicated RPC the asset detail screen can call on open;
--    security-definer + no ownership check by design (any visitor
--    viewing a published asset should count as a view), rate-limited
--    only by being a single cheap increment with no side effects worth
--    abusing.
-- ---------------------------------------------------------------------

create or replace function public.bump_asset_favorite_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.assets set favorite_count = favorite_count + 1 where id = new.asset_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.assets set favorite_count = greatest(favorite_count - 1, 0) where id = old.asset_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists bump_asset_favorite_count_trigger on public.favorites;
create trigger bump_asset_favorite_count_trigger
  after insert or delete on public.favorites
  for each row execute function public.bump_asset_favorite_count();

create or replace function public.increment_asset_view_count(p_asset_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.assets set view_count = view_count + 1 where id = p_asset_id and status = 'published';
$$;

revoke all on function public.increment_asset_view_count(uuid) from public;
grant execute on function public.increment_asset_view_count(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------
-- 7. Cross-wallet deadlock risk: pay_booking_from_wallet locks the
--    renter's wallet then (via credit_wallet_for_payment) updates the
--    owner's wallet; the new admin_refund_booking_payment below needs to
--    touch the same pair in the opposite order (owner then renter). On a
--    P2P marketplace it's entirely plausible for two users to be renter
--    and owner of each other's bookings, so two concurrent transactions
--    on the two bookings between the same pair could acquire the two
--    wallet row locks in opposite orders — a classic AB-BA deadlock.
--    Postgres would abort one transaction cleanly (no money-conservation
--    bug), but with no graceful UX today (see the retry-hint added in
--    SupabasePaymentRepository._mapWalletRpcError for '40P01'). Fix at
--    the root: every function that will touch two different users'
--    wallets in the same transaction locks both up front, always in the
--    same (ascending user_id) order, via this shared helper — so no
--    caller can ever acquire them in a conflicting order again.
-- ---------------------------------------------------------------------

create or replace function public.lock_wallet_pair(p_user_a uuid, p_user_b uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_a = p_user_b then
    perform 1 from public.wallets where user_id = p_user_a for update;
  elsif p_user_a < p_user_b then
    perform 1 from public.wallets where user_id = p_user_a for update;
    perform 1 from public.wallets where user_id = p_user_b for update;
  else
    perform 1 from public.wallets where user_id = p_user_b for update;
    perform 1 from public.wallets where user_id = p_user_a for update;
  end if;
end;
$$;

create or replace function public.pay_booking_from_wallet(p_booking_id uuid)
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
  v_wallet public.wallets;
  v_existing_payment public.payments;
  v_payment public.payments;
begin
  if v_uid is null then raise exception 'auth_required'; end if;
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found'; end if;
  if v_booking.renter_id != v_uid then raise exception 'not_authorized'; end if;
  if v_booking.status != 'confirmed' then raise exception 'booking_not_confirmed'; end if;
  select * into v_existing_payment from public.payments
    where booking_id = p_booking_id and status = 'paid'
    order by created_at desc limit 1;
  if found then return v_existing_payment; end if;

  -- Lock both wallets up front, in canonical order — see this
  -- migration's header comment on lock_wallet_pair.
  perform public.lock_wallet_pair(v_booking.renter_id, v_booking.owner_id);

  select * into v_wallet from public.wallets where user_id = v_uid;
  if not found then raise exception 'wallet_not_found'; end if;
  if v_wallet.available_balance < v_booking.total_amount then
    raise exception 'insufficient_balance';
  end if;

  update public.wallets set available_balance = available_balance - v_booking.total_amount,
    updated_at = now() where user_id = v_uid;

  insert into public.wallet_transactions (wallet_user_id, booking_id, type, amount, description)
  values (v_uid, p_booking_id, 'booking_payment', -v_booking.total_amount, 'Booking paid from wallet balance');

  insert into public.payments (booking_id, payer_id, provider, provider_reference, amount, currency, status)
  values (p_booking_id, v_uid, 'wallet', 'wallet_' || gen_random_uuid()::text, v_booking.total_amount, 'MNT', 'paid')
  returning * into v_payment;

  insert into public.payment_events (payment_id, event_type, raw_payload)
  values (v_payment.id, 'wallet.debited', jsonb_build_object('renter_id', v_uid, 'amount', v_booking.total_amount));

  perform public.credit_wallet_for_payment(v_payment.id);
  return v_payment;
end;
$$;

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

  -- Lock both wallets up front, in canonical order — safe to call even
  -- when pay_booking_from_wallet already holds both locks in this same
  -- transaction (re-acquiring a lock your own transaction already holds
  -- is a no-op), and necessary for correctness when this function is
  -- ever called on its own (it's still callable directly by
  -- service-role backend code as a standalone RPC).
  perform public.lock_wallet_pair(v_booking.renter_id, v_booking.owner_id);

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
-- 8. No path anywhere could ever move money back to a renter once
--    admin_resolve_dispute restores a booking's status — the trigger it
--    fires only touches bookings.status, never wallets. A paid,
--    confirmed booking that turns into a legitimate renter-favor dispute
--    (owner never showed up, item broken, etc.) had no way to ever be
--    refunded; the renter's money and the owner's pending credit both
--    just stayed put permanently. This adds the missing reversal: an
--    explicit admin action (not automatic on every dispute resolution —
--    plenty of disputes resolve in the owner's favor) that claws back
--    the owner's share and returns the renter's full payment, mirroring
--    credit_wallet_for_payment's math and reusing the same 'refund'
--    wallet_transaction_type / 'refunded' payment_status the schema
--    already declared for exactly this in 0001. If the owner has
--    already withdrawn the money via a payout (their balance can't cover
--    the reversal), this raises rather than going negative — that case
--    needs real manual admin intervention (money has already left the
--    platform) and is deliberately not silently papered over.
-- ---------------------------------------------------------------------

create or replace function public.admin_refund_booking_payment(p_booking_id uuid, p_reason text default null)
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings;
  v_payment public.payments;
  v_owner_share numeric(12, 2);
  v_owner_wallet public.wallets;
  v_refund_from_pending numeric(12, 2);
  v_refund_from_available numeric(12, 2);
  v_already_refunded boolean;
begin
  if not public.is_admin(v_uid) then
    raise exception 'not_authorized';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found'; end if;

  select * into v_payment from public.payments
    where booking_id = p_booking_id and status = 'paid'
    order by created_at desc limit 1
    for update;
  if not found then raise exception 'no_paid_payment'; end if;

  select exists(
    select 1 from public.wallet_transactions
    where booking_id = p_booking_id and type = 'refund'
  ) into v_already_refunded;
  if v_already_refunded then
    raise exception 'already_refunded';
  end if;

  perform public.lock_wallet_pair(v_booking.renter_id, v_booking.owner_id);

  v_owner_share := v_booking.rental_amount + v_booking.delivery_fee;

  select * into v_owner_wallet from public.wallets where user_id = v_booking.owner_id;
  if not found then raise exception 'owner_wallet_not_found'; end if;

  -- Claw back from pending_balance first, then available_balance if the
  -- earnings were already released (booking completed before the
  -- dispute was resolved) — never let either go negative.
  v_refund_from_pending := least(v_owner_wallet.pending_balance, v_owner_share);
  v_refund_from_available := v_owner_share - v_refund_from_pending;

  if v_owner_wallet.available_balance < v_refund_from_available then
    raise exception 'owner_balance_insufficient_for_reversal';
  end if;

  update public.wallets
    set pending_balance = pending_balance - v_refund_from_pending,
        available_balance = available_balance - v_refund_from_available,
        total_earned = greatest(total_earned - v_owner_share, 0),
        updated_at = now()
    where user_id = v_booking.owner_id;

  insert into public.wallet_transactions (wallet_user_id, booking_id, type, amount, description)
  values (
    v_booking.owner_id, p_booking_id, 'refund', -v_owner_share,
    coalesce('Refund reversal (admin, dispute): ' || p_reason, 'Refund reversal (admin dispute resolution)')
  );

  update public.wallets
    set available_balance = available_balance + v_payment.amount,
        updated_at = now()
    where user_id = v_booking.renter_id;
  if not found then raise exception 'renter_wallet_not_found'; end if;

  insert into public.wallet_transactions (wallet_user_id, booking_id, type, amount, description)
  values (
    v_booking.renter_id, p_booking_id, 'refund', v_payment.amount,
    coalesce('Refund (admin, dispute): ' || p_reason, 'Refund (admin dispute resolution)')
  );

  update public.payments set status = 'refunded' where id = v_payment.id returning * into v_payment;

  insert into public.payment_events (payment_id, event_type, raw_payload)
  values (v_payment.id, 'admin.refunded', jsonb_build_object('admin_id', v_uid, 'reason', p_reason));

  perform public.log_admin_action(
    'booking.refund', 'booking', p_booking_id,
    jsonb_build_object('payment_id', v_payment.id, 'amount', v_payment.amount, 'reason', p_reason)
  );

  return v_payment;
end;
$$;

revoke all on function public.admin_refund_booking_payment(uuid, text) from public;
grant execute on function public.admin_refund_booking_payment(uuid, text) to authenticated;
