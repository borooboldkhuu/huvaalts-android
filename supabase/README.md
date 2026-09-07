# Supabase backend

## Migrations

Apply in order with the Supabase CLI:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

- `0001_init_schema.sql` — full schema for every table listed in the product
  spec (users, profiles, assets, bookings, payments, wallet, chat,
  disputes, admin, audit log, etc.), UUID PKs, FKs, timestamps, and the
  business-rule constraints the client must never be trusted to enforce
  alone: booking date-range overlap prevention (`bookings_no_overlap`,
  a Postgres exclusion constraint — this is the "database-level validation"
  spec section 17 requires), price/commission math consistency checks,
  rating bounds, etc.
- `0002_rls_policies.sql` — Row Level Security for every table (spec
  section 32). Notably: `payments`, `wallets`, `wallet_transactions`,
  `admin_users`, and `audit_logs` have **no client insert/update policy at
  all** — those tables are only ever written by Edge Functions using the
  service-role key, after server-side verification (payment webhook
  signature, admin role check, etc.). That's intentional, not an
  oversight: it's how "never trust the client for price/payment
  status/wallet balance" (spec section 34) is enforced at the database
  layer, not just in app code.
- `0003_seed_categories.sql` — the fixed category list from spec section 11.
- `0004_asset_cards_view.sql` — `public.asset_cards`, a read-optimized view
  joining `assets` + owner `profiles` + primary `asset_images` row +
  aggregate rating, used by every browse/search query (Home sections,
  Search results, asset detail placeholder). Uses `security_invoker = true`
  so it enforces RLS as the querying user rather than the view owner —
  it's a projection over already-protected tables, not a bypass.
- `0005_storage_buckets.sql` — `asset-images` (public read, owner-only
  write) and `condition-reports` (private, booking-participant write)
  Storage buckets. Bucket-level file size/MIME type restrictions (spec
  section 34) aren't expressible in portable SQL — set those via the
  Supabase dashboard/CLI config once a real project exists.
- `0006_booking_rpc.sql` (Phase 4) — the booking creation and
  status-transition RPCs: `create_booking`, `confirm_booking`,
  `reject_booking`, `cancel_booking`. **Drops** `bookings_insert_renter`
  and `bookings_update_participant` from `0002` — those two policies
  shipped in Phase 0/1 as a deliberately-flagged stopgap (their own
  comments said "created via a backend RPC ... in production") that let
  an authenticated client insert a booking with a self-declared price, or
  PATCH any column on a booking they're party to including `status` and
  the amount fields. This migration is that promised RPC layer: every
  booking mutation from the client now goes through a `SECURITY DEFINER`
  function that recomputes price from the asset's *current*
  `price_per_day` server-side, re-checks `asset_availability` blackout
  ranges, and validates status transitions against who's calling and what
  state the booking is actually in — a raw client insert/update can no
  longer create or alter a booking at all. Also adds `public.booking_cards`,
  a `security_invoker` read-optimized view for booking list/detail
  screens, the same pattern as `asset_cards`.
- `0007_asset_booked_ranges.sql` (Phase 4) — `public.asset_booked_ranges`,
  a *non*-`security_invoker` view exposing just `asset_id` +
  `start_date`/`end_date` for a published asset's active bookings and
  owner blackout ranges, with no participant identity or amounts. Backs
  the booking request screen's "which dates are already taken" calendar
  pre-check. Deliberately not `security_invoker` — see the file's header
  comment for why a security_invoker view can't do this job (it would
  inherit `bookings_select_participant` and only ever show the querying
  user their *own* bookings, not the other renters' blocked dates a
  calendar actually needs to gray out).
- `0008_wallet_credit_rpc.sql` (Phase 7) — two pieces, both guarding
  money-relevant state exactly like `0006`'s booking RPCs do:
  `credit_wallet_for_payment(p_payment_id)`, a `service_role`-only
  function (no grant to `authenticated` at all — stricter than the
  booking RPCs, since nothing about how much money a booking generated
  should ever be client-triggered) that credits the booking owner's
  `wallets.pending_balance`/`total_earned` and logs a
  `wallet_transactions` row once `mock-complete-payment` calls it after a
  payment clears; and a `validate_payout_request` trigger on
  `public.payouts` that rejects a payout insert whose amount exceeds what
  the requesting user's wallet actually has available (net of their own
  other pending/processing requests), since `payouts_insert_own` (from
  `0002`) lets the client insert its own payout requests directly and
  nothing was otherwise stopping a self-reported amount from being
  nonsense. See the migration's header comment for why credited funds
  land in `pending_balance` and stay there this phase — there's no
  booking-completion flow yet to release them.
