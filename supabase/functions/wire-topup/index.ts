// ХУВААЛЦ — starts (and, in mock mode, completes) a wire.mn wallet
// top-up. Authenticated — called by the Flutter app with the renter's own
// Supabase session, never by wire.mn itself (that's `wire-topup-webhook`,
// a separate public function — see its header comment for why the real
// completion path has to live there instead of here).
//
// WHY THIS REPLACED THE ORIGINALLY-REQUESTED STATIC PAYMENT LINK: the
// product ask was "use this exact wire.mn payment link
// (pay.wire.mn/link/plink_...) for top-ups, fixed amount." Two things
// found while implementing made that impossible to do safely:
//   1. That live link is actually an *open*-amount page (a "Төлөх дүн
//      (₮)" field the payer fills in themselves), not fixed.
//   2. wire.mn's static Payment Links product does not accept a
//      metadata/client-reference field. If every user in the app were
//      sent to the same shared static link, a `payment_intent.succeeded`
//      webhook would have no reliable way to say *which* user's wallet to
//      credit — a payment could land in the wrong person's balance.
// The user confirmed (see chat) the fix: create a fresh PaymentIntent
// per top-up request via wire.mn's API, with `metadata.user_id` set to
// the requesting user's own id, so the webhook can always attribute the
// payment correctly. This function is that per-request creation step.
//
// SECRETS: reads `WIRE_SECRET_KEY` (a `sk_live_...`/`sk_test_...` value)
// from Supabase Edge Function secrets — NEVER hardcode it here, and never
// accept it from the request body. Set it yourself, from your own
// machine, with:
//
//   supabase secrets set WIRE_SECRET_KEY=sk_live_...
//
// If a real key was ever pasted into a chat with an AI assistant (this
// one included), treat it as compromised — rotate it in the wire.mn
// dashboard before using it here.
//
// MODES (mirrors `PAYMENT_PROVIDER_MODE`/`DAN_AUTH_MODE` elsewhere in
// this project): `WIRE_TOPUP_MODE` — 'mock' (default) | 'production'.
// Mock mode never calls wire.mn at all; it exists so the wallet
// top-up -> booking-payment flow can be built/tested/demoed with no
// wire.mn account yet. `action: 'mock_complete'` is the mock-mode-only
// stand-in for the real webhook (see `mock-complete-payment/index.ts` for
// the identical pattern already used for booking payments) — it is
// refused outright once `WIRE_TOPUP_MODE=production`, and even in mock
// mode it will only ever complete a topup whose `provider_reference`
// itself was mock-created (defense in depth: a client can't use this
// action to fraudulently mark a real, wire.mn-pending topup as paid).

import { createClient } from 'jsr:@supabase/supabase-js@2';

const WIRE_TOPUP_MODE = Deno.env.get('WIRE_TOPUP_MODE') ?? 'mock';
const WIRE_API_BASE = 'https://api.wire.mn/v1';

// Sane bounds for a self-service top-up — adjust to product needs.
// Amounts are whole MNT (tögrög) as entered by the user; wire.mn's API
// wants "minor units" (1 MNT = 100 minor units per its docs' own
// 500.00 MNT = 50000 example), converted just before the API call.
const MIN_TOPUP_MNT = 1000;
const MAX_TOPUP_MNT = 5000000;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'unauthorized' }, 401);
  }
  const {
    data: { user },
  } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
  if (!user) {
    return json({ error: 'unauthorized' }, 401);
  }

  let body: { action?: string; amount_mnt?: number; topup_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  if (body.action === 'mock_complete') {
    return handleMockComplete(supabase, user.id, body.topup_id);
  }

  // Default / only other action is 'create'.
  return handleCreate(supabase, user.id, body.amount_mnt);
});

