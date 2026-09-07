# ХУВААЛЦ

> Ашигладаггүй зүйлээ мөнгө болго.

Mongolia's premium peer-to-peer asset rental marketplace — Flutter +
Riverpod + GoRouter + Supabase. This repository currently contains
**Phase 0 (architecture + design system), Phase 1 (auth + onboarding +
profile), Phase 2 (home + categories + search), Phase 3 (asset create +
full asset detail + "Миний хөрөнгө"), Phase 4 (booking request,
booking detail, confirm/reject/cancel, "Миний захиалгууд"), Phase 5
(mock payment collection on a confirmed booking), Phase 6 (the DAN
production adapter + the "Get verified" flow it powers, plus closing a
payments backend gap), Phase 7 (wallet: crediting an owner on payment,
"Хэтэвч" balance/transaction history, and payout requests), Phase 8
(per-booking chat over Supabase Realtime, plus an in-app notification
center), Phase 9 (pickup/return condition reports that finally move a
booking to `active`/`completed`, releasing Phase 7's wallet credits;
reviews; and a dispute lifecycle), Phase 10 (an honestly-mock AI
listing assistant — prefills structure, not fabricated content, from a
photo), Phase 11 (the admin dashboard: asset moderation, commission
settings, payout processing, dispute resolution, and report resolution —
closing every "waiting on Phase 11" gap earlier phases flagged, plus a
previously-undocumented RLS gap it found along the way), and **Phase 12
(security/performance/testing/release hardening: closes the last
unaudited admin-write path with a new promotions admin feature, adds
real full-text search, fills a missing index, and expands the release
checklist — the last of the spec's 12 phases)** of the 12-phase build
plan; see "Roadmap" below.

## Getting started

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # freezed/json_serializable
flutter analyze
flutter test --dart-define-from-file=env/development.json
flutter run --target lib/main.dart          --dart-define-from-file=env/development.json
flutter run --target lib/main_staging.dart  --dart-define-from-file=env/staging.json
flutter run --target lib/main_production.dart --dart-define-from-file=env/production.json
```

`env/development.json` already has a real (dev-project) Supabase URL/anon
key and Maps key filled in, so `flutter run` against it works out of the
box. `env/staging.json`/`env/production.json` ship with placeholder
values (`APP_ENV`, `SUPABASE_URL`, etc. all say `placeholder-...`) — fill
those in with real values before actually using those flavors.
`AppConfig.assertNotPlaceholderInProduction()` (called from `bootstrap()`)
hard-crashes on launch if a `production`-flavor build still has
placeholder values, specifically so a build like that can't quietly ship.

**Why `--dart-define-from-file` and not a bundled `.env` file (as this
repo used to do):** an external audit (Aug 2026) found that the previous
`flutter_dotenv`-based design listed all three `.env.development`/
`.env.staging`/`.env.production` files as Flutter *assets* in
`pubspec.yaml` unconditionally — meaning every build, including a release
production APK/IPA, shipped with the development and staging config
readable inside it (Flutter assets are plain files in the package,
trivially extracted). `--dart-define-from-file` compiles the one file you
pass in directly into constants; the other two flavors' files are never
read, referenced, or present in that build's output at all. See
`lib/app/config/env.dart`'s header comment for the full reasoning.

## Architecture

Clean architecture, one direction of dependency:

```
Presentation (screens/widgets, Riverpod controllers)
      ↓
Repository interfaces (domain/repositories/*.dart)
      ↓
Repository implementations (data/repositories/*.dart)
      ↓
Data source (Supabase client / Dio → backend)
```

- `lib/app/` — theme tokens, router, env/config, localization.
- `lib/core/` — cross-feature infrastructure: errors → `Failure`, network
  (`Dio` wrapper + interceptors), storage (secure + local cache),
  security (`TokenManager`), constants, utils, Riverpod providers for all
  of the above.
- `lib/features/<name>/{domain,data,presentation}/` — one folder per
  product feature (spec section 4). `auth`, `onboarding`, `profile`,
  `home`, `search`, `assets` (browse, create, full detail, "my assets"),
  and `booking` (request, detail, confirm/reject/cancel, "my bookings",
  and as of Phase 9 the pickup/return condition report flow) are
  implemented, plus `payments` (mock pay-now flow on a confirmed
  booking), `wallet` (balance, transaction history, payout requests),
  `chat` (per-booking messaging), `notifications` (in-app notification
  center), `reviews` (leave/browse reviews), `disputes` (raise a
  dispute, view its status), `ai` (the Phase 10 listing-assistant
  suggestion call, consumed from inside `assets`' create form rather than
  having its own screen), and `admin` (the Phase 11 dashboard: asset
  moderation queue, dispute/payout/report queues, commission settings,
  plus the Phase 12 promotions queue — gated behind `isAdminProvider`, a
  client-side convenience check only; every RPC it calls re-checks
  `is_admin` server-side regardless); `map` now holds Search's Map view
  (see below); the rest (`verification` beyond the Phase 6 "Get verified"
  flow already inside `auth`, `settings` beyond language) exist as empty
  directories or thin slices reserved for their phase.
- `lib/shared/widgets/` — `PrimaryButton`, `SecondaryButton`,
  `AppTextField`, `SkeletonLoader`/`SkeletonCard`, `EmptyState`,
  `ErrorStateView`, `OfflineBanner`, `VerifiedBadge`, `CategoryChipRow`.
- `lib/shared/cards/` — `AssetCardTile`, the browse/search card used on
  Home and Search.
- `supabase/migrations/` — full initial schema + RLS + the
  `asset_cards`/`booking_cards`/`asset_booked_ranges` views + the booking
  RPCs + Storage buckets (see `supabase/README.md`).
- `supabase/functions/dan-verify/` — mock DAN verification backend.
- `supabase/functions/initiate-payment/`, `supabase/functions/mock-complete-payment/`
  — the only write path for `public.payments`/`payment_events` (that table
  has zero client-facing RLS write policies at all — see
  `supabase/README.md`).

## What's implemented (Phase 0 + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12)

- Design tokens: exact light/dark color palette, typography scale,
  spacing/radius/motion tokens, adaptive Material 3 theme
  (`lib/app/theme/`).
- Env/config: `env/development.json`/`staging.json`/`production.json`
  (`--dart-define-from-file`) + `Env`/`AppConfig`,
  three build-flavor entry points (`main.dart`, `main_staging.dart`,
  `main_production.dart`) sharing one `bootstrap()`.
- Routing: `GoRouter` with onboarding → auth → home redirect logic driven
  by Supabase auth state + a local "onboarding complete" flag.
- Core error handling: `AppException` (data layer) → `Failure` (UI layer)
  mapping, so no raw exception ever reaches a widget.
- Onboarding: 3-slide flow with the exact Mongolian copy from the spec,
  skip action, persisted completion flag.
- Auth: phone OTP send/verify against Supabase Auth, Google/Apple
  sign-in entry points (native SDK wiring left as a clearly marked TODO —
  requires platform project configuration, see "Known issues"), a fully
  isolated `DanAuthService` abstraction with a working `MockDanAuthAdapter`
  plus a backend Edge Function (`dan-verify`) implementing the full mock
  DAN session flow end-to-end (spec section 9).
  - **Registration flow, later confirmed decision**: phone/OTP stays the
    actual Supabase Auth credential (unchanged — there's no alternative
    auth backend in this project), but every signed-in user is now routed
    through a new `CompleteProfileScreen` (`/auth/complete-profile`)
    right after OTP verification, collecting овог/нэр + регистрийн дугаар
    before anywhere else in the app — enforced by `app_router.dart`'s
    redirect (awaits a new `identityDetailsCompletedProvider`), not
    optional or skippable the way DAN verification (which follows
    immediately after, still skippable) is. Stored in a new, deliberately
    *private* `public.identity_details` table — never `public.profiles`,
    which is world-readable by design — see that table's own comment in
    `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`.
- Profile: public profile read via `profiles` table, verification badge
  display, basic stats.
- Database: every table from spec section 31, UUID PKs, FKs, indexes, and
  business-rule constraints enforced *in Postgres* — notably a GiST
  exclusion constraint that makes double-booking impossible at the
  database level (`bookings_no_overlap`), not just in app code. Full RLS
  per spec section 32, including tables (`payments`, `wallets`,
  `admin_users`, `audit_logs`) that intentionally have **no client write
  policy at all** — only backend service-role code can touch them.
- Home: search entry point, category chip row, prominent "+ Хөрөнгө
  нэмэх" action, and seven discovery sections (Nearby, Popular, Recently
  added, Recommended, Under 50,000₮, Verified owners, Trending) — each
  just a different `AssetSearchFilters` value fed through one shared
  `homeSectionProvider` family, so a section is genuinely live data
  against `public.asset_cards`, not a mock. Nearby uses best-effort device
  location (`geolocator`) and simply doesn't render if location isn't
  available — never an error state for a non-essential section.
- Search: debounced (400ms) free-text search, a filter/sort bottom sheet
  (category, price range, verified-owners-only, six sort options),
  2-column results grid with cursor-based "load more". Favoriting a card
  is fully wired end-to-end against the `favorites` table with optimistic
  UI and revert-on-failure. **As of Phase 12**, the free-text query runs
  as real Postgres full-text search (`assets.search_vector`, a generated
  `tsvector` over title/description/brand/model, GIN-indexed) instead of
  a `title`-only `ILIKE '%query%'` — see "Admin dashboard: security &
  performance hardening" below.
- Asset browsing data layer: `AssetRepository`/`FavoritesRepository`
  abstractions, `SupabaseAssetRepository` querying the new
  `public.asset_cards` view, `GeoUtils` (pure-Dart Haversine distance,
  since there's no PostGIS in this schema yet) backing the "closest"
  sort.
- Asset create form (spec section 14, manual — the AI listing assistant
  layer on top is Phase 10): photos (pick/reorder/remove, capped at 8),
  title/description/category/brand/model/condition, a small ad-hoc
  specifications editor, per-hour/day/week pricing,
  pickup method + delivery toggle + free-text location, a rental-rules
  list, client-side validation (title, category, at least one price),
  and a real submit → `AssetRepository.createAsset` → navigates to the
  new listing's detail screen. **As of Phase 11**, every new listing lands
  in `pending_review`, not published immediately — the client still sends
  `status: 'published'` (harmless now; see the doc comment on
  `SupabaseAssetRepository.createAsset`), but a new
  `enforce_asset_status_transition` trigger overrides it server-side. The
  owner sees their own pending/rejected/suspended listing on "Миний
  хөрөнгө" with a status badge (`AssetCardTile`) explaining why it isn't
  publicly visible yet.
- Full asset detail screen (spec section 16): swipeable photo gallery
  with dot indicator, title/category/rating/location, an owner card
  (avatar, name, verification badge, member-since, rating), description,
  specifications (brand/model/condition + any free-form specs), rental
  rules, a static cancellation-policy blurb, and a
  sticky bottom price + "Захиалах" bar that now opens the real booking
  request flow (hidden entirely when you're viewing your own listing,
  since you can't book your own asset).
- "Миний хөрөнгө" (My assets, spec section 22's minimal slice): the
  signed-in user's own listings in any status, reachable by tapping the
  "Хөрөнгө" stat on Profile. Not the full owner analytics dashboard
  (views/bookings/earnings) that spec section 22 also describes — that
  needs booking data that doesn't exist until Phase 4.
- Mock payment collection (spec sections 19, 34, 51): once a booking is
  `confirmed`, the booking detail screen shows a "Pay now" action for the
  renter. Tapping it calls the `initiate-payment` Edge Function (creates a
  `pending` `public.payments` row idempotently — re-opening the screen or
  retrying never creates a duplicate charge attempt), then opens a
  deliberately loud mock checkout sheet (red warning banner, "this is not
  a real payment gateway") where the user picks "simulate success" or
  "simulate failure" — standing in for what a real provider's redirect/
  webhook would report. That outcome is sent to `mock-complete-payment`,
  which is the only thing allowed to actually flip `payments.status`
  server-side. The owner sees the same status read-only. No client code
  path can write to `payments` directly — see "Database" above and
  `supabase/README.md`.
  - **Superseded — booking payments are wallet-balance-based now**, a
    later confirmed product decision. `PaymentSection` no longer opens
    the mock checkout sheet; "Pay" calls the new `pay_booking_from_wallet`
    RPC directly, debiting the renter's own `wallets.available_balance`
    and settling synchronously (no external gateway step at all for a
    booking payment). Insufficient balance offers the wallet top-up sheet
    instead of a generic error. `initiate-payment`/`mock-complete-payment`
    are left in the repo (harmless, still fine for local dev/tests of the
    old flow) but are no longer in the app's actual checkout path — see
    the Wallet bullet below and `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`.
- DAN production adapter + "Get verified" flow (spec sections 9, 10, 51):
  the `DanAuthService` interface gained a real client, `EdgeFunctionDanAuthAdapter`,
  which always calls the `dan-verify` Edge Function — that function's own
  `DAN_AUTH_MODE` secret (not anything in the Flutter binary) decides
  whether it answers with mock data or, once credentials/docs exist, real
  DAN. `DanAuthServiceFactory` picks between this and the fully-offline
  `MockDanAuthAdapter` (used for `DAN_AUTH_MODE=mock`, still zero-network,
  still what tests run against). This closes a real gap: `startVerification`/
  `checkStatus` existed since Phase 1 but nothing in the UI ever called
  them. Profile now has a "Баталгаажуулах" (Get verified) entry (hidden
  once already DAN-verified) that opens a new `VerificationScreen`:
  start session → consent step → poll → verified badge. The consent step
  itself checks the returned URL's host — the project's own mock
  placeholder domain (`mock-dan.local`, returned by both adapters' mock
  paths) shows an in-app, loudly-labeled mock consent step; anything else
  opens a real browser via `url_launcher`. See "Known issues" for what a
  real DAN consent *callback* still needs.
- Wallet (spec sections 20, 33, 34): "Хэтэвч" on Profile shows the
  signed-in user's balance (available / pending / total earned, straight
  from `public.wallets` — nothing computed client-side), a transaction
  ledger tab, and a payout-requests tab. Once a booking's payment reaches
  `paid`, `mock-complete-payment` calls a new `credit_wallet_for_payment`
  Postgres function (service-role only — see "Database" and
  `supabase/README.md`) that credits the owner's `pending_balance` with
  their net share (`rental_amount + delivery_fee`, excluding the platform
  fee) and logs a `wallet_transactions` row.
  Requesting a payout is one of the few client-side inserts left in this
  schema (`payouts_insert_own` RLS) since creating the *request* doesn't
  move money — but a `validate_payout_request` trigger still rejects it
  server-side if the amount exceeds what's actually available (accounting
  for the user's other pending/processing requests too), so the client is
  never trusted to self-report a valid withdrawal amount.
  - **Funds didn't leave `pending_balance` as of this phase** — there was
    no booking-completion flow yet (nothing set `bookings.status =
    'completed'`), so nothing moved a credited amount to
    `available_balance`. This was called out in
    `credit_wallet_for_payment`'s own header comment rather than quietly
    crediting `available_balance` early. **As of Phase 9, that release
    now happens** — see the "Pickup/return condition reports, reviews,
    and disputes" bullet below for the trigger that does it.
  - **Real money enters a wallet via wire.mn top-ups now.** "Хэтэвч"
    gained a "Цэнэглэх" (top up) action: pick an amount, and
    `wire-topup`'s `create` action creates a fresh wire.mn PaymentIntent +
    checkout session per request (never a shared static link — see that
    function's header comment for why) and opens the hosted
    `pay.wire.mn/c/...` page. `wire-topup-webhook` (public, signature-
    verified, fails closed on anything it can't verify) credits
    `available_balance` directly once wire.mn confirms the payment.
    `WIRE_TOPUP_MODE=mock` (the default) skips wire.mn entirely and lets
    the sheet self-complete for local dev/demo, same gating convention as
    `DAN_AUTH_MODE`/`PAYMENT_PROVIDER_MODE`. See `supabase/README.md` for
    the secrets a real deployment needs (set only via
    `supabase secrets set`, never committed).
  - **As of Phase 11, payout requests are processed** — `admin_process_payout`
    (`supabase/migrations/0012_admin_dashboard.sql`) moves a request through
    `pending → processing → paid|failed` (or straight to `failed` from
    either open state), only actually deducting `available_balance` on the
    `processing → paid` transition (money hasn't left until it's confirmed
    sent). See "Admin dashboard" below.
- Chat and notifications (spec sections 21, 33): every booking now has a
  real conversation behind it. `get_or_create_conversation_for_booking`
  (a `SECURITY DEFINER` RPC — neither `conversations` nor
  `conversation_members` allow direct client inserts) is idempotent and
  race-safe: a `conversations_booking_id_unique` constraint plus a caught
  `unique_violation` means two participants opening chat at the same
  instant both land on the same conversation instead of creating two.
  Booking Detail has a new "Мессеж бичих" action (owner and renter both
  see it) that opens `ChatScreen`, which lists messages over a genuine
  Supabase Realtime subscription — not a poll — so a reply from the other
  side appears live, and sends go straight through `messages`' existing
  `messages_insert_member` RLS rather than a new RPC. A `BEFORE INSERT`
  trigger (`flag_suspicious_message`) always overwrites
  `flagged_for_review` server-side using a regex heuristic (long digit
  runs that look like a phone number; bank-transfer/off-platform-payment
  keywords) — flagged messages still send, just with a visible in-chat
  notice, and this is documented as a heuristic, not a real moderation
  system. `notifications` has no client insert policy at all; rows are
  created entirely server-side — `notify_new_message` and
  `notify_booking_status_change` Postgres triggers cover new messages and
  every booking status transition, and `mock-complete-payment` now also
  inserts payment-succeeded/received/failed notifications for both
  participants. The DB's `title`/`body` columns are an English fallback
  only — the Home app bar's new bell icon (live unread-count badge, also
  over Realtime) and the `NotificationsScreen` it opens both render fully
  localized mn/en copy keyed off each row's `event_type` via
  `notificationCopy()`, falling back to the DB columns only for event
  types the client doesn't recognize yet. Tapping a notification marks it
  read and, if it has a `deep_link`, navigates straight there.
- Pickup/return condition reports, reviews, and disputes (spec sections
  25, 26, 27 — see `supabase/migrations/0010_condition_reports_reviews_disputes.sql`).
  Booking Detail grows a "Rental progress" section once a booking is
  `confirmed`: either participant can submit a pickup report (photos +
  notes); submitting auto-confirms your own side, the other participant
  confirms separately from the same screen. Once both have confirmed,
  a Postgres trigger — not the client — moves the booking to `active`;
  the same thing happens for the return report, which moves it to
  `completed` **and**, in the same trigger, finally releases the owner's
  `pending_balance` for that booking into `available_balance` (closing
  the gap Phase 7's `credit_wallet_for_payment` deliberately left open).
  Pickup is blocked server-side until the booking actually has a `paid`
  payment — this app never let you skip straight to "picked up" without
  money changing hands first. Once `completed`, either side can leave a
  review (overall rating + three fixed category ratings — communication,
  accuracy, item condition — plus an optional comment); a trigger keeps
  `profiles.rating`/`review_count` in sync, so Profile's "Reviews" stat
  (tappable, like "Assets") and any rating shown elsewhere are finally
  real numbers instead of the permanent zero every profile had before
  this phase. Either participant can also raise a dispute (category +
  description + optional evidence photos, private `dispute-evidence`
  Storage bucket) any time from `confirmed` onward — doing so flips the
  booking to `disputed` (blocking new condition reports on it) and, once
  an admin resolves it (**as of Phase 11**, through the admin dashboard's
  dispute queue — see below — rather than direct database access), the
  same trigger restores whatever status the booking had before and
  notifies both sides.
- AI listing assistant (spec sections 14, 51). Once at least one photo is
  picked on the create-listing form, a new "AI-аар санал авах" (Get AI
  suggestion) button calls the `suggest-listing-from-photo` Edge
  Function, gated by an `AI_LISTING_MODE` secret the same way
  `DAN_AUTH_MODE`/`PAYMENT_PROVIDER_MODE` gate DAN/payments. No
  vision-capable API key was available, so — matching this project's rule
  against claiming a feature works when it doesn't — the mock branch
  never pretends to recognize what's actually in a photo: it prefills the
  description with a fill-in-the-blanks template, defaults condition to
  a neutral "good," and offers spec *field names* worth filling in
  (brand, model, color, year) as tappable chips that pre-fill the spec
  key for you — never fabricated values. A persistent on-screen
  disclaimer says as much. The endpoint is logged and rate-limited (new
  `ai_listing_suggestions` table, 30 calls/day) — real infrastructure a
  production vision integration would need on day one, built now rather
  than left as a gap alongside the mock itself, generous today since a
  mock call costs nothing.
- Admin dashboard (spec sections 22, 29, 30, 34 — see
  `supabase/migrations/0012_admin_dashboard.sql`). Closes every gap
  earlier phases flagged as "waiting on Phase 11", plus one this phase
  found on its own: nothing had ever stopped a client from setting
  `assets.status` straight to `'published'` via `assets_update_own`'s
  RLS (owner-writable, no column restriction) — a new
  `enforce_asset_status_transition` trigger is the first thing in this
  schema to actually gate that column, forcing every new asset into
  `pending_review` on insert and allowing only admin actions or one
  owner self-service resubmit (`draft → pending_review`) afterward.
  Reachable from Profile → "Админ самбар", shown only when
  `isAdminProvider` resolves true for the signed-in user (a UX
  convenience only — every RPC below re-checks `is_admin(auth.uid())`
  itself, so the client-side gate is never the actual authorization
  boundary). Five queues/screens, each backed by one or more
  `SECURITY DEFINER` RPCs that self-check admin status and write to
  `audit_logs` before returning:
  - **Asset moderation**: `admin_approve_asset`/`admin_reject_asset`
    (→ back to `draft` with a stored `moderation_note` reason, not a
    dead-end "rejected" status — the owner can edit and
    `resubmit_asset_for_review`)/`admin_suspend_asset` (for already-`published`
    listings). The queue itself is just `public.asset_cards` filtered to
    `pending_review`/`published` — the same view every browse/search
    surface already reads, now also carrying `status`/`moderation_note`.
  - **Commission settings**: a new single-row `platform_settings` table
    (`admin_update_commission_percent`) that `create_booking` now reads
    instead of a hardcoded 10% — closing the gap Phase 4's RPC left as a
    `TODO(Phase 11)`.
  - **Payout processing**: `admin_process_payout`, described above under
    "Wallet".
  - **Dispute resolution**: `admin_resolve_dispute` — and this phase
    *dropped* `disputes_update_admin`'s direct-RLS-write policy entirely,
    since a direct write bypassed `audit_logs` (spec section 30: "every
    sensitive admin action must write here" — true in the schema comment
    since Phase 0, never actually enforced until now). Resolving a
    dispute through the RPC still relies entirely on Phase 9's existing
    `restore_booking_status_after_dispute_resolution` trigger to restore
    the booking and notify both sides — no duplicated logic.
  - **Report resolution**: `admin_resolve_report` — the first admin
    action ever wired to `public.reports`, which existed since Phase 0/1
    with only an insert-own policy. **The client entry point this
    section used to flag as missing now exists** — see "Follow-up pass"
    above (`lib/features/reports/`, wired into asset detail, the owner
    card, and chat message long-press) — so the admin queue screen now
    has a real feeder instead of always showing empty.
  - `AssetCard` (the shared browse/search/my-assets entity) grew
    `status`/`moderationNote` fields alongside this — `AssetCardTile` now
    shows a status badge for any non-`published` asset, which in practice
    only ever renders on "Миний хөрөнгө" (every public browse/search query
    still filters `.eq('status', 'published')`), so an owner can see
    *why* their new listing isn't publicly visible yet instead of
    wondering if something broke.
- Admin dashboard: security & performance hardening (Phase 12, spec
  sections 30/34 — see `supabase/migrations/0013_security_perf_hardening.sql`).
  A narrow pass, not a new feature area — one real security gap and two
  real performance gaps found by re-reading the schema, not a
  speculative rewrite:
  - **Promotions**, a new 6th admin queue ("Урамшуулал" on the admin
    dashboard): list every promotion (active or not), create/edit
    through one form (`AdminPromotionFormScreen`, reused for both since
    `admin_upsert_promotion` is one RPC either way), deactivate with one
    tap. This closes the one direct-RLS admin-write path
    (`promotions_admin_write`) Phase 11's own README flagged but
    deliberately left out of scope — every write now goes through an
    audited RPC and drops that policy, the same shape as Phase 11's
    `disputes_update_admin` closure. `public.promotions` had zero
    Flutter code touching it before this — there is still no
    consumer-facing "apply a promo code at booking" flow; this closes
    the admin-authoring gap only.
  - **Real full-text asset search.** Search's free-text query now runs
    against `assets.search_vector` (a generated `tsvector` over
    title/description/brand/model, GIN-indexed) via
    `.textSearch('search_vector', query, config: 'simple', type:
    TextSearchType.websearch)`, replacing a `title`-only `ILIKE
    '%query%'` that no index could make fast on a leading wildcard, and
    that never looked at description/brand/model at all.
    `config: 'simple'` deliberately, not `'english'` — Postgres ships no
    Mongolian dictionary, so 'simple' tokenizes and lowercases without
    pretending to linguistically stem either language.
  - A missing `payouts_status_idx` — the Phase 11 admin payout queue
    filters on `status`, which had no supporting index before this.
  - See "Security" below for a written summary of this project's RLS/
    audit-logging posture, produced by re-reading every RLS policy and
    Edge Function with a reviewer's eye rather than adding new controls
    speculatively.
- Tests: unit tests for `CurrencyFormatter`, `Validators`, `AppDateUtils`,
  `AppLocalizations`, `GeoUtils`, `AssetSearchFilters.copyWith`,
  `NewAssetInput.hasAtLeastOnePrice`, `DateRangeUtils.overlapsAny`,
  `PriceBreakdown.estimate`, `PaymentStatus.fromId`; widget tests for
  `PrimaryButton`, the onboarding screen, the language settings screen,
  `CategoryChipRow`, `showMockPaymentSheet`'s three outcomes (that sheet
  is unused by `PaymentSection` now — wallet-based payments, see above —
  but stays exercised on its own), and `PaymentSection`'s pay-from-wallet
  flow (idle -> paid, and the insufficient-balance -> top-up-dialog path)
  against a fake `PaymentRepository`; a debounce-timing test for
  `SearchAssetsController` using Flutter's fake test clock; unit tests for
  `AssetCreateController`'s photo add/remove/reorder logic, for
  `BookingRequestController.submit`'s success/in-flight/failure paths,
  for `VerificationController`'s start/consent/poll state machine
  (including the timeout and "backend reported failed" branches), for
  `WalletTransactionType.fromId`/`PayoutStatus.fromId`, for
  `RequestPayoutController.submit`'s success/in-flight/failure paths, for
  `MessageKind.fromId`, for `SendMessageController.submit`'s success/
  in-flight/failure paths against a fake `ChatRepository`, for
  `notificationCopy()`'s localized-vs-fallback copy selection and its
  icon mapping, for `ConditionReportStage.fromId`/`DisputeStatus.fromId`/
  `DisputeStatus.isActive`/`DisputeCategory.fromId`/`ReviewerRole.fromId`,
  for `ConditionReport`'s `isFullyConfirmed`/`needsConfirmationFrom`
  view helpers, for `SubmitConditionReportController`/
  `ConfirmConditionReportController`/`SubmitReviewController`/
  `SubmitDisputeController`'s success/in-flight/failure paths, for
  `SuggestListingController`'s success/in-flight/failure paths (including
  a simulated `rate_limited` failure), and for `AssetStatus.fromId`/
  `ReportStatus.fromId`/`ReportTargetType.fromId` and every Phase 11 + 12
  admin action controller (`AssetModerationController`'s approve/reject/
  suspend, `PayoutProcessingController`, `DisputeResolutionController`,
  `ReportResolutionController`, `CommissionSettingsController`, and
  `PromotionManagementController`'s upsert/deactivate) — the admin
  controller tests share one `FakeAdminRepository`
  (`test/features/admin/fake_admin_repository.dart`, a deliberate
  exception to this project's usual one-fake-per-test-file convention,
  since `AdminRepository` has grown to over a dozen methods across six
  unrelated queues), and every other controller test above against its
  own fake repository.

## Localization (Mongolian / English)

Every screen and shared widget currently built (onboarding, phone/OTP
auth, home placeholder, profile, error/empty/offline states, the verified
badge) reads its copy from `AppLocalizations.of(context)` — nothing is
hardcoded inline (spec section 38: "Do not hardcode UI text inside
widgets").

`AppLocalizations` (`lib/app/localization/app_localizations.dart`) is
**hand-written**, not generated by `flutter gen-l10n` — and as of this
pass, that's the *only* localization system in this repo. That's a
deliberate choice, not a shortcut: this project was built in a sandbox
with no working Flutter SDK, so generated codegen output could never
actually be produced or checked here. A plain Dart class with `mn`/`en`
getters is something that can be read and verified by inspection like
every other file in this scaffold.

**This repo used to also carry a parallel ARB/`flutter gen-l10n` scaffold**
(`lib/app/localization/arb/app_mn.arb`/`app_en.arb`, `l10n.yaml`,
`generate: true` in `pubspec.yaml`) alongside the hand-written class, with
a comment claiming their keys matched `AppLocalizations`'s getters 1:1.
That was true only at the very beginning (~45 keys, Phase 0/1) and was
never kept in sync as the hand-written class grew to 400+ getters across
every later phase — an external audit (Aug 2026) correctly caught this as
stale, false documentation. Rather than try to hand-sync two systems
retroactively (error-prone, and `flutter gen-l10n` was never actually run
against this repo to verify it produces a usable result), the dead ARB
scaffold was removed entirely: no `arb/` directory, no `l10n.yaml`, no
`generate: true`, no `flutter gen-l10n` step in CI. `AppLocalizations` is
now accurately documented as the one and only localization system, not a
placeholder for a migration that was never actually validated.

The user's language choice is Mongolian or English (spec section 38 lists
exactly these two), defaults to Mongolian regardless of device locale
(`LocaleController`, `lib/app/localization/locale_controller.dart`),
persists via `LocalCacheService`, and is switchable from Profile → the
language icon in the app bar → `LanguageSettingsScreen`
(`/settings/language`). Switching languages updates the whole app
immediately since `HuvaaltsApp` watches `localeControllerProvider` at the
`MaterialApp.router` level.

## Security (Phase 12 audit summary)

A written summary of this project's actual security posture, produced by
re-reading every RLS policy and Edge Function with a reviewer's eye
(spec section 34) rather than a checklist of controls added
speculatively. What's true today:

- **Every table has RLS enabled** (`0002_rls_policies.sql`); there is no
  table a client can read/write without an explicit policy allowing it.
- **Money, price, and status are never client-authoritative.** Booking
  price and commission are recomputed server-side in `create_booking`
  (never trusted from the client — `0006`, updated by `0012` to read
  commission from `platform_settings` instead of a hardcoded value);
  wallet balances are only ever moved by `SECURITY DEFINER`
  functions/triggers (`credit_wallet_for_payment`, `admin_process_payout`,
  the condition-report-driven pending→available release); `payments`/
  `payment_events` have **zero client-facing write policies at all** —
  only the two Edge Functions (using a service-role client) can touch
  them; asset `status` can no longer be set directly by an owner as of
  Phase 11's `enforce_asset_status_transition` trigger.
- **Every admin mutation is audited.** As of Phase 11 + this phase, the
  only ways `assets.status`, `payouts.status`, `disputes.status`,
  `reports.status`, `platform_settings`, and `promotions` can change are
  `SECURITY DEFINER` RPCs that each call `log_admin_action` before
  returning — there is no remaining direct-RLS admin-write policy on any
  of those tables. (`admin_users`/`audit_logs` themselves still have no
  client write policy at all — becoming an admin, or tampering with the
  audit trail, is a database-level action only, by design.)
- **Rate limiting exists where a client could otherwise call a real cost
  center for free**: `ai_listing_suggestions` caps a user at 30 calls/24h
  before `suggest-listing-from-photo` does anything else. Nothing else
  in this schema currently needs a rate limit the same way — booking/
  payment/wallet actions are all naturally self-limiting (you can't
  request infinite payouts you don't have balance for; `create_booking`'s
  `bookings_no_overlap` exclusion constraint prevents booking spam from
  double-booking anything) or already gated by RLS ownership checks.
- **Secrets never reach the Flutter binary.** DAN/payment/AI mode
  switches (`DAN_AUTH_MODE`, `PAYMENT_PROVIDER_MODE`, `AI_LISTING_MODE`)
  and any real provider credentials live only in Edge Function secrets,
  never in the `env/*.json` dart-define files compiled into the app —
  see each function's header comment.

What this audit did **not** find a fix for this phase (tracked as
known gaps elsewhere in this document rather than silently dropped):
admin-invite is still a manual database step; `promotions` administration
is now audited but the *table itself* still has no consumer-facing
read path wired into any screen; native OAuth (Google/Apple) isn't wired
so there's nothing to audit there yet. **Storage bucket-level file
size/MIME restrictions — the bullet that used to be here claimed these
"aren't expressible in a portable SQL migration"; that was wrong** (an
external audit, Aug 2026, correctly caught it) and is now fixed — see
"External audit follow-up pass" below.

## Bug-fix pass (post-Phase-12 review)

After all 12 phases were done, the full codebase (every migration and
every Dart file, not a sample) was re-read specifically hunting for
defects rather than missing features. Eleven concrete, verified bugs
were found and fixed — no new features, no architectural changes:

- `cancel_booking` let a `confirmed` booking that had *already been
  paid* be cancelled with no refund mechanism, permanently leaving the
  owner's wallet credited for a rental that never happened. Now blocked
  (`cannot_cancel_paid_booking`) — a paid, confirmed booking has to go
  through the dispute flow instead. (`0014_bug_fixes.sql`)
- `credit_wallet_for_payment`'s idempotency check (guarding against
  double-crediting on a duplicate payment webhook) ran without locking
  anything, so two concurrent calls could both pass it before either
  had inserted its row. Now locks the booking row first. (`0014`)
- `reviews_insert_participant` checked that the *reviewer* was a
  participant on a completed booking, but never checked that
  `reviewee_id` was actually the *other* participant — any user with
  one completed booking could rate any arbitrary user. Fixed. (`0014`)
- `assets_update_own` let an owner PATCH `is_featured` directly via
  PostgREST (nothing gated it, unlike `status`, which
  `enforce_asset_status_transition` already protected) — a
  self-promotion path to the top of every "Closest"/browse sort. Now
  admin-only, same trigger. (`0014`)
- `conversation_members_update_own` let a member freely clear their own
  `is_blocked` flag, defeating the point of that column the moment
  anything ever sets it. Now column-privilege-restricted to
  `last_read_at` only. (`0014`)
- `confirm_condition_report` didn't check the booking's status. A
  dispute raised mid-pickup-confirmation could let the both-sides-
  confirmed trigger fire while the booking was `disputed` (not
  `confirmed`), silently no-op, and permanently strand the booking at
  `confirmed` even after the dispute resolved. Now blocked while
  disputed, matching the same check report *submission* already had.
  (`0014`)
- `AppDateUtils.formatShortDate`/`formatDateRange` rendered a
  `timestamptz` in UTC instead of local time — any date within a few
  hours of local midnight (Mongolia is UTC+8) showed the wrong calendar
  day. Now calls `.toLocal()`, matching `formatDateTime`.
- `errorSessionExpired` was a fully translated, unused l10n string —
  `AuthFailure` collapsed both `UnauthorizedException` and
  `SessionExpiredException` into one generic message. `failurePresentation`
  now distinguishes by the exception's message so it's actually reachable.
- A signed condition-report photo URL was re-requested (and every
  thumbnail flashed back to a loading skeleton) on every unrelated
  rebuild of the photo strip, since the `Future` was built inline in
  `build()` instead of cached. Moved to an `autoDispose` Riverpod
  provider keyed by storage path.
- The asset create form let a negative price/deposit through client-side
  validation, relying entirely on the database's `CHECK` constraint and
  surfacing a generic conflict error instead of an inline field error.
  Now caught before submit.
- `messagesStreamProvider`/`unreadNotificationCountProvider` (chat,
  notifications) were plain `StreamProvider.family`, not `autoDispose` —
  Riverpod never released them, so the Supabase Realtime channel each
  one opens leaked for the rest of the app process's lifetime, for every
  conversation/user ever watched. Both are now `autoDispose`.

## Security & consistency hardening pass (post-wallet-integration review)

After the wire.mn wallet top-up + wallet-based booking payments landed
(0017), the full codebase was independently re-reviewed a second time —
four parallel passes over auth/routing, wallet/wire.mn, booking/payments,
and every remaining feature — specifically hunting for money-conservation
bugs, authorization gaps, and race conditions now that real money moves
through the app. All fixes are in `0018_security_and_consistency_hardening.sql`
plus the Dart/Edge Function files they touch:

- **Critical — free-money exploit.** The pre-wallet `initiate-payment` /
  `mock-complete-payment` Edge Functions were still deployed and
  reachable directly (no app UI needed — just the caller's own JWT).
  Since `pay_booking_from_wallet` superseded them, calling both in
  sequence could mark an arbitrary booking "paid" and credit the
  owner's wallet with **no debit ever happening on the renter's side**.
  Both functions are now permanently disabled (return `410`
  unconditionally); the vestigial `initiatePayment`/`completeMockPayment`
  client methods and the dead `showMockPaymentSheet` widget were removed
  entirely so nothing can wire back to them by mistake.
- **`profiles_update_own` / `users_update_own`** had no column
  restriction — any signed-in user could PATCH their own
  `verification_level`/`rating`/`review_count` directly via PostgREST,
  fabricating a "DAN verified" badge and a perfect rating with zero real
  verification. Column-privilege-restricted (same technique 0014 already
  used twice) to `display_name`/`avatar_url`/`bio` only; `users` gets no
  client-writable columns at all.
- **`identity_verifications_insert_own`** had no restriction on
  `status`, so a client could insert a row claiming `status='verified'`
  directly, bypassing DAN. Now restricted to `status='pending'`.
- **Cross-wallet deadlock risk**: `pay_booking_from_wallet` and the new
  `admin_refund_booking_payment` (below) touch the same renter/owner
  wallet pair in opposite order — on a P2P marketplace it's entirely
  possible for two users to be renter and owner of each other's
  bookings, so concurrent transactions could deadlock. Fixed at the
  root with a shared `lock_wallet_pair` helper every money-moving
  function now calls first, always in the same (ascending `user_id`)
  order.
- **No refund path existed anywhere.** Once a paid, confirmed booking
  turned into a dispute, there was no way to ever move money back to
  the renter — `admin_resolve_dispute` only ever touched
  `disputes`/`bookings` status, never `wallets`. Added
  `admin_refund_booking_payment`: an explicit, separate admin action
  (not automatic on every dispute resolution) that claws back the
  owner's share and returns the renter's full payment, wired into the
  admin dispute queue screen as a "Refund renter" action.
- **`dan-callback`** could revert an already-`verified` row back to
  `failed` if two deliveries of the same callback raced (one succeeding,
  the other's token exchange failing afterward). Both write paths now
  guard with `.eq('status', 'pending')`, matching the pattern the
  cancellation path already used.
- **`WIRE_TOPUP_MODE` failing open into mock** when the env var was
  simply unset meant a deployment that shipped `WIRE_SECRET_KEY` but
  forgot the separate mode flag would silently keep taking the mock
  branch — and `mock_complete` would credit real wallet balance for
  free. Now also refused whenever `WIRE_SECRET_KEY` is configured at
  all, regardless of the mode flag.
- **`IdentityDetailsController.submit()`** read `authControllerProvider`
  synchronously (`.value`), the same first-read `AsyncNotifier` race
  `VerificationController` had already been fixed for — a fast submit
  right after OTP verification could see a null user and report a
  spurious "unauthorized". Now awaits `.future`, same as
  `WalletTopupController`'s post-success wallet-cache invalidation.
- **Router stuck state**: a session ending while a user sat on
  `CompleteProfileScreen` (explicit sign-out, or a failed token refresh)
  left them permanently stranded there — every redirect branch required
  `signedIn`, and that route was wrongly treated as a safe-for-signed-out
  "auth route". Fixed.
- **`messages.body`** had no length limit anywhere (DB, repository, or
  UI) — an unbounded storage-growth vector. Capped at 2000 characters,
  DB-enforced with a matching client-side `maxLength`.
- **`asset_images`** had no server-side cap, only the client's own
  `kMaxAssetPhotos` — mirrored server-side via a trigger.
- **`assets.view_count`/`favorite_count`** were declared and read by
  Home's "Popular"/"Trending" sort options but nothing anywhere ever
  incremented either one — both silently sorted by nothing since launch.
  `favorite_count` now stays in sync via a trigger on `favorites`;
  `view_count` gets a dedicated RPC the asset detail screen calls once
  per open.
- The `condition-reports` storage bucket policy was participant-only,
  unlike the otherwise-identical `dispute-evidence` bucket, which also
  grants admins read access — aligned.
- Added test coverage for the two areas above that had none at all
  before this pass despite handling real money: `WalletTopupController`
  (create/poll/mock-complete state machine, bounded-retry give-up,
  transient-error resilience) and `IdentityDetailsController` (the auth
  race fix, display-name seeding rules, duplicate-register-number
  mapping).

Deliberately **not** fixed in this pass (flagged, not silently dropped —
see "Known issues" below): no automatic expiry for a `pending` booking
request the owner never responds to; no in-app "report a listing/user"
entry point despite the backend fully supporting it; no reconciliation
job for a `wallet_topups` row orphaned between wire.mn's two API calls.
**All three are addressed in the follow-up pass immediately below.**

## Follow-up pass: the three gaps flagged above

A direct continuation of the hardening pass — closes each of the three
"deliberately not fixed" items above rather than leaving them
permanently as known gaps.

- **Pending-booking auto-expiry.** Added
  `public.expire_stale_pending_bookings()`
  (`0019_pending_booking_expiry.sql`) — cancels any `pending` booking
  older than 48 hours (`cancellation_reason = 'expired_no_owner_response'`),
  freeing its dates for other renters (it counted toward
  `bookings_no_overlap`'s exclusion constraint the whole time it sat
  unanswered). Uses `for update skip locked` so it never blocks on a
  booking a participant is concurrently confirming/rejecting/cancelling.
  `0020_pending_booking_expiry_schedule.sql` schedules it hourly via
  `pg_cron` — kept in its own migration on purpose since `pg_cron`
  availability isn't guaranteed on every Postgres instance this schema
  might run on; see that file's header comment for the fallback if it
  fails to apply. While implementing this, also fixed a latent bug in
  `notify_booking_status_change` (0009): a system-initiated status
  change (no `auth.uid()` — exactly what the new sweep produces) fell
  into the same branch as "the renter acted" and only ever notified the
  owner, so a renter whose own booking just got auto-cancelled would
  never have been told. Now notifies both participants when the actor
  can't be resolved.
- **Client-facing "report abuse" entry points.** New `lib/features/reports/`
  feature (repository/controller/`showReportSheet` bottom sheet, 5 fixed
  reason options + optional free-text details) wired into three places:
  the asset detail AppBar ("report this listing"), the owner card on the
  same screen ("report this user"), and a long-press on any *other*
  participant's chat bubble ("report this message" —
  `ReportTargetType.message`). All three insert into the `public.reports`
  table that had existed with full RLS and an admin resolution RPC since
  Phase 0/1, but had zero client code ever creating a row until now.
- **wire.mn top-up reconciliation.** New `reconcile-wire-topups` Edge
  Function checks stale-`pending` `wallet_topups` rows (older than 15
  minutes, real ones only — mock-mode rows are excluded) directly against
  wire.mn's own PaymentIntent status: credits the wallet if wire.mn says
  it succeeded (via the same idempotent `credit_wallet_for_topup` RPC the
  webhook uses, so a race with a late webhook is harmless), marks the row
  `failed` if wire.mn says it can't ever be paid. Callable two ways: with
  the service-role key as bearer (for scheduling — see the function's
  header comment for why this is deliberately *not* wired through
  `pg_cron`/`pg_net` the way booking expiry is, to avoid ever putting the
  service-role key in a Postgres setting), or by a signed-in admin (the
  "Wire дахин шалгах" tile on the admin dashboard, gated by the same
  `is_admin` check every other admin action uses) for an on-demand manual
  check. Neither path is wired to run automatically out of the box — see
  "Known issues" below for what's still manual about this one.

## External audit follow-up pass (Aug 2026)

A user-run external static audit scored this codebase 68/100 overall,
~32/100 for production readiness, and flagged 16 findings across
architecture, security, DAN/identity, wire.mn, CI/CD, and localization.
Each finding was independently checked against the actual code (not
assumed correct) before acting on it — a few of the audit's own claims
turned out to be about documentation drift rather than a functional bug,
and one (the DAN/ХУР protocol question) could not be fully resolved from
public sources. What follows is an honest per-finding accounting, not a
blanket "all fixed."

**Fixed, verified against the actual code:**

- **Environment isolation (the audit's #1 production blocker).**
  `pubspec.yaml` bundled all three `.env.development`/`.env.staging`/
  `.env.production` files as Flutter assets unconditionally — a
  production release build shipped with development and staging config
  (including a real dev Supabase URL/anon key) readable inside it.
  Rebuilt entirely on `--dart-define-from-file` (`env/*.json`,
  compile-time constants via `String.fromEnvironment`) — a build only
  ever contains the one flavor's file it was invoked with; the other two
  are never part of that build's output in any form. `flutter_dotenv`
  dependency and the old `.env.*`/`.env.example` files are gone. Also
  added `AppConfig.assertNotPlaceholderInProduction()`, called from
  `bootstrap()`: a `production`-flavor build hard-crashes on launch if
  its config still has placeholder values, so a scaffold config can't
  quietly ship. See `lib/app/config/env.dart`'s header comment.
- **`WIRE_TOPUP_MODE`/`DAN_AUTH_MODE` fail-open into mock.** `wire-topup`
  already had a defense-in-depth check (0018) refusing mock-complete if
  a real `WIRE_SECRET_KEY` was configured; `dan-verify` had no equivalent
  for `DAN_CLIENT_ID`/`DAN_CLIENT_SECRET`. Now it does — both `start` and
  `status` refuse the mock branch if DAN credentials are configured but
  `DAN_AUTH_MODE` isn't explicitly `production`, closing the same
  "shipped real secrets, forgot the mode flag" gap the audit flagged.
- **No identity cross-check in `dan-callback`.** A successful ХУР consent
  (`resultCode === 0`) only proves someone authenticated, not that they're
  the person named in this app's own `identity_details` row. Now extracts
  a regnum from the ХУР response (defensively — the exact field shape
  isn't confirmed, same caveat as the point below) and fails verification
  on a mismatch, instead of trusting `resultCode` alone.
- **`wire-topup-webhook`'s payload-shape guessing** didn't cover `data`
  itself being the PaymentIntent (only `data.object`) — added as another
  fallback shape, per the audit's specific claim about wire.mn's event
  schema (that specific claim could not be independently verified against
  a primary wire.mn source, but the fallback is a safe, no-cost addition
  either way).
- **Storage bucket upload restrictions "not expressible in portable
  SQL" was wrong** — `file_size_limit`/`allowed_mime_types` are real
  `storage.buckets` columns the Storage service reads directly.
  `0021_storage_bucket_restrictions.sql` sets an 8 MiB / image-only
  allowlist on all three buckets.
- **Two parallel, drifted localization systems.** A dead ARB/
  `flutter gen-l10n` scaffold (`lib/app/localization/arb/`, `l10n.yaml`,
  `generate: true`) sat alongside the real hand-written
  `AppLocalizations` class with a comment claiming their keys matched
  1:1 — true only at ~45 keys (Phase 0/1), never kept in sync as the real
  class grew past 400 getters. The audit correctly caught this as stale
  documentation. Removed the dead scaffold entirely rather than
  hand-reconciling two systems; `AppLocalizations` is now documented as
  the only localization system.
- **CI would fail on `flutter build apk`/`flutter build ios`** — this
  repo has no `android`/`ios` platform folders (see "Known issues"
  below), and CI never generated them. Added a `flutter create .
  --platforms=android` / `--platforms=ios` step before each build job so
  CI can actually produce a debug build; also passes
  `--dart-define-from-file=env/development.json` to every
  build/test/run command, now that config isn't a bundled asset.
- **JWT verification for the two public callback functions** (called
  directly by ХУР/wire.mn, no Supabase session) lived only as a
  `--no-verify-jwt` flag someone had to remember to pass on every
  deploy. Added `supabase/config.toml` with `verify_jwt = false`
  declared for both, so the CLI applies it automatically.

**Flagged as a real, unresolved question — not fixed, because it
couldn't be responsibly guessed at:**

- **Whether the DAN/ХУР OAuth2 integration (`sso.gov.mn/oauth2/...`) is
  actually the current, correct protocol for production.** Research
  triggered by this audit found live documentation for a *different*
  mechanism (SOAP/XML against `xyp.gov.mn/service-1.5.0/ws`,
  authenticated per-request via an `accessToken`/`timeStamp`/RSA-SHA256
  `signature` trio, not OAuth2) for reaching the same named service this
  code calls — but also found a live, current OAuth 2.0 docs section at
  `developer.sso.gov.mn` consistent with what's implemented here, which
  may mean these are two genuinely separate ХУР products (citizen
  login/consent vs. a data-exchange API used after authentication).
  Public documentation wasn't sufficient to resolve this with confidence,
  and registering as a real ХУР integrator requires a formal request to
  Цахим хөгжил, харилцаа холбооны яам — not something verifiable from
  outside that process. **Do not flip `DAN_AUTH_MODE=production` against
  a real citizen without confirming this exact flow against your own
  registered integration's documentation first.** See `dan-verify/index.ts`'s
  header comment for the full detail.

**Findings the audit raised that turned out to already be accurately
handled, on closer check:**

- Google/Apple native sign-in and Firebase not being initialized are
  both already correctly guarded (a named `..._requires_native_flow_wiring`
  exception for the former; a startup warning, no code anywhere calls a
  Firebase API before init, for the latter) and already documented as
  known gaps requiring real platform projects/credentials this sandbox
  cannot fabricate — not silently broken, just genuinely incomplete
  pending real infrastructure.

**Could not be fixed in this sandboxed, no-Flutter-SDK environment —
requires real tooling/infrastructure, not more code:**

- `pubspec.lock` — generating one honestly requires `flutter pub get`
  resolving against live pub.dev; no Flutter/Dart SDK or `pubspec.lock`-
  generation capability exists in this environment. Run it locally
  before your first real CI run or release build and commit the result.
- `android`/`ios`/`web` platform projects — CI now self-heals this with
  `flutter create .`, but a real signed release still needs the manual
  one-time setup listed in "Before you trust this code" below (signing
  config, `google-services.json`/`GoogleService-Info.plist`, Google/Apple
  OAuth native registration).
- Confirming the DAN/ХУР protocol question above against your actual
  registered integration — needs your own ministry-issued documentation,
  not something obtainable from public sources.

## Known issues / not yet done

- **Flutter SDK could not be run in the environment this was built in**
  (sandboxed, no network access to Flutter's download servers), so
  `flutter pub get`, `flutter analyze`, `flutter pub run build_runner
  build`, and `flutter test` have **not actually been executed against
  this code**. Every file was hand-written carefully and cross-checked
  (import resolution, brace balance, Riverpod/GoRouter/Supabase API
  shapes verified against their current APIs), but treat "run
  `flutter analyze` and `flutter test` before you trust this" as the very
  first thing to do locally — see the checklist at the bottom.
- `freezed`/`json_serializable` codegen (`.freezed.dart`/`.g.dart`) hasn't
  been run, so `AppUser` and `Profile` won't compile until you run
  `build_runner`.
- Google/Apple native sign-in: the button UI exists
  (`SocialAuthButtons`) but the actual native handshake
  (`google_sign_in` package + Android SHA-1 fingerprint registration /
  iOS URL scheme; `sign_in_with_apple` + the Apple Sign In capability) is
  not wired — `SupabaseAuthRepository.signInWithGoogle/signInWithApple`
  currently throw a clear `ValidationException` explaining what's
  missing.
- DAN verification: mock by default (`DAN_AUTH_MODE=mock`, spec section
  9/51), but **`DAN_AUTH_MODE=production` is now a real integration**
  against ХУР (sso.gov.mn) — see `supabase/README.md`'s
  `functions/dan-verify/` and `functions/dan-callback/` bullets for the
  full flow and required secrets (`DAN_CLIENT_ID`, `DAN_CLIENT_SECRET`,
  `DAN_REDIRECT_URI`). The mock path is still fully functional end-to-end
  too (Flutter → `EdgeFunctionDanAuthAdapter` → `dan-verify` Edge
  Function → fake session → verified → `profiles.verification_level`
  updated), reachable from Profile → "Get verified" (Phase 6) — **no
  Flutter code changes** were needed for the production swap either way,
  since the client already always talks to `dan-verify` via
  `EdgeFunctionDanAuthAdapter` regardless of mode.
  - **Still open**: the citizen's browser doesn't automatically hand back
    to the Flutter app once `dan-callback` finishes verifying them — that
    needs a `huvalts://` deep link registered in the native
    `android`/`ios` projects, which don't exist in this repo yet (next
    bullet). Until then, `VerificationScreen`'s existing manual "I've
    given consent" button (unchanged) covers reconnecting to the app
    correctly, since the real outcome is already written server-side by
    the time the citizen taps it — this is a UX polish item (auto-resume
    vs. a manual tap), not a functional gap, same category as Google/Apple
    native sign-in below (which *is* still a real gap, not just polish).
- No `android/` or `ios/` platform projects yet — those get generated by
  `flutter create .` in this directory once you're ready to build/run on
  a device (do this locally, not in this scaffold, so it picks up your
  Flutter SDK version correctly).
- No Firebase wiring yet (Crashlytics/Analytics/FCM) — `bootstrap()` has a
  clearly marked spot to add it after you run `flutterfire configure`.
- Location permissions: `nearbyLocationProvider` calls `geolocator`, which
  needs `ACCESS_COARSE_LOCATION` added to `AndroidManifest.xml` and
  `NSLocationWhenInUseUsageDescription` added to `Info.plist` once the
  platform projects exist (step 1 of the checklist below) — without them
  the Nearby section just never appears, it won't crash, but it also
  won't work until those are added.
- **As of Phase 12, search uses a real `tsvector`/GIN full-text index**
  (`assets.search_vector`), not `title`-only `ILIKE`. Still true:
  "closest" sort fetches a batch and sorts by Haversine distance
  client-side rather than using PostGIS — fine at small catalog size,
  worth revisiting once there's real listing volume and this hardening
  pass's index changes weren't enough on their own (see
  `supabase/README.md`).
- Pagination (`AssetRepository.search`'s cursor) only fully works for the
  newest/recommended sorts; switching to cheapest/most-expensive/highest-
  rated/closest fetches one page without further "load more" support this
  phase — see the doc comment on `SupabaseAssetRepository` for why.
- Map/list hybrid browsing (spec section 13): Search now has a map/list
  toggle (`lib/features/map/presentation/widgets/asset_map_view.dart`,
  wired into `SearchScreen`'s AppBar action) that plots a pin for every
  asset in the currently loaded result page that has coordinates —
  reusing the exact filter/results state the list view already has, not
  a separate fetch. "Live" here is the device's own position, shown via
  `GoogleMap.myLocationEnabled` (the native Maps SDK's own continuously-
  updating blue dot); asset pins themselves are static, since an asset's
  location is fixed at listing time. **This code builds and type-checks
  but has nothing to actually render against yet**, for the same two
  reasons flagged below for Home's Nearby section, plus one more:
  1. No `android`/`ios` platform projects (see the next bullet).
  2. No real Google Maps API key wired into
     `AndroidManifest.xml`/`AppDelegate.swift` — `google_maps_flutter`
     needs one per platform; without it the map view is a blank/grey
     box, not a crash, but also not a working map.
  3. Same location-permission entries as Nearby (`ACCESS_COARSE_LOCATION`
     / `NSLocationWhenInUseUsageDescription`) — without them the map still
     renders and pins still show, it just never enables the "my location"
     blue dot (see the widget's own fallback banner for that case).
  `AssetSearchFilters` already carried `nearLatitude`/`nearLongitude`/
  `radiusKm` before this, which is what let the map reuse Search's
  existing plumbing instead of adding a parallel query path.
- **Admin dashboard (Phase 11) is built, but with real remaining gaps:**
  - **No self-service admin invite/promotion flow.** Making someone an
    admin is still a direct `insert into admin_users (user_id, role)`
    statement — there's no UI (admin or otherwise) to grant/revoke admin
    access. `admin_users_select_admin` RLS means `isAdminProvider` at
    least resolves correctly once a row exists; creating that first row
    is a manual database step, documented here rather than silently
    assumed.
  - ~~`promotions_admin_write` is still a direct, unaudited RLS write
    path~~ — **closed in Phase 12**, see the "Admin dashboard: promotions"
    bullet below. Left crossed out here rather than deleted since this
    Phase 11 paragraph is what first flagged it.
  - **No admin-side analytics/reporting** (spec section 29 also describes
    platform-wide metrics — GMV, active listings, dispute rate, etc.) —
    this phase is action queues only (approve/reject/suspend/process/
    resolve), not a dashboard of numbers.
  - **The moderation queue has no pagination** — `getPendingAssets`
    fetches every `pending_review`/`published` asset in one query, fine
    at this catalog's size, a follow-up once it isn't (same caveat
    `AssetRepository.search` already documents for its own non-keyset
    sorts).
- **Reviews are one-shot.** A review can be left once per booking per
  reviewer (`reviews_booking_id_reviewer_id_key`) and never edited or
  deleted — there's no "edit my review" flow this phase.
- **A condition report, once submitted, can't be edited or re-submitted**
  — `condition_reports_booking_stage_unique` allows exactly one row per
  booking per stage. If a submitted report was wrong, the honest path
  right now is a dispute, not a correction flow (that would need its own
  design — an editable "official" record undercuts the point of a
  condition report).
- **AI listing assistant: mock only, and deliberately does very little.**
  Same story as DAN and payments — no vision-capable API key was
  available. Unlike those two, the mock branch here doesn't even attempt
  to simulate what a real answer would contain (DAN's mock does verify
  you; the payment mock does complete a payment) — it can't fabricate a
  title, category, brand, or condition from a photo it never looked at
  without that being an outright false claim, so it only ever offers
  structure (a template, a list of field *names*), not content. Once a
  real vision provider is wired in, `suggest-listing-from-photo`'s
  `AI_LISTING_MODE=production` branch and the `TODO(production)` inside
  it are the only things that need to change — see that function's
  header comment.
- **Notifications are in-app only — no push delivery.** There's no FCM
  wiring yet (see the Firebase bullet below), so a notification only
  shows up if you're already in the app watching the bell badge or the
  notifications screen; nothing arrives while the app is closed or
  backgrounded. The DB/trigger side is push-ready (`event_type`,
  `deep_link`) — adding FCM later is a delivery-layer addition, not a
  schema change.
- **Chat is text-only this phase.** `MessageKind` already models
  `image`/`system`/`bookingReference`/`assetReference`, but the composer
  only sends `text` — image messages need the same Storage upload
  wiring asset photos use, deferred rather than duplicated ad hoc here.
- **No unified conversation inbox.** Chat is reached only from a specific
  booking's detail screen ("Мессеж бичих"); there's no single "all my
  conversations" screen listing every thread across bookings.
- Asset create form: photos go in resized (`imageQuality: 80, maxWidth:
  1600`) but not cropped — `image_cropper` is declared in `pubspec.yaml`
  but not wired up, since its native full-screen crop UI is a bigger
  surface to get right without a live Flutter SDK to actually run it
  against. Uploading each photo to Storage is also not atomic with the
  asset/`asset_images` row inserts (Supabase's Flutter client has no
  portable multi-table+Storage transaction) — an asset never fails to
  exist just because one photo upload failed, but a failed upload is
  currently silent rather than surfaced back to the user. Specifications
  are a bare key/value list editor, not the smarter per-category
  suggested-fields UI the spec's AI assistant section implies.
- **As of Phase 11, the asset publish flow has a moderation step** — see
  the "Admin dashboard" bullet above and the "Asset create form" bullet
  under "What's implemented".
- Booking (spec sections 17, 18): pick a date range on the booking
  request screen, see a client-side price estimate, submit → the
  `create_booking` Postgres RPC recomputes the real price server-side
  and creates the booking (see `supabase/migrations/0006_booking_rpc.sql`
  — and its header comment for *why* this is an RPC and not a plain
  table insert: the Phase 0/1 RLS policies that let a client insert/update
  `bookings` directly were a flagged stopgap, now closed). Booking detail
  shows the authoritative stored price breakdown, dates, counterparty,
  and status, with role-appropriate actions — the owner can confirm/reject
  a pending booking, either side can cancel a pending/confirmed one — each
  action calling its own RPC (`confirm_booking`/`reject_booking`/
  `cancel_booking`) rather than writing to `bookings` directly.
  "Миний захиалгууд" lists both roles (renting / hosting) in separate
  tabs, reachable from Profile.
  - **Daily pricing only this phase** — an asset with only
    `price_per_hour`/`price_per_week` set shows a clear "can't be booked
    yet" state instead of a broken form; hourly/weekly booking math is a
    follow-up once there's UI for picking something other than a date
    range.
  - The date-range picker is Flutter's stock `showDateRangePicker` with a
    client-side pre-check against `public.asset_booked_ranges` (grays out
    nothing visually — it validates *after* a range is picked and shows an
    error if it collides) rather than a custom calendar that highlights
    blocked days directly; a real calendar widget is a reasonable
    follow-up once this flow has real usage.
  - No payment is collected at booking-request time — a booking is
    created in `pending` status and nothing charges anyone. Payment
    happens once the owner confirms; see the "Mock payment collection"
    bullet above and the Payments notes below.
  - Delivery fee is always 0 (no per-asset delivery pricing exists in the
    schema yet, only the `delivery_available` boolean). **As of Phase 11**,
    the platform commission is no longer hardcoded — `create_booking` now
    reads it from the new `platform_settings` table (default still 10%,
    now admin-editable via the commission settings screen).
  - **Pending-booking auto-expiry now exists** (`0019`/`0020` — see
    "Follow-up pass" above): `expire_stale_pending_bookings()` cancels any
    `pending` booking older than 48 hours, scheduled hourly via
    `pg_cron`. The TTL is still hardcoded (not yet in `platform_settings`
    the way commission is) — a reasonable future follow-up, not a gap in
    correctness.
- Payments (spec sections 19, 34, 51) — **superseded, updated for the
  wallet-based flow (0017/0018)**: the paragraph below used to describe
  a mock card/QPay-style gateway (`initiate-payment` +
  `mock-complete-payment`); that flow is gone. Booking payments are now
  wallet-balance-based end to end — see "Wallet" above and
  `pay_booking_from_wallet` in
  `supabase/migrations/0017_wire_topup_and_wallet_payments.sql`.
  - **No real card/QPay-style gateway is integrated for booking
    payments, and there no longer needs to be one for the MVP** — a
    renter pays out of their own wallet balance (topped up via wire.mn,
    see "Wallet" above), which settles synchronously with no external
    redirect or webhook wait. `initiate-payment`/`mock-complete-payment`
    (the original mock gateway) are still present as source files for
    history only and are **permanently disabled** — see the "Security &
    consistency hardening pass" section above for why. A future direct-
    card/QPay-at-booking-time flow, if the product ever wants one *in
    addition to* wallet balance, needs a new implementation built from
    scratch (real session/intent creation + signature-verified webhook),
    not a revival of the old pair.
  - **Currency is hardcoded to `MNT`.** `bookings` has no `currency`
    column of its own (only `assets.currency` does) —
    `pay_booking_from_wallet` hardcodes `MNT`, consistent with `assets`'
    own default. Worth revisiting once/if the catalog needs
    multi-currency listings.
  - **Payment happens after confirmation, not at request time** — a
    deliberate scoping choice so Phase 4's booking-request flow didn't
    need to change: the owner accepts first, then the renter pays to
    lock it in, rather than paying upfront on a request that might get
    rejected.
  - `payments`/`payment_events` have **zero client-facing RLS write
    policies** (see `supabase/migrations/0002_rls_policies.sql`) — every
    mutation goes through `security definer` RPCs
    (`pay_booking_from_wallet`, `admin_refund_booking_payment`) or, for
    the wallet top-up side, Edge Functions using a service-role client.
    The Flutter repository only ever reads `payments` directly (allowed
    by `payments_select_participant`), and calls the RPC/functions for
    anything that writes.
  - **Refunds now exist**, added in the post-wallet-integration hardening
    pass: `admin_refund_booking_payment` (0018) reverses a paid booking's
    payment — claws back the owner's share and returns the renter's full
    payment — as an explicit admin action from the dispute queue screen
    ("Refund renter"), not automatic on every dispute resolution (plenty
    of disputes resolve in the owner's favor). No partial refunds yet —
    it's all-or-nothing per booking. Wallet crediting on a successful
    payment is wired (`credit_wallet_for_payment`, called from
    `pay_booking_from_wallet`), and as of Phase 9 the credited amount is
    also automatically released from `pending_balance` to
    `available_balance` once the booking's return is confirmed by both
    parties — see "Wallet" and "Pickup/return condition reports, reviews,
    and disputes" above.
  - **Reconciliation for a `wallet_topups` row left orphaned** between
    wire.mn's two API calls, or for a pending topup whose webhook never
    arrives, **now exists** as the `reconcile-wire-topups` Edge Function
    (see "Follow-up pass" above) — but it still isn't wired to run on any
    automatic schedule out of the box, only on-demand from the admin
    dashboard. To make it automatic, either set up its own schedule via
    Supabase Dashboard → Edge Functions → this function → Cron, or point
    an external scheduler at it with the service-role key. Until one of
    those is set up, a stuck row only gets reconciled when an admin
    remembers to tap "Wire дахин шалгах".

## Before you trust this code — checklist

1. `flutter create . --platforms=android,ios` (or just `android`/`ios`
   individually) to generate the missing platform folders against your
   installed Flutter SDK, then add the location permission entries
   mentioned above (`ACCESS_COARSE_LOCATION` / `NSLocationWhenInUseUsageDescription`)
   if you want Home's Nearby section or Search's Map view to show your
   own location. For Search's Map view specifically, also add a real
   Google Maps API key to `AndroidManifest.xml`'s
   `com.google.android.geo.API_KEY` meta-data entry and to
   `AppDelegate.swift`'s `GMSServices.provideAPIKey(...)` call — without
   one the map renders blank.
2. `flutter pub get`
3. `flutter pub run build_runner build --delete-conflicting-outputs`
4. `flutter analyze` — fix whatever your SDK version's analyzer flags,
   since this was written without a live analyzer in the loop.
5. `flutter test`
6. Create a real Supabase project, run `supabase db push` against
   `supabase/migrations/`, fill in `env/development.json` (and
   `env/staging.json`/`env/production.json` once those environments
   exist) with the real URL/anon key.

### Before an actual store release (beyond the checklist above)

None of this is done in this repository — these are the concrete steps
still needed once the code above actually passes analyze/test on a real
machine, kept here rather than implied:

1. Grant yourself (or whoever will administer the platform) an admin row:
   `insert into admin_users (user_id, role) values ('<your-user-id>',
   'super_admin');` — there is no in-app flow for this (see "Security"
   above), it's a one-time manual step per admin.
2. ~~Set Storage bucket-level file size/MIME type restrictions via the
   Supabase dashboard or CLI config~~ — **done in this repo now**, see
   `0021_storage_bucket_restrictions.sql` (8 MiB / image-only allowlist
   on all three buckets). Nothing left to do here unless those specific
   limits need to change for your deployment.
3. App icons + splash screen: this repo ships no launcher icon/splash
   assets or generator config (`flutter_launcher_icons`/
   `flutter_native_splash` aren't declared in `pubspec.yaml`) — add real
   brand assets and wire one of those tools once design assets exist,
   rather than shipping the Flutter default icon.
4. Android signing (`key.properties` + upload keystore) and iOS signing
   (Apple Developer account, provisioning profiles) — `.github/workflows/ci.yml`'s
   `build-android`/`build-ios` jobs deliberately only build **debug**,
   unsigned artifacts; wiring `flutter build appbundle --release` /
   `flutter build ipa` needs real signing secrets added to the CI
   environment first.
5. Firebase project + `flutterfire configure` (Crashlytics/Analytics/FCM
   — see the Firebase bullet under "Known issues") and Google/Apple
   native sign-in platform registration (SHA-1 fingerprint, URL scheme —
   see the sign-in bullet under "Known issues").
6. Store listing content (screenshots, privacy policy URL, data-safety
   declarations) — genuinely out of scope for this repository to
   generate; Google Play/App Store both require this to be reviewed and
   hosted by the actual publisher, not shipped as boilerplate text in a
   code scaffold.
7. Swap every mock integration this README documents for a real one once
   credentials exist — DAN (`dan-verify`), payments
   (`initiate-payment`/`mock-complete-payment`), and the AI listing
   assistant (`suggest-listing-from-photo`) — each function's own header
   comment marks exactly what changes and what doesn't.

## Roadmap (spec section 49)

**All 12 phases of the original build plan are done as of this commit.**
Phase 0-11 built every feature area the spec calls out by phase number;
Phase 12 (security/performance/testing/release) closed the last
unaudited admin-write path (`promotions_admin_write` → the new
promotions admin queue), added real full-text search, filled a missing
index, and turned the accumulated "known issues" list into the
release-readiness checklist above rather than leaving it implicit.

What's left is exactly what "Known issues / not yet done" above and
"Before an actual store release" just above describe — none of it has a
phase number of its own in the original 12-phase plan, because none of
it can be finished inside this sandbox: FCM push delivery, a unified
conversation inbox, an admin-invite flow, admin analytics/reporting,
native Google/Apple sign-in, PostGIS, and — the largest category — every
mock-only integration (DAN, payments, AI listing assistant) swapping to
production once real credentials exist. This document, not a phase
counter, is the actual source of truth for what's done versus what a
team picking this up next still needs to do.