- `0009_chat_notifications.sql` (Phase 8) — three pieces:
  a `conversations_booking_id_unique` constraint plus
  `get_or_create_conversation_for_booking(p_booking_id)`, a
  `SECURITY DEFINER` RPC (the only way `conversations`/
  `conversation_members` rows get created — neither table has a client
  insert policy) that's idempotent and race-safe: concurrent first-opens
  from both participants catch each other's `unique_violation` and both
  resolve to the same conversation row instead of erroring or
  duplicating; a `BEFORE INSERT` trigger on `messages`
  (`flag_suspicious_message`) that always overwrites the client-supplied
  `flagged_for_review` with a server-computed regex heuristic (long
  digit runs shaped like a phone number, or off-platform-payment
  keywords like "вотсап"/"шилжүүлэг"/"iban") — messages still send either
  way, this only adds a visible in-chat notice, and it's documented as a
  heuristic rather than real moderation; and two `AFTER INSERT`/
  `AFTER INSERT OR UPDATE` trigger functions, `notify_new_message` (on
  `messages`) and `notify_booking_status_change` (on `bookings`), that
  are the *only* way rows land in `notifications` from booking/message
  activity, since that table also has no client insert policy at all.
  `notify_booking_status_change` reads `auth.uid()` to infer which
  participant is the actor vs. the recipient — confirmed this still
  resolves correctly for updates coming from inside the existing
  `SECURITY DEFINER` `confirm_booking`/`reject_booking`/`cancel_booking`
  RPCs (0006), since PostgREST's `request.jwt.claims` session setting is
  unaffected by a function's own privilege elevation. Both trigger
  functions write a stable `event_type` plus a plain-English
  `title`/`body` fallback; the Flutter client renders fully localized
  copy keyed off `event_type` and only falls back to those DB columns
  for event types it doesn't recognize yet.
- `0010_condition_reports_reviews_disputes.sql` (Phase 9) — closes the
  three gaps every earlier phase's own comments flagged and deferred:
  nothing ever set `bookings.status` to `active`/`completed`, nothing
  ever released Phase 7's `pending_balance` credits, and
  `reviews_insert_participant` (0002) had required `status = 'completed'`
  since Phase 0/1 without that ever being reachable. Four pieces:
  `validate_and_autoconfirm_condition_report` (`BEFORE INSERT` on
  `condition_reports`) enforces the right booking status per stage —
  `pickup` additionally requires an already-`paid` payment — and
  auto-confirms the submitter's own side; `confirm_condition_report(p_report_id)`
  (`SECURITY DEFINER`, `authenticated`-only) is the *only* way the other
  party's confirmation timestamp gets set, since `condition_reports` has
  no client update policy; `advance_booking_on_condition_report`
  (`AFTER INSERT OR UPDATE` on `condition_reports`) is what actually
  moves `bookings.status` once both confirmations land, and — on the
  return stage specifically — moves the owner's earned share from
  `wallets.pending_balance` to `available_balance` (via
  `bookings.payout_released_at`, guarding against a double release) and
  bumps both participants' `profiles.completed_rentals_count`; and
  `update_profile_rating_on_review` (`AFTER INSERT` on `reviews`)
  recomputes `profiles.rating`/`review_count` from every review the
  reviewee has received. Separately, disputes get an actual lifecycle:
  `validate_dispute_insert` restricts which booking statuses can be
  disputed and gives a friendly `dispute_already_open` error;
  `mark_booking_disputed` flips the booking to `disputed` (remembering
  the prior status in the new `bookings.pre_dispute_status` column) and
  notifies the other participant; `restore_booking_status_after_dispute_resolution`
  reacts to an admin's `resolved`/`rejected` update (the only way that
  happens — see "Still to build" below) by restoring that prior status
  and notifying both sides. `notify_booking_status_change` (0009) also
  gets copy added for the two statuses this migration makes reachable
  (`active`, `completed`) — `disputed` deliberately stays uncovered
  there in favor of the two dedicated `dispute_*` notifications above.
  Also adds a private `dispute-evidence` Storage bucket (same
  participant-scoped shape as `condition-reports`, plus admin read) and
  two integrity constraints that should have existed from the start:
  `wallets.available_balance`/`pending_balance` non-negative checks, and
  `condition_reports_booking_stage_unique` (one report per booking per
  stage).
- `0011_ai_listing_suggestions.sql` (Phase 10) — one table,
  `ai_listing_suggestions`, backing `suggest-listing-from-photo`'s rate
  limit (`MAX_CALLS_PER_DAY` in that function). Client-readable
  (`ai_listing_suggestions_select_own`) so a future "N requests left
  today" UI doesn't need a round trip through the function itself, but
  **no client insert/update/delete policy at all** — only the function's
  service-role client writes rows, since a client-writable rate-limit log
  would let anyone bypass the limit it exists to enforce (the same
  posture as `payments`/`notifications` having zero client write access,
  just for a different reason: those are about not trusting client state,
  this is about not trusting a client to self-report its own usage).
