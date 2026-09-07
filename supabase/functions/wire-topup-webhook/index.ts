// ХУВААЛЦ — wire.mn webhook receiver for wallet top-ups.
//
// DIFFERENT FROM `wire-topup/index.ts`, same way `dan-callback` differs
// from `dan-verify`: this one is called by wire.mn's own servers, not by
// the Flutter app, so there is no Supabase session/JWT on the request —
// it must be deployed with JWT verification disabled:
//
//   supabase functions deploy wire-topup-webhook --no-verify-jwt
//
// Because this endpoint has no Supabase auth to lean on, its entire
// trust model is the request's own cryptographic signature — see
// `verifySignature` below. No signature, wrong signature, or a missing
// `WIRE_WEBHOOK_SECRET` secret all fail CLOSED (the request is rejected),
// never open — a webhook endpoint that would process an unverified
// "payment succeeded" event is a direct path to crediting wallets for
// money that was never actually paid.
//
// SECRETS: `WIRE_WEBHOOK_SECRET` (a `whsec_...` value, returned once when
// the webhook endpoint is registered in wire.mn's dashboard/API — see
// their webhooks guide) must be set yourself, never pasted into chat:
//
//   supabase secrets set WIRE_WEBHOOK_SECRET=whsec_...
//
// PAYLOAD SHAPE CAVEAT: wire.mn's public docs describe the signature
// header format precisely (`WirePayment-Signature: t=<ts>,v1=<hex>`,
// signed over `"<t>.<rawBody>"`) but do not publish the exact JSON shape
// of a `payment_intent.succeeded` event body. `extractPaymentIntent`
// below tries several plausible shapes (Stripe-style `{type, data:
// {object}}`; `{event, data}` with `data` itself being the PaymentIntent
// — added after an external audit, Aug 2026, claimed wire.mn's actual
// event schema puts the affected resource directly on `event.data`
// rather than nested under `.object`; this project could not itself
// independently confirm that claim against a primary wire.mn source, but
// it costs nothing to also accept the shape defensively; a flatter
// `{event, payment_intent}`; or the PaymentIntent itself as the
// top-level body) and logs the raw payload whenever none
// of them match, so a mismatch is loud in the function logs rather than
// silently dropping real payments. If your first real test event doesn't
// parse, check those logs and adjust `extractPaymentIntent` to match
// what wire.mn actually sends — everything else in this file (signature
// verification, the wallet_topups lookup/credit) does not depend on that
// shape.
//
// MATCHING A TOPUP TO A WALLET: `wire-topup/index.ts` stores each
// PaymentIntent's id as `wallet_topups.provider_reference` the moment it
// creates it — that id is this function's only lookup key.
// `credit_wallet_for_payment`-style trust in `metadata.user_id` alone is
// deliberately NOT used to pick which wallet to credit; the row already
// pinned to a specific user_id when it was created is the source of
// truth, exactly so a mismatched/forged metadata field can't redirect
// money to the wrong wallet.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SIGNATURE_TOLERANCE_SECONDS = 300; // reject signatures older than 5 minutes (replay defense)

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const webhookSecret = Deno.env.get('WIRE_WEBHOOK_SECRET');
  if (!webhookSecret) {
    console.error('wire-topup-webhook: missing WIRE_WEBHOOK_SECRET secret — refusing to process unverifiable events');
    return json({ error: 'webhook_not_configured' }, 500);
  }

  // Read the RAW body text first — verification must run over the exact
  // bytes wire.mn signed, before any JSON parsing/reserialization could
  // change whitespace or key order.
  const rawBody = await req.text();
  const signatureHeader = req.headers.get('WirePayment-Signature');
  const verification = await verifySignature(rawBody, signatureHeader, webhookSecret);
  if (!verification.ok) {
    console.error('wire-topup-webhook: signature verification failed', verification.reason);
    return json({ error: 'invalid_signature' }, 400);
  }

  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  const eventType = getEventType(payload);
  if (eventType !== 'payment_intent.succeeded') {
    // Acknowledge anything we don't act on — standard webhook practice,
    // avoids wire.mn retrying an event this endpoint was never going to
    // do anything with.
    return json({ received: true, ignored: eventType ?? 'unknown' }, 200);
  }

  const pi = extractPaymentIntent(payload);
  if (!pi?.id) {
    console.error('wire-topup-webhook: could not locate a PaymentIntent id in payload', JSON.stringify(payload));
    return json({ received: true, warning: 'unrecognized_payload_shape' }, 200);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const { data: topup, error: lookupError } = await supabase
    .from('wallet_topups')
    .select('*')
    .eq('provider_reference', pi.id)
    .maybeSingle();

  if (lookupError) {
    console.error('wire-topup-webhook: lookup failed', lookupError);
    return json({ error: 'lookup_failed' }, 500);
  }
  if (!topup) {
    // No matching row — either an event for a PaymentIntent this app
    // never created, or (bug) the create step failed to record it.
    // Acknowledge rather than error so wire.mn doesn't retry forever;
    // this is logged for follow-up either way.
    console.error('wire-topup-webhook: no wallet_topups row for provider_reference', pi.id);
    return json({ received: true, warning: 'no_matching_topup' }, 200);
  }

  if (topup.status === 'paid') {
    return json({ received: true, already_credited: true }, 200); // webhook redelivery — idempotent no-op
  }

  const { error: creditError } = await supabase.rpc('credit_wallet_for_topup', { p_topup_id: topup.id });
  if (creditError) {
    console.error('wire-topup-webhook: credit_wallet_for_topup failed', creditError);
    return json({ error: 'credit_failed' }, 500);
  }

  await supabase.from('notifications').insert({
    user_id: topup.user_id,
    event_type: 'wallet_topup_succeeded',
    title: 'Хэтэвч цэнэглэгдлээ',
    body: '',
    deep_link: '/wallet',
  });

  return json({ received: true }, 200);
});

