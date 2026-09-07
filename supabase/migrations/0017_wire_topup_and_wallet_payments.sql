-- ХУВААЛЦ — wallet-based booking payments + wire.mn wallet top-ups +
-- self-reported name/register-number for the new registration flow.
--
-- Product decisions this migration encodes (confirmed with the user):
--  1. Booking payments are now wallet-balance-based end to end — a renter
--     pays a confirmed booking out of `wallets.available_balance`
--     (`pay_booking_from_wallet`), not a direct per-booking provider
--     charge. This *replaces* the mock/QPay-style flow in
--     `initiate-payment`/`mock-complete-payment` as the path the client
--     uses for booking checkout; those two functions are left in place
--     (harmless, and still useful for local dev/tests) but the Flutter
--     client is being switched to call `pay_booking_from_wallet` instead.
--  2. The only way real money enters a wallet as *spendable* balance is a
--     wire.mn top-up (`credit_wallet_for_topup`, called by the
--     `wire-topup-webhook` Edge Function after verifying wire.mn's
--     webhook signature — never by the client directly, same
--     zero-client-write-RLS posture as `payments`).
--  3. Registration now collects овог/нэр (surname/given name) +
--     регистрийн дугаар (register number) right after phone/OTP signup,
--     before DAN verification. This data is **self-reported by the user
--     at this step** — it is not yet the citizen's own claim to
--     ownership of that identity in the way ХУР's biometric page-in-
--     browser session establishes it. Storing it therefore needs a
--     private table, NOT `public.profiles`: `profiles_select_all` (0002)
--     is `for select using (true)` — world-readable, by design, for
--     public browse/search cards. A register number is sensitive
--     Mongolian PII (used across banks/government services much like an
--     SSN) and must never be exposed through that policy.

-- ---------------------------------------------------------------------
-- 1. identity_details — private, self-reported legal name + register
--    number. Deliberately separate from `identity_verifications` (0001):
--    that table only ever stores a level/status/opaque session
--    reference for a verification *attempt* and must stay that way (see
--    its header comment). This table is the opposite — it's exactly the
--    two fields ХУР verification is about, but self-reported and never
--    cross-checked field-by-field against ХУР's response payload
--    (`dan-callback` already made the deliberate decision to read only
--    `resultCode` from ХУР and persist nothing else — see its header
--    comment). A future enhancement could diff this table's values
--    against ХУР's response at verification time; that is out of scope
--    here and would be its own reviewed change.
-- ---------------------------------------------------------------------

