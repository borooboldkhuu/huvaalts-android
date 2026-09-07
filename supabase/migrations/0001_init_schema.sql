-- ХУВААЛЦ — initial schema
-- Conventions: UUID PKs (default gen_random_uuid()), created_at/updated_at
-- timestamptz on every table, FKs with explicit ON DELETE behavior, and
-- CHECK/ENUM constraints for state machines the client must never be
-- trusted to enforce alone (spec sections 17, 19, 20, 26, 31, 34).

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------

create type verification_level as enum ('phone', 'dan', 'identity', 'business');
create type booking_status as enum (
  'pending', 'confirmed', 'rejected', 'cancelled',
  'active', 'completed', 'disputed'
);
create type payment_status as enum (
  'pending', 'authorized', 'paid', 'failed',
  'cancelled', 'refunded', 'partially_refunded'
);
create type wallet_transaction_type as enum (
  'booking_income', 'platform_fee', 'refund', 'payout',
  'deposit_release', 'adjustment'
);
create type payout_status as enum ('pending', 'processing', 'paid', 'failed');
create type dispute_status as enum ('open', 'under_review', 'resolved', 'rejected', 'escalated');
create type report_status as enum ('open', 'reviewed', 'actioned', 'dismissed');
create type asset_status as enum ('draft', 'pending_review', 'published', 'suspended', 'archived');
create type condition_report_stage as enum ('pickup', 'return');

-- ---------------------------------------------------------------------
-- Users / profiles / verification
-- ---------------------------------------------------------------------

-- Mirrors auth.users for convenient FKs + app-specific account flags.
-- Kept in sync by the `handle_new_auth_user` trigger below.
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text unique,
  email text unique,
  is_active boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Public-facing profile — what other users see (spec section 28, 33).