- `0012_admin_dashboard.sql` (Phase 11) — closes every gap earlier
  phases flagged as "waiting on Phase 11" (see "Still to build" below for
  what those pointers said before this landed), plus one this phase found
  on its own: `assets_update_own` (0002) let an owner `UPDATE` any column
  on their own asset, including `status`, with zero server-side
  restriction — nothing stopped a client from setting
  `status: 'published'` directly and skipping moderation entirely. A
  shared `log_admin_action(p_action, p_target_type, p_target_id, p_metadata)`
  helper (deliberately **not** granted to `authenticated` — only callable
  from inside another `SECURITY DEFINER` function that owns it, so a
  client can never call it directly to write a fake audit entry) backs
  every RPC below; each one checks `is_admin(auth.uid())` itself and
  calls this helper before returning, so an admin action that skips
  `audit_logs` would be a bug in this file, not something reachable by
  skipping a step. Six pieces:
  - `enforce_asset_status_transition` (`BEFORE INSERT OR UPDATE` on
    `assets`) — forces every new asset to `pending_review` regardless of
    what the client sends, and blocks every `UPDATE`-time status change
    except an admin action or the one owner self-service case (`draft →
    pending_review` via `resubmit_asset_for_review`, after a rejection).
    `asset_cards` (0004) is re-declared identically plus a new
    `moderation_note` column, so the same view now also backs the admin
    moderation queue.
  - `admin_approve_asset(p_asset_id)` (`pending_review → published`),
    `admin_reject_asset(p_asset_id, p_reason)` (`pending_review → draft`,
    storing `p_reason` in `moderation_note` — reused rather than adding a
    new enum value, so the owner can edit and resubmit instead of hitting
    a dead end), `admin_suspend_asset(p_asset_id, p_reason)`
    (`published → suspended`), and `resubmit_asset_for_review(p_asset_id)`
    (owner-only, `draft → pending_review`, clearing `moderation_note`).
  - A new single-row `platform_settings` table (`id` fixed at `1` by a
    check constraint, public read via `platform_settings_select_all`, no
    client write policy) and `admin_update_commission_percent(p_percent)`.
    `create_booking` (0006) is re-declared with the exact same signature
    and body except its commission is now read from this table
    (`coalesce`d to 10 if the row is somehow missing) instead of hardcoded.
  - `admin_process_payout(p_payout_id, p_new_status, p_destination_reference)`
    — enforces `pending → processing|failed` and `processing → paid|failed`
    (anything else, including touching an already-terminal row, is
    rejected); only on landing on `paid` does it actually deduct
    `wallets.available_balance` and log a negative `wallet_transactions`
    row (money hasn't left until it's confirmed sent, not merely "being
    processed" — deliberately not deducted at the `pending → processing`
    step).
  - `admin_resolve_dispute(p_dispute_id, p_new_status, p_resolution_notes)`
    — and this migration **drops** `disputes_update_admin`'s direct-RLS-write
    policy from 0002 entirely, since a direct write bypassed `audit_logs`
    (true in a schema comment since Phase 0, never actually enforced for
    admin table writes until now). Deliberately does nothing beyond the
    column update + audit log — `restore_booking_status_after_dispute_resolution`
    (0010) already reacts correctly to any `UPDATE` on `disputes.status`
    regardless of caller, so duplicating its booking-restore/notification
    logic here would just be a maintenance risk.
  - `admin_resolve_report(p_report_id, p_new_status)` — the first admin
    action ever wired to `public.reports`, which existed since Phase 0/1
    with only an insert-own client policy.
- `0013_security_perf_hardening.sql` (Phase 12) — a narrow hardening
  pass, not a new feature area: one security gap and two performance gaps
  found by re-reading the schema, not a speculative rewrite.
  - **Security**: drops `promotions_admin_write` (0002) — the one
    direct-RLS admin-write path Phase 11's own README flagged but left
    out of scope — and replaces it with `admin_upsert_promotion(p_id,
    p_code, p_title, p_description, p_discount_percent, p_starts_at,
    p_ends_at, p_is_active)` (one RPC for both create and update, since a
    promotion has no status-machine to enforce the way assets/disputes/
    payouts do) and `admin_deactivate_promotion(p_id)`, both logging to
    `audit_logs` like every other admin RPC since 0012. `public.promotions`
    has had zero Flutter code touching it since Phase 0 — this closes the
    admin-authoring gap only; there is still no consumer-facing "apply a
    promo code at booking" flow.
  - **Performance**: `payouts_status_idx` (the Phase 11 admin payout
    queue filters on `status`; only `user_id` was indexed before), and a
    generated `assets.search_vector tsvector` column (title +
    description + brand + model, `to_tsvector('simple', ...)` — 'simple'
    deliberately, not 'english': Postgres ships no Mongolian dictionary,
    so 'simple' tokenizes/lowercases without pretending to stem either
    language) plus a GIN index on it, replacing Search's `title`-only
    `ILIKE '%query%'` (no index can make a leading-wildcard `ILIKE`
    fast). `asset_cards` (0004, re-declared by 0012) is re-declared once
    more, identical plus this one new trailing column, so
    `SupabaseAssetRepository.search` can call `.textSearch('search_vector',
    query, config: 'simple', type: TextSearchType.websearch)` directly
    against the view.
- `0014_bug_fixes.sql` (post-Phase-12 bug-fix pass, not a new phase) —
  six concrete backend defects found by re-reading every RPC/RLS policy
  against its actual callers, each `create or replace function`/
  policy-swap, no schema/shape changes: `cancel_booking` blocking
  cancellation of an already-paid `confirmed` booking
  (`cannot_cancel_paid_booking` — no refund mechanism exists, so this
  routes it to the dispute flow instead of silently losing the money
  trail); `credit_wallet_for_payment` locking the booking row before its
  idempotency check (was previously a check-then-insert race under
  concurrent calls); `reviews_insert_participant` validating
  `reviewee_id` is actually the booking's other participant (previously
  any completed-booking participant could review anyone); extending
  `enforce_asset_status_transition` (0012) to also guard `is_featured`,
  not just `status`; a column-level `grant update (last_read_at)` on
  `conversation_members` (previously a member could self-clear their own
  `is_blocked`, replacing the blanket `authenticated` update grant);
  `confirm_condition_report` refusing to confirm while a booking is
  `disputed` (previously could permanently strand a booking at
  `confirmed` if a dispute landed mid-pickup-confirmation). See
  README.md's "Bug-fix pass" section for the five additional Dart-only
  fixes from the same review (no migration needed for those).