async function verifySignature(
  rawBody: string,
  header: string | null,
  secret: string,
): Promise<{ ok: true } | { ok: false; reason: string }> {
  if (!header) return { ok: false, reason: 'missing_header' };

  const parts = Object.fromEntries(
    header.split(',').map((kv) => {
      const [k, v] = kv.split('=');
      return [k?.trim(), v?.trim()];
    }),
  );
  const t = parts['t'];
  const v1 = parts['v1'];
  if (!t || !v1) return { ok: false, reason: 'malformed_header' };

  const tSeconds = Number(t);
  if (!Number.isFinite(tSeconds)) return { ok: false, reason: 'malformed_timestamp' };
  const ageSeconds = Math.abs(Date.now() / 1000 - tSeconds);
  if (ageSeconds > SIGNATURE_TOLERANCE_SECONDS) return { ok: false, reason: 'timestamp_out_of_tolerance' };

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signatureBytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${t}.${rawBody}`));
  const expectedHex = toHex(new Uint8Array(signatureBytes));

  if (!timingSafeEqual(expectedHex, v1.toLowerCase())) {
    return { ok: false, reason: 'signature_mismatch' };
  }
  return { ok: true };
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function getEventType(payload: unknown): string | undefined {
  if (typeof payload !== 'object' || payload === null) return undefined;
  const p = payload as Record<string, unknown>;
  return (p.type as string) ?? (p.event as string) ?? (p.event_type as string) ?? undefined;
}

// Tries several plausible shapes for where the actual PaymentIntent
// object lives in the webhook body — see this file's header comment on
// why the exact shape isn't confirmed against real wire.mn docs yet.
function extractPaymentIntent(payload: unknown): { id?: string; status?: string } | undefined {
  if (typeof payload !== 'object' || payload === null) return undefined;
  const p = payload as Record<string, unknown>;

  const dataObject = (p.data as Record<string, unknown> | undefined)?.object;
  if (dataObject && typeof dataObject === 'object') {
    return dataObject as { id?: string; status?: string };
  }
  // Added after an external audit (Aug 2026) flagged that `data` itself
  // (not nested under `data.object`) is also a plausible — arguably more
  // likely, per wire.mn's own event docs describing `event.data` as "the
  // affected resource" directly — shape for this event. Checked after
  // the Stripe-style `data.object` case above (more specific), before
  // the flatter `payment_intent`/top-level cases below (less specific):
  // a payload with a `data` object carrying an `id` field is read as the
  // PaymentIntent itself.
  const dataDirect = p.data as Record<string, unknown> | undefined;
  if (dataDirect && typeof dataDirect === 'object' && typeof dataDirect.id === 'string') {
    return dataDirect as { id?: string; status?: string };
  }
  if (p.payment_intent && typeof p.payment_intent === 'object') {
    return p.payment_intent as { id?: string; status?: string };
  }
  if (typeof p.id === 'string' && p.id.startsWith('pi_')) {
    return p as { id?: string; status?: string };
  }
  return undefined;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