create table public.identity_details (
  user_id uuid primary key references public.users (id) on delete cascade,
  surname text not null check (char_length(surname) between 1 and 100), -- овог
  given_name text not null check (char_length(given_name) between 1 and 100), -- нэр
  register_number text not null unique check (char_length(register_number) between 7 and 12), -- регистрийн дугаар
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.identity_details is
  'Private, self-reported овог/нэр + регистрийн дугаар collected at '
  'registration, ahead of DAN verification. Never exposed through the '
  'public profiles table/view — select is owner-or-admin only.';

alter table public.identity_details enable row level security;

create policy identity_details_select_own on public.identity_details
  for select using (user_id = auth.uid() or public.is_admin(auth.uid()));

create policy identity_details_insert_own on public.identity_details
  for insert with check (user_id = auth.uid());

create policy identity_details_update_own on public.identity_details
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create trigger identity_details_set_updated_at
  before update on public.identity_details
  for each row execute function public.set_updated_at();

-- RLS policies are only the *second* gate — PostgREST/Postgres still
-- requires the base table-level privilege first, and unlike every other
-- table in this schema this one never got it, so every request failed
-- with `42501 permission denied for table identity_details` before RLS
-- was ever evaluated (confirmed live: the client's own SELECT after
-- login errored this way, resulting in a blank screen since the
-- complete-profile check has no error handling for this case). Match the
-- three owner policies above: select/insert/update, never delete (no
-- policy or product need for a user to delete their own identity_details
-- row).
grant select, insert, update on public.identity_details to authenticated;

-- ---------------------------------------------------------------------
-- 2. wallet_topups — one row per wire.mn top-up attempt. Same
--    zero-client-write posture as `payments` (0001/0002): a top-up only
--    ever becomes 'paid' via `credit_wallet_for_topup`, called by the
--    `wire-topup-webhook` Edge Function (service role) after it has
--    independently verified wire.mn's webhook signature — the client
--    can create a *request* for one (via the authenticated
--    `wire-create-topup` function, which inserts the initial 'pending'
--    row using the service-role key) but can never mark its own top-up
--    paid.
-- ---------------------------------------------------------------------

create table public.wallet_topups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  provider text not null default 'wire',
  provider_reference text unique, -- wire.mn PaymentIntent id — also this row's webhook idempotency key
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'MNT',
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index wallet_topups_user_id_idx on public.wallet_topups (user_id);

alter table public.wallet_topups enable row level security;

create policy wallet_topups_select_own on public.wallet_topups
  for select using (user_id = auth.uid() or public.is_admin(auth.uid()));

-- No insert/update policy: rows are created and transitioned exclusively
-- by `wire-create-topup`/`wire-topup-webhook` via the service-role key,
-- mirroring `payments`' comment in 0002.

create trigger wallet_topups_set_updated_at
  before update on public.wallet_topups
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 3. pay_booking_from_wallet — the renter-facing RPC that replaces a
--    direct provider charge at booking checkout. Debits the renter's own
--    `wallets.available_balance`, writes a `payments` row (provider:
--    'wallet', status: 'paid' — it settles synchronously, there is no
--    external gateway round trip once the money is already sitting in
--    the wallet), and then hands off to the existing, already-proven
--    `credit_wallet_for_payment` (0008/0014) to credit the owner's
--    pending_balance with the exact same commission-split math every
--    other payment path uses. Callable directly by the authenticated
--    renter (`security definer` + grant to `authenticated`) — unlike
--    `payments` inserts, this one never lets the client choose its own
--    amount or provider; both are computed here from the booking row.
-- ---------------------------------------------------------------------

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
  if v_uid is null then
    raise exception 'auth_required';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found';
  end if;
  if v_booking.renter_id != v_uid then
    raise exception 'not_authorized';
  end if;
  if v_booking.status != 'confirmed' then
    raise exception 'booking_not_confirmed';
  end if;

  -- Idempotent: a retry (double tap, client resubmit after a network
  -- blip) reuses the already-paid payment instead of double-charging the
  -- wallet. Mirrors `initiate-payment`'s existing-payment reuse.
  select * into v_existing_payment
    from public.payments
    where booking_id = p_booking_id and status = 'paid'
    order by created_at desc
    limit 1;
  if found then
    return v_existing_payment;
  end if;

  select * into v_wallet from public.wallets where user_id = v_uid for update;
  if not found then
    raise exception 'wallet_not_found';
  end if;
  if v_wallet.available_balance < v_booking.total_amount then
    raise exception 'insufficient_balance';
  end if;

  update public.wallets
    set available_balance = available_balance - v_booking.total_amount,
        updated_at = now()
    where user_id = v_uid;

  insert into public.wallet_transactions (wallet_user_id, booking_id, type, amount, description)
  values (v_uid, p_booking_id, 'booking_payment', -v_booking.total_amount, 'Booking paid from wallet balance');

  insert into public.payments (booking_id, payer_id, provider, provider_reference, amount, currency, status)
  values (p_booking_id, v_uid, 'wallet', 'wallet_' || gen_random_uuid()::text, v_booking.total_amount, 'MNT', 'paid')
  returning * into v_payment;

  insert into public.payment_events (payment_id, event_type, raw_payload)
  values (v_payment.id, 'wallet.debited', jsonb_build_object('renter_id', v_uid, 'amount', v_booking.total_amount));

  -- Credits the owner's pending_balance with the same
  -- rental_amount + delivery_fee (platform_fee withheld) math every
  -- other payment path uses — see 0014's fixed version for the
  -- already-credited guard and row locking.
  perform public.credit_wallet_for_payment(v_payment.id);

  return v_payment;
end;
$$;

revoke all on function public.pay_booking_from_wallet(uuid) from public;
grant execute on function public.pay_booking_from_wallet(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 4. credit_wallet_for_topup — the wire.mn-webhook-only counterpart to
--    `credit_wallet_for_payment`. Unlike booking income (which lands in
--    `pending_balance` until a condition-report release, 0010), a
--    top-up is real money the payer just sent for their *own* wallet —
--    it credits `available_balance` directly and immediately.
--    Idempotent on `wallet_topups.status`: a webhook redelivery for an
--    already-'paid' topup is a silent no-op, same pattern as
--    `credit_wallet_for_payment`'s already-credited guard.
-- ---------------------------------------------------------------------

create or replace function public.credit_wallet_for_topup(p_topup_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topup public.wallet_topups;
begin
  select * into v_topup from public.wallet_topups where id = p_topup_id for update;
  if not found then
    raise exception 'topup_not_found';
  end if;
  if v_topup.status = 'paid' then
    return; -- already credited; nothing to do
  end if;
  if v_topup.status != 'pending' then
    raise exception 'topup_not_pending';
  end if;

  update public.wallets
    set available_balance = available_balance + v_topup.amount,
        updated_at = now()
    where user_id = v_topup.user_id;
  if not found then
    raise exception 'wallet_not_found';
  end if;

  insert into public.wallet_transactions (wallet_user_id, type, amount, description)
  values (v_topup.user_id, 'wallet_topup', v_topup.amount, 'Wallet top-up via wire.mn');

  update public.wallet_topups set status = 'paid', updated_at = now() where id = p_topup_id;
end;
$$;

revoke all on function public.credit_wallet_for_topup(uuid) from public;
grant execute on function public.credit_wallet_for_topup(uuid) to service_role;