- `0015_remove_deposit.sql` (product decision, not a phase) — removes the
  deposit/collateral (`барьцаа хөрөнгө`) concept entirely: drops
  `assets.deposit_amount` and `bookings.deposit_amount`, rewrites
  `bookings_total_matches_sum` to `rental_amount + platform_fee +
  delivery_fee` (no deposit term), drops `'deposit'` from
  `booking_items.kind`'s allowed values, and re-declares `asset_cards`
  (0004/0012/0013), `booking_cards` (0006), and `create_booking`
  (0006/0012) each minus every deposit column/computation/insert. The
  `wallet_transaction_type` enum's `'deposit_release'` value is
  deliberately left in place — vanilla Postgres has no
  `ALTER TYPE ... DROP VALUE`, and the value was already dead (nothing
  ever inserted it), so recreating the whole enum type for an inert,
  harmless leftover wasn't worth the risk. The Dart-side mirror
  (`WalletTransactionType`) has dropped its `depositRelease` case;
  `fromId`'s `orElse` fallback (`adjustment`) means a `'deposit_release'`
  row would never have appeared client-side anyway.
- `0016_wallet_enum_values.sql` — adds `'wallet_topup'`/`'booking_payment'`
  to `wallet_transaction_type`, alone in its own migration/transaction on
  purpose (Postgres won't let a brand-new enum value be *used* in the
  same transaction that added it) so `0017` can reference both values
  immediately after.
- `0017_wire_topup_and_wallet_payments.sql` — wallet-balance-based
  booking payments end to end (`pay_booking_from_wallet`), wire.mn wallet
  top-ups (`credit_wallet_for_topup`, `wallet_topups` table), and
  self-reported surname/given-name/register-number collection for the
  registration flow. See its own header comment for the three product
  decisions it encodes.
- `0018_security_and_consistency_hardening.sql` — second full-codebase
  security/consistency pass (same spirit as `0014`, now that real money
  moves through the wallet). See README.md's "Security & consistency
  hardening pass" section for the itemized list — column-grant
  restrictions on `profiles`/`users`, the `identity_verifications`
  status restriction, cross-wallet deadlock prevention
  (`lock_wallet_pair`), `admin_refund_booking_payment`, the
  `dan-callback` race fix, `messages.body` length cap,
  `asset_images`/8-photo server-side cap, and `view_count`/
  `favorite_count` finally getting incremented.
- `0019_pending_booking_expiry.sql` — `expire_stale_pending_bookings()`:
  auto-cancels any `pending` booking older than 48 hours
  (`cancellation_reason = 'expired_no_owner_response'`), freeing its
  dates (a lingering `pending` booking counted toward
  `bookings_no_overlap` the whole time). `for update skip locked` so it
  never blocks on a booking a participant is concurrently transitioning.
  Also fixes a `notify_booking_status_change` (0009) gap where a
  system-initiated transition (no `auth.uid()`) only ever notified the
  owner, never the renter whose own booking got auto-cancelled — now
  notifies both when the actor can't be resolved.