create table public.profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  bio text,
  verification_level int not null default 0 check (verification_level between 0 and 3),
  rating numeric(3, 2) not null default 0 check (rating between 0 and 5),
  review_count int not null default 0 check (review_count >= 0),
  completed_rentals_count int not null default 0 check (completed_rentals_count >= 0),
  assets_count int not null default 0 check (assets_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One row per verification *attempt* (spec section 9/10). Never stores the
-- raw national ID or DAN payload — only a level, status, and opaque
-- provider session reference for audit purposes.
create table public.identity_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  level verification_level not null,
  provider text not null default 'dan',
  provider_session_id text,
  status text not null default 'pending' check (status in ('pending', 'verified', 'failed', 'cancelled')),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index identity_verifications_user_id_idx on public.identity_verifications (user_id);

-- ---------------------------------------------------------------------
-- Categories / assets
-- ---------------------------------------------------------------------

create table public.categories (
  id text primary key, -- e.g. 'camera', 'drone' — matches AssetCategory.id client-side
  name_mn text not null,
  name_en text not null,
  icon text,
  sort_order int not null default 0,
  is_active boolean not null default true
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users (id) on delete cascade,
  category_id text not null references public.categories (id),
  title text not null,
  description text not null default '',
  brand text,
  model text,
  specifications jsonb not null default '{}'::jsonb,
  condition text,
  price_per_hour numeric(12, 2) check (price_per_hour >= 0),
  price_per_day numeric(12, 2) check (price_per_day >= 0),
  price_per_week numeric(12, 2) check (price_per_week >= 0),
  deposit_amount numeric(12, 2) not null default 0 check (deposit_amount >= 0),
  currency text not null default 'MNT',
  pickup_method text,
  delivery_available boolean not null default false,
  latitude double precision,
  longitude double precision,
  location_label text,
  status asset_status not null default 'draft',
  is_featured boolean not null default false,
  view_count int not null default 0 check (view_count >= 0),
  favorite_count int not null default 0 check (favorite_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assets_has_a_price check (
    price_per_hour is not null or price_per_day is not null or price_per_week is not null
  )
);

create index assets_owner_id_idx on public.assets (owner_id);
create index assets_category_id_idx on public.assets (category_id);
create index assets_status_idx on public.assets (status);
create index assets_location_idx on public.assets (latitude, longitude);

create table public.asset_images (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets (id) on delete cascade,
  storage_path text not null,
  sort_order int not null default 0,
  width int,
  height int,
  created_at timestamptz not null default now()
);

create index asset_images_asset_id_idx on public.asset_images (asset_id);

-- Blackout / available date ranges. Booking availability is authoritative
-- here + re-checked at booking-creation time inside a transaction — never
-- trust a client-side "is available" computation (spec section 17, 34).
create table public.asset_availability (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets (id) on delete cascade,
  start_date date not null,
  end_date date not null,
  is_blocked boolean not null default true, -- true = owner blackout, false = explicit open window
  reason text,
  created_at timestamptz not null default now(),
  constraint asset_availability_valid_range check (end_date >= start_date)
);

create index asset_availability_asset_id_idx on public.asset_availability (asset_id);
create index asset_availability_range_idx on public.asset_availability (asset_id, start_date, end_date);

create table public.asset_rules (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets (id) on delete cascade,
  rule text not null,
  sort_order int not null default 0
);

create index asset_rules_asset_id_idx on public.asset_rules (asset_id);

-- ---------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets (id),
  renter_id uuid not null references public.users (id),
  owner_id uuid not null references public.users (id),
  start_date date not null,
  end_date date not null,
  status booking_status not null default 'pending',
  rental_amount numeric(12, 2) not null check (rental_amount >= 0),
  platform_fee numeric(12, 2) not null check (platform_fee >= 0),
  delivery_fee numeric(12, 2) not null default 0 check (delivery_fee >= 0),
  deposit_amount numeric(12, 2) not null default 0 check (deposit_amount >= 0),
  total_amount numeric(12, 2) not null check (total_amount >= 0),
  commission_percent numeric(5, 2) not null,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_valid_range check (end_date >= start_date),
  constraint bookings_total_matches_sum check (
    total_amount = rental_amount + platform_fee + delivery_fee + deposit_amount
  )
);

create index bookings_asset_id_idx on public.bookings (asset_id);
create index bookings_renter_id_idx on public.bookings (renter_id);
create index bookings_owner_id_idx on public.bookings (owner_id);
create index bookings_status_idx on public.bookings (status);

-- Database-level double-booking prevention: no two *active-ish* bookings
-- for the same asset may overlap in date range (spec section 17: "prevent
-- double booking with database-level validation").
create extension if not exists btree_gist;

alter table public.bookings
  add constraint bookings_no_overlap
  exclude using gist (
    asset_id with =,
    daterange(start_date, end_date, '[]') with &&
  )
  where (status in ('pending', 'confirmed', 'active'));

-- Line-item breakdown backing the booking price summary (spec section 18).
create table public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  kind text not null check (kind in ('rental', 'platform_fee', 'delivery_fee', 'deposit', 'tax', 'adjustment')),
  label text not null,
  amount numeric(12, 2) not null,
  created_at timestamptz not null default now()
);

create index booking_items_booking_id_idx on public.booking_items (booking_id);

-- ---------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  payer_id uuid not null references public.users (id),
  provider text not null default 'mock', -- swappable — see PaymentProvider abstraction client-side
  provider_reference text,
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'MNT',
  status payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index payments_booking_id_idx on public.payments (booking_id);
create index payments_payer_id_idx on public.payments (payer_id);

-- Append-only ledger of provider webhook events. `payments.status` is only
-- ever mutated by the backend after verifying a webhook against this table
-- — the client can never mark a payment "paid" on its own (spec section 19).
create table public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments (id) on delete cascade,
  event_type text not null,
  raw_payload jsonb not null,
  received_at timestamptz not null default now()
);

create index payment_events_payment_id_idx on public.payment_events (payment_id);

-- ---------------------------------------------------------------------
-- Wallet / payouts
-- ---------------------------------------------------------------------

create table public.wallets (
  user_id uuid primary key references public.users (id) on delete cascade,
  available_balance numeric(12, 2) not null default 0,
  pending_balance numeric(12, 2) not null default 0,
  total_earned numeric(12, 2) not null default 0,
  updated_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_user_id uuid not null references public.wallets (user_id) on delete cascade,
  booking_id uuid references public.bookings (id),
  type wallet_transaction_type not null,
  amount numeric(12, 2) not null, -- signed: positive = credit, negative = debit
  description text,
  created_at timestamptz not null default now()
);

create index wallet_transactions_wallet_user_id_idx on public.wallet_transactions (wallet_user_id);

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id),
  amount numeric(12, 2) not null check (amount > 0),
  status payout_status not null default 'pending',
  destination_reference text, -- bank account token / masked reference — never raw bank details here
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);

create index payouts_user_id_idx on public.payouts (user_id);

-- ---------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  reviewer_id uuid not null references public.users (id),
  reviewee_id uuid not null references public.users (id),
  role text not null check (role in ('owner', 'renter')), -- role of the *reviewer* in this booking
  rating int not null check (rating between 1 and 5),
  comment text,
  category_scores jsonb not null default '{}'::jsonb, -- e.g. {"communication": 5, "accuracy": 4}
  created_at timestamptz not null default now(),
  unique (booking_id, reviewer_id) -- prevents duplicate reviews (spec section 27)
);

