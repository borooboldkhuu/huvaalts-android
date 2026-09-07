-- ХУВААЛЦ — wallet crediting + payout request guard (Phase 7).
--
-- Two pieces, both backend-only mutations of money-relevant state (spec
-- section 34: never trust the client for wallet balance):
--
-- 1. `credit_wallet_for_payment(p_payment_id)` — credits the booking's
--    owner once a payment actually clears. Called by
--    `mock-complete-payment` (service-role only) right after it flips a
--    payment to `paid`, never by the client directly — there is
--    deliberately no grant to `authenticated` here, only `service_role`,
--    the same posture as the booking RPCs being `authenticated`-only but
--    inverted: this one is *more* locked down because nothing about "how
--    much money did this booking generate" should ever be client-driven.
--
--    Credits `pending_balance` (not `available_balance`) with the
--    owner's net share (`rental_amount + delivery_fee` — the renter's
--    `platform_fee` is the marketplace's cut, and `deposit_amount` isn't
--    the owner's money to spend, it's collateral that should go back to
--    the renter absent damage). Moving funds from `pending_balance` to
--    `available_balance` is intentionally NOT done here: that's supposed
--    to happen once a booking is confirmed *returned* — a condition
--    report / return flow that doesn't exist until Phase 9. Until then,
--    a completed rental's payout sits in `pending_balance` forever,
--    which is honest about what this phase actually implements rather
--    than pretending funds are spendable before there's any mechanism
--    that would actually release them.
--
--    Idempotent: guards against being invoked twice for the same
--    payment (defense in depth — the Edge Function's own
--    `payments.status <> 'pending'` check already prevents this under
--    normal operation, but a function this security-sensitive shouldn't
--    rely on a single caller behaving correctly).
--
-- 2. `validate_payout_request()` trigger on `public.payouts` — the table
--    already has a client insert policy (`payouts_insert_own`, from
--    `0002_rls_policies.sql`) since *requesting* a payout doesn't move
--    any money by itself. But nothing stopped a client from requesting a
--    payout for more than they actually have. This trigger rejects an
--    insert whose amount exceeds `available_balance` minus whatever the
--    same user already has sitting in `pending`/`processing` payout
--    requests, so someone can't double-claim the same balance across two
--    concurrent requests. Actually deducting `available_balance` when a
--    payout is approved/paid is a Phase 11 admin action, not implemented
--    here.

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

  select exists(
    select 1 from public.wallet_transactions
    where booking_id = v_payment.booking_id and type = 'booking_income'
  ) into v_already_credited;
  if v_already_credited then
    return; -- already credited for this booking; nothing to do
  end if;

  select * into v_booking from public.bookings where id = v_payment.booking_id;
  if v_booking is null then
    raise exception 'booking_not_found';
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

revoke all on function public.credit_wallet_for_payment(uuid) from public;
grant execute on function public.credit_wallet_for_payment(uuid) to service_role;

create or replace function public.validate_payout_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available numeric(12, 2);
  v_already_requested numeric(12, 2);
begin
  select available_balance into v_available
    from public.wallets
    where user_id = new.user_id
    for update;

  if v_available is null then
    raise exception 'wallet_not_found';
  end if;

  select coalesce(sum(amount), 0) into v_already_requested
    from public.payouts
    where user_id = new.user_id and status in ('pending', 'processing');

  if new.amount > (v_available - v_already_requested) then
    raise exception 'insufficient_available_balance';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_payout_request on public.payouts;
create trigger validate_payout_request
  before insert on public.payouts
  for each row execute function public.validate_payout_request();