- `0020_pending_booking_expiry_schedule.sql` — schedules 0019's function
  hourly via `pg_cron`. Kept separate from 0019 on purpose: `pg_cron`
  availability isn't guaranteed on every Postgres instance, so a failure
  here shouldn't take the (always-safe) function definition down with it.
  See the file's own header comment for the fallback if `create
  extension pg_cron` fails on your project.
- `0021_storage_bucket_restrictions.sql` — sets `file_size_limit`
  (8 MiB) and `allowed_mime_types` (image types only) on all three
  Storage buckets (`asset-images`, `condition-reports`,
  `dispute-evidence`). Corrects a claim in `0005`'s/`0010`'s own header
  comments that these "aren't expressible in a portable SQL migration" —
  an external audit (Aug 2026) correctly caught that as wrong: both are
  plain columns on `storage.buckets` that the Storage service reads
  directly, regardless of how the row got its values.

## Edge Functions

No new Edge Function this phase (Phase 11) — every admin action is a
plain `SECURITY DEFINER` Postgres RPC (`0012_admin_dashboard.sql`), not
an Edge Function, since none of them need anything an Edge Function
would give that a `SECURITY DEFINER` function doesn't already (no
outbound third-party API call, no secret only the Edge runtime should
see — the `dan-verify`/`initiate-payment`/`mock-complete-payment`/
`suggest-listing-from-photo` functions below all exist because they
either call or stand in for an external service).

- `functions/dan-verify/` — implementation of the DAN identity
  verification backend endpoint described in spec section 9, gated by
  `DAN_AUTH_MODE` (`mock` by default). A single `POST` endpoint routed by
  an `action` field in the JSON body (`'start'` | `'status'`, plus
  `session_id` for `status`) rather than by sub-path/HTTP verb — this
  matches the request shape of every other function here
  (`initiate-payment`, `mock-complete-payment`) instead of depending on
  exactly how a given client library builds sub-path URLs. Called by
  `EdgeFunctionDanAuthAdapter` (Phase 6,
  `lib/features/auth/data/services/edge_function_dan_auth_adapter.dart`)
  — the Flutter app's `MockDanAuthAdapter` is a separate, fully offline
  fake that never calls this function at all (viable because
  `identity_verifications` does allow a client insert, unlike `payments`
  below).
  **`DAN_AUTH_MODE=production` is now implemented** — real
  ХУР (Government Data Exchange, sso.gov.mn) OAuth per
  https://developer.xyp.gov.mn/web/service-list, no Flutter code changes,
  same swap story as everywhere else in this doc. `start` only builds the
  Authorization Request URL and records a `pending`
  `identity_verifications` row keyed by a freshly-minted `state` — it
  cannot get an access token or citizen data itself, because ХУР redirects
  the *citizen's browser*, not this function, once they consent. See
  `functions/dan-callback/` below for the other half. `status` in
  production mode is a pure read of whatever `dan-callback` already wrote.
  Needs three secrets beyond `DAN_AUTH_MODE=production`: `DAN_CLIENT_ID`,
  `DAN_CLIENT_SECRET` (used only by `dan-callback`), `DAN_REDIRECT_URI`
  (this project's deployed `dan-callback` URL, exactly as registered with
  ХУР). **Fail-open-into-mock fix (external audit, Aug 2026):** same
  defense-in-depth `wire-topup` already had — if `DAN_CLIENT_ID`/
  `DAN_CLIENT_SECRET` are configured but `DAN_AUTH_MODE` isn't explicitly
  `production`, both `start` and `status` refuse the mock branch instead
  of silently auto-verifying (mock `status` auto-verifies on first poll,
  which would otherwise credit `profiles.verification_level` for free on
  a deployment that shipped real DAN credentials but forgot the mode
  flag). **Also flagged, unresolved:** this OAuth2 flow's own header
  comment now carries a caveat — research triggered by the same audit
  found live documentation for a *different*, signature-based ХУР
  integration mechanism (SOAP/XML + RSA-SHA256 signature, not OAuth2) for
  the same named service this function calls; confirm the exact protocol
  against your own registered integration before flipping this to
  production against a real citizen.
- `functions/dan-callback/` — the OAuth `redirect_uri` ХУР redirects the
  citizen's browser to after consent. **Must be deployed with**
  **`supabase functions deploy dan-callback --no-verify-jwt`** — unlike
  every other function here, this one is called directly by the citizen's
  browser via a 302 redirect, carrying no Supabase session/JWT at all;
  the default JWT check would reject ХУР's redirect with 401 before this
  code ever ran. Identity here comes entirely from `state`: rejects
  anything that doesn't match exactly one `pending`
  `identity_verifications` row minted by `dan-verify`'s `start` action —
  that check is this endpoint's CSRF/replay defense, standing in for the
  client-side `state`-equality check a normal redirect flow would do
  (there's no client here to do it). On a matching `state`, exchanges the
  authorization `code` for an access token
  (`POST https://sso.gov.mn/oauth2/token`), calls
  `GET https://sso.gov.mn/oauth2/api/v1/service` with it, and writes only
  `identity_verifications.status`/`verified_at` +
  `profiles.verification_level` — **never** the citizen payload itself
  (name, register number, ID card fields) — matching
  `identity_verifications`'s own table comment in `0001_init_schema.sql`
  ("never stores the raw national ID or DAN payload"). **Identity
  cross-check added (external audit, Aug 2026):** `resultCode === 0`
  alone only proves *some* citizen consented on ХУР's page — not that
  they're the same person who filled in `identity_details`
  (surname/given name/register number) at registration. Now extracts a
  regnum from the ХУР response (defensively — see `extractRegnum`'s own
  comment, since the exact field name isn't confirmed) and fails
  verification on a mismatch against `identity_details.register_number`,
  rather than silently trusting `resultCode` alone; the regnum is used
  only for this in-memory comparison, never written to any table.
  Responds with a
  small static HTML page telling the citizen to return to the app (no
  Flutter code runs here — this is outside the app entirely); it also
  attempts a `huvalts://dan-callback` deep link, which is currently a
  harmless no-op since that scheme isn't registered anywhere yet (no
  `android`/`ios` platform projects exist in this repo — see "Known
  issues"). That's a UX nicety for later (auto-resume instead of a manual
  tap), not a correctness gap: `VerificationScreen`'s existing "I've
  completed consent" button already re-triggers a status poll when the
  citizen manually switches back to the app, and by then this function
  has long since written the real outcome.