async function handleCreate(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  amountMnt: number | undefined,
): Promise<Response> {
  if (
    typeof amountMnt !== 'number' ||
    !Number.isFinite(amountMnt) ||
    amountMnt < MIN_TOPUP_MNT ||
    amountMnt > MAX_TOPUP_MNT
  ) {
    return json({ error: 'invalid_amount', min: MIN_TOPUP_MNT, max: MAX_TOPUP_MNT }, 400);
  }
  // Round to whole төгрөг — the wallet ledger (numeric(12,2)) can carry
  // cents, but MNT has no practical subunit and wire.mn's own examples
  // are whole-tögrög amounts.
  const amount = Math.round(amountMnt);

  if (WIRE_TOPUP_MODE !== 'production') {
    const { data: created, error: insertError } = await supabase
      .from('wallet_topups')
      .insert({
        user_id: userId,
        provider: 'wire',
        provider_reference: `mock_wire_${crypto.randomUUID()}`,
        amount,
        currency: 'MNT',
        status: 'pending',
      })
      .select()
      .single();
    if (insertError || !created) {
      return json({ error: 'create_failed' }, 500);
    }
    return json({ topup: created, mock: true, checkout_url: null });
  }

  const secretKey = Deno.env.get('WIRE_SECRET_KEY');
  if (!secretKey) {
    console.error('wire-topup: missing WIRE_SECRET_KEY secret');
    return json({ error: 'wire_not_configured' }, 500);
  }

  const requestKey = crypto.randomUUID();

  try {
    // 1. PaymentIntent — the actual amount/currency/metadata this top-up
    // will be verified against when the webhook arrives.
    const piRes = await fetch(`${WIRE_API_BASE}/payment_intents`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secretKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': `topup_pi_${requestKey}`,
      },
      body: JSON.stringify({
        amount: amount * 100, // minor units
        currency: 'MNT',
        description: 'ХУВААЛЦ хэтэвч цэнэглэлт',
        metadata: { user_id: userId },
      }),
    });
    if (!piRes.ok) {
      console.error('wire-topup: payment_intents failed', piRes.status, await safeText(piRes));
      return json({ error: 'wire_request_failed' }, 502);
    }
    const pi = (await piRes.json()) as { id?: string };
    if (!pi.id) {
      console.error('wire-topup: payment_intents response had no id');
      return json({ error: 'wire_request_failed' }, 502);
    }

    // Record the pending topup now, keyed by the PaymentIntent id — this
    // is the row `wire-topup-webhook` will look up by `provider_reference`
    // once wire.mn reports success. `provider_reference` is unique, so a
    // retried request that got here twice for the same PaymentIntent
    // would fail the insert rather than double-record it; that's fine
    // for now since each `create` call always mints a fresh PaymentIntent
    // (no client-supplied idempotency across separate `create` calls).
    const { data: topup, error: insertError } = await supabase
      .from('wallet_topups')
      .insert({
        user_id: userId,
        provider: 'wire',
        provider_reference: pi.id,
        amount,
        currency: 'MNT',
        status: 'pending',
      })
      .select()
      .single();
    if (insertError || !topup) {
      console.error('wire-topup: wallet_topups insert failed', insertError);
      return json({ error: 'create_failed' }, 500);
    }

    // 2. Checkout session — this is what actually hands back a hosted
    // pay.wire.mn URL to send the payer's browser/webview to.
    const successUrl = Deno.env.get('WIRE_TOPUP_SUCCESS_URL') ?? undefined;
    const csRes = await fetch(`${WIRE_API_BASE}/checkout/sessions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secretKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': `topup_cs_${requestKey}`,
      },
      body: JSON.stringify({
        payment_intent: pi.id,
        ...(successUrl ? { success_url: successUrl } : {}),
      }),
    });
    if (!csRes.ok) {
      console.error('wire-topup: checkout/sessions failed', csRes.status, await safeText(csRes));
      return json({ error: 'wire_request_failed' }, 502);
    }
    const cs = (await csRes.json()) as { url?: string };
    if (!cs.url) {
      console.error('wire-topup: checkout/sessions response had no url');
      return json({ error: 'wire_request_failed' }, 502);
    }

    return json({ topup, checkout_url: cs.url });
  } catch (e) {
    console.error('wire-topup: unexpected error', e);
    return json({ error: 'unexpected_error' }, 500);
  }
}

async function handleMockComplete(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  topupId: string | undefined,
): Promise<Response> {
  // Refuse mock-completion whenever a real wire.mn secret is configured
  // at all — not only when `WIRE_TOPUP_MODE` is explicitly 'production'.
  // `WIRE_TOPUP_MODE` defaults to 'mock' when simply unset, so a
  // deployment that shipped `WIRE_SECRET_KEY` (a live/test key) but
  // forgot (or had a redeploy reset) the separate `WIRE_TOPUP_MODE`
  // secret would otherwise silently keep taking the mock branch — and
  // `mock_complete` would then credit real wallet balance for free,
  // with no wire.mn payment ever having happened. A configured secret is
  // itself evidence this environment is meant to be real, regardless of
  // whether the mode flag was also correctly set.
  if (WIRE_TOPUP_MODE === 'production' || Deno.env.get('WIRE_SECRET_KEY')) {
    return json({ error: 'not_in_mock_mode' }, 400);
  }
  if (!topupId) {
    return json({ error: 'missing_topup_id' }, 400);
  }

  const { data: topup, error: lookupError } = await supabase
    .from('wallet_topups')
    .select('*')
    .eq('id', topupId)
    .maybeSingle();
  if (lookupError) return json({ error: 'lookup_failed' }, 500);
  if (!topup) return json({ error: 'topup_not_found' }, 404);
  if (topup.user_id !== userId) return json({ error: 'not_authorized' }, 403);
  if (topup.status !== 'pending') return json({ error: 'topup_not_pending' }, 409);
  if (!topup.provider_reference?.startsWith('mock_wire_')) {
    // Guards against using this action to short-circuit a real,
    // wire.mn-pending topup — only ever completes one this same mock
    // mode created.
    return json({ error: 'not_a_mock_topup' }, 400);
  }

  const { error: creditError } = await supabase.rpc('credit_wallet_for_topup', {
    p_topup_id: topupId,
  });
  if (creditError) {
    console.error('wire-topup: credit_wallet_for_topup failed', creditError);
    return json({ error: 'credit_failed' }, 500);
  }

  await supabase.from('notifications').insert({
    user_id: userId,
    event_type: 'wallet_topup_succeeded',
    title: 'Хэтэвч цэнэглэгдлээ',
    body: '',
    deep_link: '/wallet',
  });

  const { data: updated } = await supabase.from('wallet_topups').select('*').eq('id', topupId).single();
  return json({ topup: updated });
}

async function safeText(res: Response): Promise<string> {
  try {
    return await res.text();
  } catch {
    return '';
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
