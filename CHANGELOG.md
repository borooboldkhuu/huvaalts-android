# Changelog

All notable changes to ХУВААЛЦ are recorded here, one entry per build
phase. See `README.md` for the full "what's implemented" / "known
issues" detail behind each line — this file is a chronological index
into that, not a replacement for it.

Versioning note: `0.12.x` reflects "all 12 phases of the original build
plan are done," not production readiness — DAN, payments, and the AI
listing assistant are all still mock-only integrations (see README
"Known issues"), so this project deliberately stays on a `0.x` version
rather than claiming a `1.0.0` maturity it hasn't earned yet. The patch
digit (`0.12.1`, `0.12.2`, `0.12.3`) marks a fix/product-change pass over
the same 12 phases, not a 13th phase.

## 0.12.6 — same migration, a second real `db push` bug

Reordering (0.12.5) got `db push` past the "column still referenced by
a view" error and into the `create or replace view public.asset_cards`
statement itself, which then failed on its own:

```
ERROR: cannot drop columns from view (SQLSTATE 42P16)
```

`create or replace view` can only *add* columns or retype existing
ones in place — it can never remove one, and `deposit_amount` is gone
from the column list entirely in the 0015 redefinition. The fix has to
drop the view and recreate it, not `or replace` it. Added
`drop view if exists public.asset_cards;` / `... booking_cards;` right
before each view's `create or replace` — checked first that no other
view or function selects from either one, and neither has an
object-level `grant` anywhere in the migration history (both rely on
Supabase's default schema-level `authenticated`/`anon` grants), so
dropping first loses nothing that needs restoring after.

Same exception as 0.12.5, same reasoning: `0015` still hasn't
successfully applied anywhere, so this is still pre-first-deploy, not
an edit to something already live.

- `supabase/migrations/0015_remove_deposit.sql`.

## 0.12.5 — first real `supabase db push` fixes a migration ordering bug

The developer ran `supabase db push` against a real, fresh Supabase
project for the first time this project has ever existed — every prior
"the schema is correct" claim rested on hand-review, never a live
Postgres instance. It got exactly one statement into
`0015_remove_deposit.sql` before failing:

```
ERROR: cannot drop column deposit_amount of table bookings because
other objects depend on it (SQLSTATE 2BP01)
view booking_cards depends on column deposit_amount of table bookings
```

`0015_remove_deposit.sql` dropped `bookings.deposit_amount` /
`assets.deposit_amount` *before* redefining the `booking_cards` /
`asset_cards` views that still selected those columns — Postgres won't
drop a column a view still references. Fixed by reordering the file:
both views now get `create or replace`d (already written, in this same
file, to select everything *except* `deposit_amount`) before either
column drop runs. Nothing about *what* changes — same columns dropped,
same views end up in the same final shape — only the order.

This is the one deliberate exception to "never edit an already-shipped
migration" in this project: `0015` had never once been successfully
applied to any real database anywhere (this `db push` was the first
attempt, and it failed on this exact statement), so there was no
already-deployed environment whose migration history the edit could
contradict — the rule exists to protect that case, and it doesn't
apply here. Once `db push` succeeds and the migration is actually
live somewhere, this exception is retired: any further fix becomes a
new `0016_*.sql`, no exceptions.

- `supabase/migrations/0015_remove_deposit.sql` (reordered, not
  behaviorally changed).

## 0.12.4 — Riverpod 3 / freezed 3 / dependency-major-upgrade fix pass

Not a new phase — a real `flutter analyze` was run for the first time
against this project (on the developer's machine, once `flutter create`
had generated the missing `android`/`ios` scaffolding — see README
"Known issues") after `flutter pub upgrade --major-versions` bumped
`flutter_riverpod` 2→3, `riverpod_annotation`/`riverpod_generator` 2→4,
`freezed`/`freezed_annotation` 2→3, `go_router` 14→17, `flutter_secure_storage`
9→11, and `firebase_*`/`geolocator`/`intl` by a major version each. It
reported 417 issues; this pass fixes every one that was a real compile
error (blocking issues only — the remaining ~35 info/lint-level items,
e.g. deprecated `withOpacity`, `value:` on form fields, unused imports,
are cosmetic and deferred):

- **freezed 3.x**: every `@freezed` entity's `class X with _$X` became
  `abstract class X with _$X` — freezed 3.0 requires the annotated class
  to be `abstract` (or `sealed` for union types, not used here). 22 files.
- **Riverpod 3.x**: `riverpod`'s public API no longer exposes
  `FutureProviderFamily`/`AutoDisposeFutureProviderFamily`/
  `AutoDisposeStreamProviderFamily` as explicit type-annotation classes,
  so every `final FutureProviderFamily<T, Arg> x = FutureProvider.family<T, Arg>(...)`
  style declaration dropped its now-invalid left-hand type and lets Dart
  infer it instead. 12 provider files, 19 declarations.
- **`AsyncValue.valueOrNull` → `.value`**: Riverpod 3's `AsyncValue.value`
  is itself now nullable and already returns the last-known value across
  loading/error states (what `valueOrNull` used to do) — `valueOrNull` no
  longer exists. 7 call sites, including `AssetMapView` from 0.12.3.
- **Flutter SDK**: `ThemeData.cardTheme` now takes `CardThemeData`, not
  the deprecated-for-that-use `CardTheme` constructor
  (`app/theme/app_theme.dart`).
- **dio**: `DioExceptionType` gained a `transformTimeout` value; added to
  `DioClient._mapDioException`'s exhaustive switch alongside the other
  timeout variants (`core/network/dio_client.dart`).
- **flutter_secure_storage 11.x**: `AndroidOptions.encryptedSharedPreferences`
  was removed (the Jetpack Crypto it wrapped was deprecated upstream) —
  encryption is no longer optional, so the option is just gone, not
  renamed (`core/storage/secure_storage_service.dart`).
- **supabase_flutter**: `Supabase.initialize`'s `anonKey` parameter is
  deprecated in favor of `publishableKey` (same value, renamed key
  concept) (`bootstrap.dart`).
- **`postgrest` strict inference**: every `.rpc(...)` call now passes an
  explicit `<dynamic>` type argument — `flutter_lints: ^6.0.0`'s stricter
  inference rule flags the implicit-`dynamic` return type `rpc<T>`
  resolves to otherwise. 13 call sites across 4 repositories.
- **`verification_screen.dart`**: `_FailedView._messageFor` called
  `failurePresentation` (defined in `shared/widgets/error_state.dart`)
  without importing that file — a genuine pre-existing missing-import
  bug, unrelated to the dependency upgrade, just never caught until this
  analyze run.
- **`test/widget_test.dart`**: `flutter create .`'s default template
  (`MyApp` counter-app smoke test) doesn't match this project's actual
  root widget (`HuvaaltsApp`, in `lib/bootstrap.dart`) and never
  compiled. Replaced with a real smoke test scoped to `AppTheme` — the
  one app-wide piece safe to pump without first booting Supabase/env,
  consistent with how every screen-level test in this suite already
  avoids booting the full app shell.

The developer re-ran `flutter analyze` after this: 417 → 76 issues,
all real compile errors gone. Two genuine bugs turned up in that
second pass, both fixed the same way (real error, not a version-bump
casualty):

- **`review_screen.dart`**: called `booking.isOwner(...)`, an
  extension method (`BookingViewHelpers`, in `booking.dart`) reached
  only through a transitive import (`booking_providers.dart`) —
  extension methods aren't visible that way in Dart, only through a
  direct import of their declaring library. Added the direct import.
- **`rental_lifecycle_section.dart`**: `dispute == null ? ... :
  disputeStatusLabel(dispute.status, ...)` — `dispute` is a public
  widget field, and Dart's null-check flow promotion from `dispute ==
  null` doesn't apply to fields the way it does to local variables, so
  the `:` branch still saw `dispute` as nullable. Captured it into a
  local variable first so the promotion applies.

Plus three real (not cosmetic) warnings in `supabase_admin_repository.dart`
(`approveAsset`/`rejectAsset`/`suspendAsset`): each did
`return _reloadAssetSummary(assetId);` *without* `await` inside a
`try` block whose `catch` only handles `PostgrestException` — since
the return left the `try` block before `_reloadAssetSummary`'s future
actually resolved, a `PostgrestException` thrown while re-fetching
would have skipped the `catch` entirely and reached the caller
unmapped. Added the missing `await`.

Also removed two now-unused imports flagged as warnings
(`payment_section.dart`'s `currency_formatter.dart`,
`language_settings_screen_test.dart`'s `local_cache_service.dart`).

What's left after this pass is 0 errors, 0 real-bug warnings — just
~65 cosmetic `info`-level lints (`withOpacity` → `.withValues()`,
`value:` → `initialValue:` on form fields, `onReorder` →
`onReorderItem`, `unnecessary_underscores`, `prefer_const_constructors`,
a couple of `use_build_context_synchronously`/`close_sinks` hints).
Deliberately deferred — none of them are wrong code, just not the
newest idiom — batch-fixable in a follow-up pass whenever wanted.

None of this touched product behavior beyond the three real bugs
above — every other change is a mechanical adaptation to a new
major-version API surface. Verified by re-checking brace/paren balance
across every edited file; **not yet re-verified by a third
`flutter analyze` run** confirming the 76 → ~65 delta, since this
environment has no Flutter SDK.

## 0.12.3 — Search Map view (spec section 13)

Adds the map/list hybrid browsing spec section 12 always deferred: a map
toggle in Search's AppBar (`Icons.map_outlined`) swaps the results grid
for `AssetMapView`, which plots a pin per asset in the already-loaded
result page (same filters/state as the list — no separate fetch) and
shows the device's own live position via `GoogleMap.myLocationEnabled`
(the native Maps SDK's own continuously-updating dot, not a custom
tracking pipeline — asset pins are static since location is fixed at
listing time). Tapping a pin opens a bottom preview card (image, title,
price) that pushes to the asset's detail screen.

**Same "code exists, platform doesn't yet" gap as Home's Nearby
section** — see README "Known issues" for the full list (no
`android`/`ios` projects, no real Google Maps API key, no location
permission entries). This is honest scaffolding, not a working map on a
real device yet.

- `lib/features/map/presentation/widgets/asset_map_view.dart` (new).
- `lib/features/search/presentation/screens/search_screen.dart` (map/list
  toggle).
- 4 new l10n keys (`searchShowMapAction`, `searchShowListAction`,
  `mapNoLocatedAssets`, `mapMyLocationUnavailable`).

## 0.12.2 — remove the deposit/collateral concept

Product decision, not a phase: ХУВААЛЦ no longer asks owners to set a
security deposit or renters to pay one. Removed end to end — schema
(`assets.deposit_amount`, `bookings.deposit_amount`, the
`bookings_total_matches_sum` check, `'deposit'` as a `booking_items.kind`),
the `asset_cards`/`booking_cards` views and `create_booking` RPC,
every Dart entity/repository/screen that surfaced it (asset create
form, asset detail, booking request/detail price breakdowns,
`AssetSearchFilters.maxDeposit`), and the corresponding tests. The demo
mockups and pitch deck (`03_asset_detail`, `04_checkout` screens; the
"transparent pricing" bullet on the product-tour slide) were updated to
match — booking totals recompute without the deposit line.

`wallet_transaction_type`'s `'deposit_release'` Postgres enum value is
deliberately left in place (see `supabase/README.md`'s entry on
`0015_remove_deposit.sql` for why); the Dart-side `depositRelease` case
is gone since it had no real producer.

- `supabase/migrations/0015_remove_deposit.sql`.

## 0.12.1 — bug-fix pass (post-Phase-12 full-codebase review)

Not a new phase — every migration and every Dart file was re-read
specifically hunting for defects. Eleven concrete bugs found and fixed;
see README's "Bug-fix pass" section for the full list with reasoning.
Highlights: `cancel_booking` could cancel an already-paid booking with
no refund path; `credit_wallet_for_payment`'s idempotency check had a
race window; `reviews_insert_participant` didn't validate `reviewee_id`
was the actual counterparty; `assets_update_own` didn't restrict
`is_featured`; `confirm_condition_report` could permanently strand a
booking if a dispute landed mid-pickup-confirmation; two chat/
notification `StreamProvider`s leaked their Supabase Realtime channel
for the app's whole process lifetime (missing `autoDispose`); a
timezone bug in `AppDateUtils.formatShortDate`.

- `supabase/migrations/0014_bug_fixes.sql`.

## 0.12.0 — Phase 12: security / performance / testing / release

- Closed the last unaudited direct-RLS admin-write path
  (`promotions_admin_write`) with audited `admin_upsert_promotion`/
  `admin_deactivate_promotion` RPCs and a new promotions admin queue.
- Real full-text asset search (generated `tsvector` + GIN index,
  `.textSearch(..., config: 'simple', type: TextSearchType.websearch)`),
  replacing a `title`-only `ILIKE '%query%'`.
- Added a missing `payouts_status_idx` (the admin payout queue filters on
  `status`; only `user_id` was indexed before).
- Added a "Security" section to `README.md` — a written audit summary of
  RLS/audit-logging posture, and a "Before an actual store release"
  checklist covering signing, icons, Firebase, store listings, and admin
  bootstrapping, none of which existed as an explicit checklist before.
- `supabase/migrations/0013_security_perf_hardening.sql`.

## 0.11.0 — Phase 11: admin dashboard

- Asset moderation (`admin_approve_asset`/`admin_reject_asset`/
  `admin_suspend_asset`/`resubmit_asset_for_review`), closing Phase 3's
  "no moderation queue" gap and a previously-undocumented RLS gap
  (`assets_update_own` let an owner set `status` directly) via a new
  `enforce_asset_status_transition` trigger.
- Commission settings (`platform_settings` +
  `admin_update_commission_percent`), replacing `create_booking`'s
  hardcoded 10%.
- Payout processing (`admin_process_payout`), closing Phase 7's
  request-only gap.
- Dispute resolution (`admin_resolve_dispute`), dropping
  `disputes_update_admin`'s unaudited direct-write policy.
- Report resolution (`admin_resolve_report`) — the first admin action
  ever wired to `public.reports`.
- New `lib/features/admin/` Flutter feature: five queues, gated behind
  `isAdminProvider` (UX convenience only — every RPC re-checks
  `is_admin` server-side).
- `supabase/migrations/0012_admin_dashboard.sql`.

## 0.10.0 — Phase 10: AI listing assistant (mock)

- `suggest-listing-from-photo` Edge Function, gated by `AI_LISTING_MODE`
  (mock only — no vision-capable API key was available). The mock branch
  offers structure (description template, neutral condition default,
  spec field names) and never fabricates content from a photo it never
  decoded.
- Rate-limited (`ai_listing_suggestions`, 30 calls/24h).
- New `lib/features/ai/` feature, wired into the asset create form.

## 0.9.0 — Phase 9: condition reports, reviews, disputes

- Pickup/return condition reports that move a booking through
  `active`/`completed` and release Phase 7's wallet credits from
  `pending_balance` to `available_balance`.
- Reviews (overall + three category ratings), keeping
  `profiles.rating`/`review_count` in sync via trigger.
- Dispute lifecycle (raise → `disputed` → resolved/rejected, restoring
  the booking's prior status).
- `supabase/migrations/0010_condition_reports_reviews_disputes.sql`.

## 0.8.0 — Phase 8: chat & notifications

- Per-booking chat over Supabase Realtime
  (`get_or_create_conversation_for_booking`, `flag_suspicious_message`
  heuristic).
- In-app notification center (`notify_new_message`,
  `notify_booking_status_change`), fully localized client-side copy.
- `supabase/migrations/0009_chat_notifications.sql`.

## 0.7.0 — Phase 7: wallet

- `credit_wallet_for_payment` credits an owner's `pending_balance` once a
  payment clears.
- "Хэтэвч" balance/transaction history screen, payout requests
  (`validate_payout_request` trigger guards the amount server-side).
- `supabase/migrations/0008_wallet_credit_rpc.sql`.

## 0.6.0 — Phase 6: DAN production adapter

- `EdgeFunctionDanAuthAdapter` + `dan-verify` Edge Function (mock-only,
  no official DAN credentials available), reachable from a new
  "Get verified" flow (`VerificationScreen`).
- Closed a payments backend gap: `initiate-payment` now checks
  `PAYMENT_PROVIDER_MODE` the same way `mock-complete-payment` already
  did.

## 0.5.0 — Phase 5: mock payment collection

- `initiate-payment` + `mock-complete-payment` Edge Functions — the only
  write path for `public.payments` (zero client-facing RLS write
  policies on that table).
- Loudly-labeled mock checkout sheet on a confirmed booking's detail
  screen.

## 0.4.0 — Phase 4: booking

- `create_booking`/`confirm_booking`/`reject_booking`/`cancel_booking`
  RPCs, replacing Phase 0/1's flagged-as-stopgap direct-insert/update RLS
  policies. Server-side price recomputation, `bookings_no_overlap`
  exclusion constraint.
- Booking request/detail screens, "Миний захиалгууд".
- `supabase/migrations/0006_booking_rpc.sql`,
  `0007_asset_booked_ranges.sql`.

## 0.3.0 — Phase 3: asset create & detail

- Asset create form (photos, pricing, specs, rules), full asset detail
  screen, "Миний хөрөнгө".

## 0.2.0 — Phase 2: home, categories, search

- Seven Home discovery sections, category browsing, debounced search
  with filter/sort bottom sheet, favoriting.
- `supabase/migrations/0003_seed_categories.sql`,
  `0004_asset_cards_view.sql`.

## 0.1.0 — Phase 0 + 1: architecture & auth

- Design tokens, `GoRouter`, `AppException`/`Failure` error handling,
  hand-written `AppLocalizations` (mn/en).
- Phone OTP auth, onboarding, profile.
- Full initial Postgres schema + RLS for every table in the spec
  (`0001_init_schema.sql`, `0002_rls_policies.sql`).