- `functions/initiate-payment/` (Phase 5, gated on `PAYMENT_PROVIDER_MODE`
  since Phase 6) — the *only* way a `payments` row gets created.
  `0002_rls_policies.sql` gives that table zero client-facing write
  policies, so unlike DAN's mock (which is a pure client-side fake
  because `identity_verifications` does allow a client insert), even mock
  payments have to go through a real Edge Function. Verifies the caller
  is the booking's renter and the booking is `confirmed`, then inserts a
  `pending` payment for `bookings.total_amount` — idempotently: if a
  `pending`/`authorized`/`paid` payment already exists for the booking
  it's returned as-is instead of creating a duplicate. Phase 6 added the
  same `PAYMENT_PROVIDER_MODE` gate `mock-complete-payment` already had:
  before that fix, a deployment with `PAYMENT_PROVIDER_MODE` set to
  anything but `mock` could still create `provider: 'mock'` payment rows
  here that `mock-complete-payment` would then refuse to ever complete —
  a payment stuck pending forever with no way to finish it. As of Phase
  7, `mock-complete-payment` also calls `credit_wallet_for_payment`
  (best-effort — a crediting failure doesn't undo the payment itself,
  it's logged for follow-up) right after marking a payment `paid`.
- `functions/mock-complete-payment/` (Phase 5) — stands in for the
  webhook a real payment provider would call back on. Gated by
  `PAYMENT_PROVIDER_MODE` (mirrors `DAN_AUTH_MODE`; defaults to `mock`)
  — returns `501` if that's set to anything else. Takes a simulated
  `success`/`failure` outcome (chosen by the user in the Flutter mock
  checkout sheet, *not* trusted as a real gateway signal — see the
  in-file header comment for what a production version needs: signature
  verification against the real provider's webhook payload instead of a
  client-supplied boolean), records a `payment_events` row, and updates
  `payments.status` to `paid`/`failed`. As of Phase 8, it also inserts
  `notifications` rows directly (service-role, same as its
  `credit_wallet_for_payment` call) — `payment_succeeded`/
  `payment_received` for the renter/owner on success, `payment_failed`
  for the renter on failure — since a payment outcome doesn't go through
  either of `0009`'s triggers on its own.
- `functions/wire-topup/` — authenticated; the Flutter client calls this
  to start (and, in mock mode, self-complete) a wire.mn wallet top-up.
  **Booking payments are now wallet-balance-based end to end** — see
  `pay_booking_from_wallet` in `migrations/0017_wire_topup_and_wallet_payments.sql`
  — so this is how real money gets into a wallet in the first place.
  Gated on `WIRE_TOPUP_MODE` (mirrors every other provider gate in this
  project; defaults to `mock`). The product's original ask was "send
  every top-up to this one static wire.mn payment link
  (`pay.wire.mn/link/plink_...`), fixed amount" — implementing that
  surfaced two problems, confirmed with the user before building this
  instead: (1) that live link is actually an *open*-amount page, not
  fixed, and (2) wire.mn's static Payment Links don't accept a
  metadata/client-reference field, so a shared static link has no way to
  say which user paid when the webhook fires — a payment could credit
  the wrong wallet. `action: 'create'` (default) creates a fresh
  wire.mn PaymentIntent *and* a checkout session per top-up request, with
  `metadata.user_id` set to the caller's own id, and records a `pending`
  `wallet_topups` row keyed by the PaymentIntent's id — that id is the
  only thing `wire-topup-webhook` (below) trusts to decide which wallet
  to credit. Returns the hosted `pay.wire.mn/c/...` checkout URL for the
  client to open. `action: 'mock_complete'` is `mock-complete-payment`'s
  same pattern applied to top-ups — refused outright once
  `WIRE_TOPUP_MODE=production`, and even in mock mode it only completes a
  topup whose `provider_reference` is itself mock-created.
- `functions/wire-topup-webhook/` — public, **must be deployed with
  `--no-verify-jwt`** (same reason as `dan-callback`: wire.mn calls this
  directly, there is no Supabase session on the request). Its entire
  trust model is the request's own signature — verifies the
  `WirePayment-Signature: t=...,v1=...` header (HMAC-SHA256 over
  `"<t>.<rawBody>"` using `WIRE_WEBHOOK_SECRET`, constant-time compared,
  5-minute replay tolerance) and fails **closed** (rejects) on any
  missing secret, missing header, or mismatch — never processes an
  unverified event. On a verified `payment_intent.succeeded`, looks up
  `wallet_topups` by `provider_reference = <payment intent id>` (never by
  the payload's `metadata.user_id` alone — the row `wire-topup` already
  pinned to a specific user is the source of truth) and calls
  `credit_wallet_for_topup`, idempotently (a redelivered webhook for an
  already-`paid` topup is a no-op). **Caveat, flagged in the file's own
  header comment**: wire.mn's public docs document the signature header
  precisely but not the exact JSON shape of a `payment_intent.succeeded`
  body — `extractPaymentIntent` tries a few plausible shapes and logs the
  raw payload if none match, so a first real test event that doesn't
  parse is loud in the function logs rather than silently dropping a
  real payment. Verify against wire.mn's dashboard test-event feature (or
  your first real top-up) and adjust that one function if needed.
- `functions/reconcile-wire-topups/` — reconciles `wallet_topups` rows
  stuck `pending` for reasons `wire-topup-webhook` above can't fix on its
  own: an orphaned row (checkout-session creation failed right after the
  PaymentIntent + row were created) or a missed/failed webhook delivery.
  Polls wire.mn's PaymentIntent-status endpoint directly for any real
  (non-mock), stale-pending (15+ minutes old) row and reconciles: credits
  via the same idempotent `credit_wallet_for_topup` RPC the webhook uses
  if wire.mn says it succeeded, marks `failed` if wire.mn says it can't
  ever be paid, leaves it alone if still genuinely pending. Accepts two
  kinds of caller, checked in the function itself: the project's own
  service-role key as the bearer token (for scheduling — see below), or
  a signed-in admin's session (gated by `is_admin`, for the "Wire дахин
  шалгах" manual action on the admin dashboard). **Not wired to run on
  its own** — this project deliberately doesn't schedule it via
  `pg_cron`/`pg_net` the way `expire_stale_pending_bookings` (0019/0020)
  is, since that route needs the service-role key stored as a Postgres
  setting, and every other secret in this project stays in Edge Function
  secrets only. To automate it, either give it its own schedule via
  Supabase Dashboard → Edge Functions → this function → Cron, or point an
  external scheduler at its URL with the service-role key you already
  have.
