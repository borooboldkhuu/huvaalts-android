// ХУВААЛЦ — reconciles stuck/orphaned `wallet_topups` rows against
// wire.mn's own PaymentIntent status. See README's "Known issues" for
// the two ways a real (non-mock) top-up can otherwise get stranded in
// `pending` forever:
//   1. `wire-topup`'s `create` action inserts the `wallet_topups` row
//      right after creating the PaymentIntent, then makes a *second*
//      wire.mn API call to create the checkout session — if that second
//      call fails, the row exists but no checkout URL was ever handed
//      to the payer, so it can never be paid through the app.
//   2. The payer DID complete payment on the hosted pay.wire.mn page,
//      but `wire-topup-webhook` never got (or never successfully
//      processed) the delivery — network hiccup, wire.mn's own retry
//      budget exhausted, or a webhook payload-shape mismatch (see that
//      function's header comment on why the exact shape isn't confirmed
//      against a real wire.mn event yet).
//
// This function asks wire.mn directly what actually happened to each
// stale-pending PaymentIntent and reconciles our side to match: credits
// the wallet if wire.mn says it succeeded (via the same
// `credit_wallet_for_topup` RPC the webhook uses — idempotent, so a race
// with a late-arriving webhook is harmless), marks the row `failed` if
// wire.mn says it failed/was cancelled/doesn't exist, and leaves it
// alone if wire.mn still shows it genuinely pending.
//
// TWO WAYS TO INVOKE THIS — both supported by the auth check below:
//   1. Automated: call it on a schedule using the project's service-role
//      key as the `Authorization: Bearer <key>` header. The built-in way
//      to do that with no extra secret handling is Supabase Dashboard →
//      Edge Functions → this function → its own "Cron" tab (or your own
//      external scheduler hitting this URL with the key you already
//      have). Deliberately NOT wired through `pg_cron`/`pg_net` the way
//      `expire_stale_pending_bookings` is (0019/0020) — that route would
//      need the service-role key stored as a Postgres setting, and this
//      project avoids putting secrets anywhere but Edge Function secrets.
//   2. Manual: a signed-in admin can trigger it on demand — see
//      `AdminRepository.reconcileWireTopups` (the "Wire дахин шалгах"
//      admin wallet-tools action). Gated by `public.is_admin`, the same
//      check every other admin RPC in this codebase uses.
//
// SECRETS: reads `WIRE_SECRET_KEY` exactly like `wire-topup/index.ts` —
// never hardcode it, never accept it from the request body.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const WIRE_API_BASE = 'https://api.wire.mn/v1';

// Give the webhook a fair chance to arrive on its own, and give wire.mn
// a fair chance to reach eventual consistency right after a checkout
// session is created, before polling.
const MIN_AGE_MINUTES = 15;

// Keeps one run bounded — wire.mn API calls are sequential and a large
// backlog shouldn't turn one invocation into a long-running request; a
// scheduled hourly/daily run works through a bounded batch each time.
const BATCH_LIMIT = 50;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const authHeader = req.headers.get('Authorization') ?? '';
  const bearer = authHeader.replace('Bearer ', '');
  if (!bearer) {
    return json({ error: 'unauthorized' }, 401);
  }

  // Accept either the service-role key itself (scheduled/automated
  // calls) or a signed-in admin's own session (manual calls) — never
  // anything else.
  const isServiceRoleCaller = bearer === serviceRoleKey;
  if (!isServiceRoleCaller) {
    const {
      data: { user },
    } = await supabase.auth.getUser(bearer);
    if (!user) {
      return json({ error: 'unauthorized' }, 401);
    }
    const { data: isAdmin, error: adminCheckError } = await supabase.rpc('is_admin', { uid: user.id });
    if (adminCheckError || !isAdmin) {
      return json({ error: 'not_authorized' }, 403);
    }
  }

  const secretKey = Deno.env.get('WIRE_SECRET_KEY');
  if (!secretKey) {
    // Mock mode / wire.mn not configured yet — nothing real to
    // reconcile against. Not an error.
    return json({ reconciled: 0, skipped: 'wire_not_configured' }, 200);
  }

  const cutoffIso = new Date(Date.now() - MIN_AGE_MINUTES * 60 * 1000).toISOString();
  const { data: stale, error: fetchError } = await supabase
    .from('wallet_topups')
    .select('*')
    .eq('provider', 'wire')
    .eq('status', 'pending')
    .lt('created_at', cutoffIso)
    .not('provider_reference', 'like', 'mock_wire_%')
    .order('created_at', { ascending: true })
    .limit(BATCH_LIMIT);

  if (fetchError) {
    console.error('reconcile-wire-topups: fetch failed', fetchError);
    return json({ error: 'fetch_failed' }, 500);
  }

  const results: Array<{ id: string; outcome: string }> = [];
  for (const topup of stale ?? []) {
    const outcome = await reconcileOne(supabase, secretKey, topup as Record<string, unknown>);
    results.push({ id: (topup as Record<string, unknown>).id as string, outcome });
  }

  return json({ reconciled: results.length, results });
});

async function reconcileOne(
  supabase: ReturnType<typeof createClient>,
  secretKey: string,
  topup: Record<string, unknown>,
): Promise<string> {
  const providerReference = topup.provider_reference as string | null;
  const topupId = topup.id as string;
  if (!providerReference) return 'no_reference';

  let piRes: Response;
  try {
    piRes = await fetch(`${WIRE_API_BASE}/payment_intents/${providerReference}`, {
      headers: { Authorization: `Bearer ${secretKey}` },
    });
  } catch (e) {
    console.error('reconcile-wire-topups: request failed for', providerReference, e);
    return 'wire_request_failed';
  }

  if (piRes.status === 404) {
    // wire.mn has no record of this PaymentIntent — it can never be
    // paid (this is the "checkout session creation failed right after
    // the PaymentIntent insert" orphan, or the PaymentIntent itself was
    // somehow never created on wire.mn's side). Mark it failed so it
    // stops looking like a live pending top-up and drops out of future
    // reconciliation batches.
    await markFailed(supabase, topupId);
    return 'not_found_marked_failed';
  }
  if (!piRes.ok) {
    console.error('reconcile-wire-topups: payment_intents lookup failed', providerReference, piRes.status);
    return 'wire_lookup_failed';
  }

  const pi = (await piRes.json()) as { status?: string };

  if (pi.status === 'succeeded') {
    const { error: creditError } = await supabase.rpc('credit_wallet_for_topup', { p_topup_id: topupId });
    if (creditError) {
      console.error('reconcile-wire-topups: credit_wallet_for_topup failed', topupId, creditError);
      return 'credit_failed';
    }
    await supabase.from('notifications').insert({
      user_id: topup.user_id,
      event_type: 'wallet_topup_succeeded',
      title: 'Хэтэвч цэнэглэгдлээ',
      body: '',
      deep_link: '/wallet',
    });
    return 'credited';
  }

  if (pi.status === 'canceled' || pi.status === 'cancelled' || pi.status === 'failed') {
    await markFailed(supabase, topupId);
    return 'marked_failed';
  }

  // Still genuinely pending on wire.mn's side (e.g. the payer hasn't
  // finished the checkout page yet) — leave it alone, next run checks
  // again.
  return 'still_pending';
}

async function markFailed(supabase: ReturnType<typeof createClient>, topupId: string): Promise<void> {
  // `.eq('status', 'pending')` guards against clobbering a status a
  // concurrent webhook delivery already moved on from between this
  // function's fetch and this write.
  await supabase.from('wallet_topups').update({ status: 'failed' }).eq('id', topupId).eq('status', 'pending');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