create index reviews_reviewee_id_idx on public.reviews (reviewee_id);
create index reviews_booking_id_idx on public.reviews (booking_id);

-- ---------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings (id),
  asset_id uuid references public.assets (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  last_read_at timestamptz,
  is_blocked boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index conversation_members_user_id_idx on public.conversation_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid references public.users (id), -- null = system message
  kind text not null default 'text' check (kind in ('text', 'image', 'system', 'booking_reference', 'asset_reference')),
  body text,
  image_path text,
  flagged_for_review boolean not null default false, -- suspicious off-platform payment language (spec section 23)
  created_at timestamptz not null default now()
);

create index messages_conversation_id_idx on public.messages (conversation_id, created_at);

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  event_type text not null, -- e.g. 'new_booking', 'payment_received' — see spec section 24
  title text not null,
  body text not null,
  deep_link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_id_idx on public.notifications (user_id, created_at);

-- ---------------------------------------------------------------------
-- Condition reports / disputes / reports
-- ---------------------------------------------------------------------

create table public.condition_reports (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  stage condition_report_stage not null,
  submitted_by uuid not null references public.users (id),
  photo_paths text[] not null default '{}',
  notes text,
  confirmed_by_renter_at timestamptz,
  confirmed_by_owner_at timestamptz,
  created_at timestamptz not null default now()
);

create index condition_reports_booking_id_idx on public.condition_reports (booking_id);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id),
  raised_by uuid not null references public.users (id),
  category text not null,
  description text not null,
  evidence_paths text[] not null default '{}',
  status dispute_status not null default 'open',
  resolution_notes text,
  -- References the resolving admin's underlying user id (public.admin_users
  -- itself is keyed by user_id — see below) rather than a separate FK
  -- target, so this table doesn't need to be declared after admin_users.
  resolved_by uuid references public.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index disputes_booking_id_idx on public.disputes (booking_id);
create index disputes_status_idx on public.disputes (status);

-- ---------------------------------------------------------------------
-- Favorites / reports / promotions
-- ---------------------------------------------------------------------

create table public.favorites (
  user_id uuid not null references public.users (id) on delete cascade,
  asset_id uuid not null references public.assets (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, asset_id)
);

create index favorites_asset_id_idx on public.favorites (asset_id);

-- Generic abuse/content reports — fraudulent listings, bad behavior, chat
-- abuse (spec sections 26, 30, 34).
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id),
  target_type text not null check (target_type in ('user', 'asset', 'message', 'review')),
  target_id uuid not null,
  reason text not null,
  details text,
  status report_status not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index reports_target_idx on public.reports (target_type, target_id);
create index reports_status_idx on public.reports (status);

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  title text not null,
  description text,
  discount_percent numeric(5, 2) check (discount_percent between 0 and 100),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint promotions_valid_window check (ends_at > starts_at)
);

-- ---------------------------------------------------------------------
-- Admin / audit
-- ---------------------------------------------------------------------

-- Elevated permissions are granted through this table + server-side role
-- checks (Edge Functions / RLS policies), never through a client-settable
-- flag on `public.users` (spec section 32).
create table public.admin_users (
  user_id uuid primary key references public.users (id) on delete cascade,
  role text not null default 'admin' check (role in ('admin', 'support', 'finance', 'super_admin')),
  granted_by uuid references public.users (id),
  created_at timestamptz not null default now()
);

-- Every sensitive admin action must write here (spec section 30).
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users (id),
  action text not null, -- e.g. 'asset.approve', 'user.suspend', 'payment.refund'
  target_type text,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_actor_id_idx on public.audit_logs (actor_id);
create index audit_logs_action_idx on public.audit_logs (action);
create index audit_logs_target_idx on public.audit_logs (target_type, target_id);

-- ---------------------------------------------------------------------
-- Triggers: keep public.users in sync with auth.users, and updated_at
-- columns current on every UPDATE.
-- ---------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, phone, email)
  values (new.id, new.phone, new.email)
  on conflict (id) do update set phone = excluded.phone, email = excluded.email;

  insert into public.profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (user_id) do nothing;

  insert into public.wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'users', 'profiles', 'identity_verifications', 'assets', 'bookings',
    'payments', 'disputes'
  ]
  loop
    execute format(
      'drop trigger if exists set_updated_at on public.%I; '
      'create trigger set_updated_at before update on public.%I '
      'for each row execute function public.set_updated_at();',
      t, t
    );
  end loop;
end;
$$;