- `functions/suggest-listing-from-photo/` (Phase 10, gated on
  `AI_LISTING_MODE`, mirrors `DAN_AUTH_MODE`/`PAYMENT_PROVIDER_MODE`;
  defaults to `mock`, `501`s otherwise) — the backend half of the AI
  listing assistant. Checks the caller's `ai_listing_suggestions` row
  count over the last 24h against `MAX_CALLS_PER_DAY` (30) before doing
  anything else, returning `429` if exhausted — the first endpoint in
  this project that needed a rate limit, since it's the first one that
  would call a metered third-party API per request once real. The mock
  branch logs the call (`mock: true`) and returns a suggestion that is
  deliberately *structural, not content-specific* — a fill-in-the-blanks
  description template, a neutral default condition, and spec *field
  names* worth adding (never fabricated values) — because nothing here
  actually decoded or looked at the photo bytes it received. Swapping to
  a real provider means implementing the `TODO(production)` block: decode
  `photos` (already base64 in the request body), call a real
  vision-capable model, and map its answer onto the same
  `title_suggestion`/`description_suggestion`/`condition_suggestion`/
  `suggested_spec_fields` response shape — no Flutter changes needed,
  same swap story as `dan-verify`.

Deploy with:

`supabase/config.toml`'s `[functions.dan-callback]`/
`[functions.wire-topup-webhook]` sections now set `verify_jwt = false`
declaratively (external audit follow-up, Aug 2026 — see that file's own
header comment), so the CLI applies it automatically on
`supabase functions deploy <name>` even without the explicit
`--no-verify-jwt` flag below. The flag is left in these commands anyway
as belt-and-suspenders — harmless if config.toml already covers it,
still correct if this project isn't `supabase link`-ed yet when you run
these.

```bash
supabase functions deploy dan-verify
supabase secrets set DAN_AUTH_MODE=mock

# Real ХУР instead of mock — also requires dan-callback deployed (below)
# and registered as this client's redirect_uri with ХУР:
#   supabase secrets set DAN_AUTH_MODE=production \
#     DAN_CLIENT_ID=... DAN_CLIENT_SECRET=... \
#     DAN_REDIRECT_URI=https://YOUR-PROJECT.functions.supabase.co/dan-callback
supabase functions deploy dan-callback --no-verify-jwt


# initiate-payment / mock-complete-payment: DO NOT deploy these anymore.
# Booking payments are wallet-based (pay_booking_from_wallet) as of 0017
# — these two are now permanently disabled at the code level (see their
# own header comments) because they were a live free-money exploit once
# the wallet flow superseded them. If either is still deployed from
# before this change, undeploy it:
#   supabase functions delete initiate-payment
#   supabase functions delete mock-complete-payment

supabase functions deploy suggest-listing-from-photo
supabase secrets set AI_LISTING_MODE=mock

supabase functions deploy wire-topup
supabase functions deploy wire-topup-webhook --no-verify-jwt
supabase secrets set WIRE_TOPUP_MODE=mock

# Real wire.mn instead of mock — set your OWN secret key/webhook signing
# secret from your own machine, never here, never pasted into chat:
#   supabase secrets set WIRE_TOPUP_MODE=production \
#     WIRE_SECRET_KEY=sk_live_... \
#     WIRE_WEBHOOK_SECRET=whsec_...
# Then register https://YOUR-PROJECT.functions.supabase.co/wire-topup-webhook
# as the webhook endpoint URL in wire.mn's dashboard/API, subscribed to
# payment_intent.succeeded, and copy the whsec_... it returns into the
# secret above (it's shown only once).
```

## Still to build (later phases)

**Booking payments are wallet-based now, not `initiate-payment`/
`mock-complete-payment`.** Those two functions are left in the repo as
source only, for history — **both are now permanently disabled** (see
`0018_security_and_consistency_hardening.sql`'s header comment and each
function's own file): once `pay_booking_from_wallet` became the
sanctioned path, the old pair became a live free-money exploit (any
renter could mark their own booking "paid" via `initiate-payment` +
`mock-complete-payment` and credit the owner's wallet with no debit ever
happening on the renter's side). The Flutter client's booking checkout
calls `pay_booking_from_wallet` directly — see
`migrations/0017_wire_topup_and_wallet_payments.sql`'s header comment for
the full reasoning. A future direct-card/QPay-at-booking-time flow, if
the product ever wants one *in addition to* wallet balance, would need a
new implementation built from scratch with real session/intent creation
and signature-verified webhook handling (matching wire.mn's own
`wire-topup`/`wire-topup-webhook` pattern) — not a revival of these two.
wire.mn itself (the wallet top-up side) already has a real, non-mock
adapter — see `functions/wire-topup/`
and `functions/wire-topup-webhook/` above — gated on `WIRE_TOPUP_MODE`
the same way DAN's real branch is gated on `DAN_AUTH_MODE`.

A real vision provider
integration behind `suggest-listing-from-photo`'s
`AI_LISTING_MODE=production` branch (same story again — Phase 10's own
README bullet spells out exactly what stays the same and what changes
when this lands), push delivery of the notification rows `0009`'s (and
now `0010`'s) triggers already create (FCM — no phase number of its own
in spec section 49, same "needs `flutterfire configure` and real project
credentials" story as Firebase generally; today a notification only
shows up if the app is already open), image messages in chat (needs the
same Storage upload wiring asset photos use — `messages`/`MessageKind`
already model `image` but the composer only sends `text`), and a unified
"all my conversations" inbox (chat is reached per-booking only right
now). None of these are stubbed yet — they're listed here so they aren't
mistaken for "already covered by 0001-0012" / the functions above.

**As of Phase 11, closed:** payout *processing* (`admin_process_payout`),
dispute resolution (`admin_resolve_dispute` — replacing the old
`disputes_update_admin` direct-write path `0010` was waiting on), asset
moderation (`admin_approve_asset`/`admin_reject_asset`/
`admin_suspend_asset` — what Phase 3's `createAsset` comment was waiting
on), report resolution (`admin_resolve_report`), and commission settings
(`admin_update_commission_percent` — what `create_booking`'s hardcoded
10% was waiting on). See the `0012_admin_dashboard.sql` bullet above.

**Real gaps Phase 11 itself left behind:**
- No self-service admin invite/promotion(-to-admin) flow — granting admin
  access is still a direct `insert into admin_users (user_id, role)`, no
  UI for it (admin or otherwise). **Still open as of Phase 12** — this
  hardening pass closed the `promotions_admin_write` gap (see the `0013`
  bullet above and "Still open after Phase 12" below) but admin-granting
  itself is a different, still-unstarted flow.
- `promotions_admin_write` (0002) was a direct, unaudited RLS write path
  — unlike `disputes_update_admin`, it wasn't flagged as a "waiting on
  Phase 11" gap by any earlier phase, so it was deliberately left out of
  scope that phase. **Closed in Phase 12** — see the `0013` migration
  bullet above.
- No admin-role Edge Function surface, by design — none of Phase 11's (or
  Phase 12's) admin actions need one; see the "Edge Functions" section
  above for why plain `SECURITY DEFINER` RPCs were the right shape
  instead.
- No platform-wide admin analytics/reporting (spec section 29 also
  describes metrics like GMV, active listings, dispute rate) — every
  admin phase so far is action queues only. **Still open after Phase 12.**

**Still open after Phase 12:** the admin-invite flow and admin
analytics/reporting above, a real payment/DAN/vision-provider
integration (see the "Still to build" paragraph above), PostGIS, image
messages in chat, a unified conversation inbox, and push delivery (FCM)
— none of these are in scope for a security/perf/testing/release
hardening pass; they're feature work with no phase number of their own
left in the original 12-phase plan.

The booking-completion flow that releases `wallets.pending_balance` into
`available_balance` — listed here as still-missing through Phase 7 and
Phase 8 — **is now built** (`0010`'s `advance_booking_on_condition_report`,
triggered off a return condition report both parties confirm). Kept as a
crossed-off entry here rather than silently deleted, since two earlier
phases' own "still to build" lists pointed at it.

**The real DAN consent callback is now built** — `functions/dan-callback/`
does the token exchange + citizen-info fetch that ХУР's redirect requires
a live server endpoint for, and `dan-verify`'s `start`/`status` actions
were updated alongside it (see both bullets above). What's still a
deliberate gap: the citizen's browser isn't automatically handed back to
the Flutter app after `dan-callback` finishes — that needs a
`huvalts://` deep link registered in the native `android`/`ios` projects,
which don't exist in this repo yet (see "Known issues"). Until that's
wired up, `VerificationScreen`'s existing manual "I've completed consent"
button (unchanged) covers reconnecting to the app correctly — the
backend outcome is already written by the time the citizen taps it, so
this is a UX polish item, not a functional gap.

`create_booking` (0006, re-declared by 0012) is daily-pricing only — an
asset with only `price_per_hour`/`price_per_week` set can't be booked
through it yet, and `delivery_fee` is hardcoded to 0 since there's no
per-asset delivery pricing column. **As of Phase 11**, commission is no
longer hardcoded — it's read from `platform_settings`
(`admin_update_commission_percent`), defaulting to the same 10%
`AppConstants.defaultCommissionPercent` mirrors client-side for the
booking screen's price *estimate* (never the authoritative figure —
that's always this function's own read of the table).

`initiate-payment` hardcodes `currency: 'MNT'` since `bookings` has no
currency column of its own (only `assets.currency` does) — worth
revisiting if the catalog ever needs multi-currency listings.

**As of Phase 12, asset search uses a real `tsvector`/GIN full-text
index** (`assets.search_vector`, `0013_security_perf_hardening.sql`)
instead of a plain `ILIKE '%query%'` against `title` alone — see the
`0013` migration bullet above. Still not in the schema: PostGIS (the
"closest" sort/nearby radius still pulls a batch of rows and sorts by
Haversine distance client-side in `GeoUtils` — see
`lib/features/assets/data/repositories/supabase_asset_repository.dart`);
real geospatial indexing/queries are a bigger schema change than this
hardening pass was scoped for.
