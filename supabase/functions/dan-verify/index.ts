// ХУВААЛЦ — DAN identity verification backend endpoint.
//
// This is the server-side half of the architecture required by spec
// section 9:
//   Flutter -> Backend Auth Endpoint -> DAN Authentication -> User Consent
//   -> Secure Callback -> Backend Verification -> Create/Link User -> Verified Account
//
// The Flutter app never talks to DAN directly — it calls this function,
// which is the only place a DAN client secret would ever live (as a
// Supabase Edge Function secret, never in this source file, never in the
// Flutter binary). Two Flutter-side adapters call this same function
// shape identically (see lib/features/auth/data/services/):
//   - MockDanAuthAdapter: doesn't call this function at all — a fully
//     offline local fake, for tests/demos with no backend deployed.
//   - EdgeFunctionDanAuthAdapter: the "production" adapter. It calls this
//     function for both mock-mode and real-DAN deployments — which one
//     actually happens is decided entirely by DAN_AUTH_MODE below, so the
//     Flutter code never needs to change when this function's mode flips
//     (spec section 51: "implement the adapter/interface and a safe mock
//     environment, clearly mark the missing production configuration").
//
// Routing: a single POST endpoint, action selected by `action` in the
// JSON body (`'start'` | `'status'`) rather than by sub-path/HTTP verb —
// this matches the shape of every other function in this project
// (initiate-payment, mock-complete-payment) and avoids depending on
// exactly how a given Supabase client library builds sub-path URLs.
//
// STATUS: DAN_AUTH_MODE defaults to 'mock'. No official DAN API
// documentation or credentials were available when this was written, so
// the mock branch fully implements the *shape* of the real flow (start
// session -> poll status -> mark identity_verifications row verified)
// using deterministic fake data — enough for the rest of the product
// (verification badges, booking gates on verification level, etc.) to be
// built and demoed today, without ever claiming a real DAN check happened.
//
// LIVE as of this commit: `DAN_AUTH_MODE=production` calls the real ХУР
// (Government Data Exchange / "Иргэний бүртгэл") OAuth endpoint at
// sso.gov.mn, following the protocol documented at
// https://developer.xyp.gov.mn/web/service-list. The `start` action here
// only builds the Authorization Request URL and records a pending
// `identity_verifications` row keyed by `state` — it does NOT get an
// access token or citizen data itself. The actual token exchange +
// citizen-info fetch happens in `dan-callback/index.ts`, the function
// registered with ХУР as `redirect_uri`, once the citizen has actually
// consented on sso.gov.mn's own page and their browser is redirected back
// with a `code`. That split is required by the protocol, not a choice —
// ХУР redirects the *citizen's browser*, which has no Supabase session to
// authenticate this function's normal `Authorization: Bearer` check, so
// the token exchange can't happen here.
//
// ⚠ UNVERIFIED AGAINST A CURRENT/AUTHORITATIVE SPEC — an external audit
// (Aug 2026) questioned whether this OAuth2-style flow (sso.gov.mn
// /oauth2/authorize + /oauth2/token + /oauth2/api/v1/service) is still
// the correct integration for a real ХУР "get citizen data" call in
// production. Follow-up research (same date) found live pages for BOTH
// of these, and could not fully resolve which one this project's actual
// registered integration is meant to use:
//   - developer.xyp.gov.mn describes a *different*, currently-published
//     mechanism for calling a named service like WS100101_getCitizenIDCardInfo:
//     SOAP/XML against https://xyp.gov.mn/service-1.5.0/ws?WSDL, authenticated
//     per-request via an `accessToken` + `timeStamp` + RSA-SHA256
//     `signature` header trio — not a Bearer token from an OAuth consent
//     redirect at all.
//   - developer.sso.gov.mn (current, distinct from the expired-cert
//     "old.developer.sso.gov.mn" mirror) does have its own live OAuth 2.0
//     docs section, consistent with the flow implemented here — this may
//     be a genuinely separate, correct product (ДАН citizen login/consent)
//     from XYP's service-oriented data-exchange API (used *after*
//     authentication to actually pull registry data), in which case
//     nothing here is wrong, just under-documented publicly.
// This project has no confirmed, ministry-issued integration spec to
// check the above against (registering as a ХУР integrator requires a
// formal request to Цахим хөгжил, харилцаа холбооны яам per
// datacenter.gov.mn/service/dan — not something obtainable from public
// docs alone). Do NOT flip `DAN_AUTH_MODE=production` against a real
// citizen without first confirming this exact flow — endpoints, auth
// mechanism, and the WS100101 call — against whatever integration
// document ХУР actually issued for this project's registered client.
//
// Required Edge Function secrets (`supabase secrets set ...`, never
// committed):
//   DAN_AUTH_MODE=production
//   DAN_CLIENT_ID=<Client ID issued by ХУР for this integration>
//   DAN_CLIENT_SECRET=<Client Secret issued by ХУР>          (used only in dan-callback)
//   DAN_REDIRECT_URI=<this project's dan-callback function URL,
//                      exactly as registered with ХУР — e.g.
//                      https://YOUR-PROJECT.functions.supabase.co/dan-callback>
//
// `status` in production mode never calls ХУР itself — by the time the
// Flutter app polls, `dan-callback` has already written the real outcome
// (verified/failed) onto the `identity_verifications` row from the
// server-to-server token exchange; this action just reads that row back.
//
// PRIVACY: per this schema's own design (see `identity_verifications`'s
// table comment in `supabase/migrations/0001_init_schema.sql`), the raw
// citizen payload ХУР returns (name, register number, ID card fields) is
// never written to any table here — only `status`/`verified_at` and the
// bump to `profiles.verification_level`. If a future feature wants to use
// the verified name/register number for something (e.g. pre-filling a
// display name), that's a deliberate follow-up decision, not something to
// silently start persisting.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const DAN_MODE = Deno.env.get('DAN_AUTH_MODE') ?? 'mock';

// Defense-in-depth, same reasoning and same pattern as
// `wire-topup/index.ts`'s `handleMockComplete` guard (added after an
// external audit, Aug 2026, flagged both this function and wire-topup as
// "fail open into mock"): `DAN_MODE` defaults to 'mock' when simply
// unset, so a deployment that shipped real `DAN_CLIENT_ID`/
// `DAN_CLIENT_SECRET` secrets but forgot (or had a redeploy reset) the
// separate `DAN_AUTH_MODE` secret would otherwise silently keep taking
// the mock branch — and the mock `status` action auto-verifies on first
// poll, bumping `profiles.verification_level` with **no real ХУР check
// ever having happened**. Configured DAN credentials are themselves
// evidence this environment is meant to be real, regardless of whether
// the mode flag was also correctly set.
const DAN_CREDENTIALS_CONFIGURED = Boolean(Deno.env.get('DAN_CLIENT_ID') || Deno.env.get('DAN_CLIENT_SECRET'));
const DAN_MOCK_REFUSED = DAN_MODE !== 'production' && DAN_CREDENTIALS_CONFIGURED;

// service_structure per the ХУР integration guide's §1 example — only the
// citizen ID-card lookup is requested (no input params for that service).
// Re-check https://developer.xyp.gov.mn/web/service-list before going
// live: the guide's own examples mix `citizen-1.2.0` and `citizen-1.3.0`
// WSDL paths, so confirm the currently-published version for your
// registered client rather than trusting this constant blindly.
const DAN_SERVICE_STRUCTURE = [
  {
    services: ['WS100101_getCitizenIDCardInfo'],
    wsdl: 'https://xyp.gov.mn/citizen-1.3.0/ws?WSDL',
  },
];

function buildDanScope(): string {
  // base64(json_encode(service_structure)) — every field here is ASCII,
  // so plain `btoa` (not a UTF-8-safe variant) is fine.
  return btoa(JSON.stringify(DAN_SERVICE_STRUCTURE));
}

function randomState(): string {
  // A 32-byte random value, hex-encoded (64 chars) — matches the shape of
  // ХУР's own example `state` value. Unguessable and single-use: this
  // doubles as this function's CSRF defense, since `dan-callback` only
  // proceeds for a `state` that matches a `pending` row it (or rather,
  // this function) created.
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

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

  let body: { action?: string; session_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  if (body.action === 'start') {
    if (DAN_MODE !== 'mock') {
      const clientId = Deno.env.get('DAN_CLIENT_ID');
      const redirectUri = Deno.env.get('DAN_REDIRECT_URI');
      if (!clientId || !redirectUri) {
        // Misconfigured deployment (flipped to production without setting
        // the secrets it needs) — fail loudly rather than silently
        // falling back to mock behavior.
        return json({ error: 'dan_production_not_configured' }, 500);
      }

      const state = randomState();

      // Recorded *before* redirecting the citizen anywhere — `state` is
      // the only thing `dan-callback` will have to look this row up by
      // when ХУР redirects back, since that request carries no Supabase
      // session.
      const { error: insertError } = await supabase.from('identity_verifications').insert({
        user_id: user.id,
        level: 'dan',
        provider: 'dan',
        provider_session_id: state,
        status: 'pending',
      });
      if (insertError) return json({ error: 'create_failed' }, 500);

      const authorizeUrl = new URL('https://sso.gov.mn/oauth2/authorize');
      authorizeUrl.searchParams.set('response_type', 'code');
      authorizeUrl.searchParams.set('client_id', clientId);
      authorizeUrl.searchParams.set('redirect_uri', redirectUri);
      authorizeUrl.searchParams.set('scope', buildDanScope());
      authorizeUrl.searchParams.set('state', state);

      return json({
        session_id: state,
        consent_url: authorizeUrl.toString(),
        status: 'pending',
      });
    }

    if (DAN_MOCK_REFUSED) {
      console.error(
        'dan-verify: refusing mock start — DAN_CLIENT_ID/DAN_CLIENT_SECRET are configured but ' +
          'DAN_AUTH_MODE is not "production". Set DAN_AUTH_MODE=production, or unset the DAN ' +
          'credentials if this deployment is genuinely meant to stay in mock mode.',
      );
      return json({ error: 'not_in_mock_mode' }, 400);
    }

    const sessionId = `mock-dan-${user.id}-${crypto.randomUUID()}`;

    await supabase.from('identity_verifications').insert({
      user_id: user.id,
      level: 'dan',
      provider: 'dan',
      provider_session_id: sessionId,
      status: 'pending',
    });

    return json({
      session_id: sessionId,
      consent_url: `https://mock-dan.local/consent?session=${sessionId}`,
      status: 'pending',
    });
  }

  if (body.action === 'status') {
    const sessionId = body.session_id;
    if (!sessionId) return json({ error: 'missing_session_id' }, 400);

    if (DAN_MODE !== 'mock') {
      // No call to ХУР here — `dan-callback` already did the token
      // exchange and wrote the real outcome onto this row by the time the
      // app is polling. This is just a read.
      const { data: verification, error } = await supabase
        .from('identity_verifications')
        .select('status')
        .eq('provider_session_id', sessionId)
        .eq('user_id', user.id)
        .maybeSingle();

      if (error) return json({ error: 'lookup_failed' }, 500);
      if (!verification) return json({ error: 'session_not_found' }, 404);
      return json({ status: verification.status });
    }

    if (DAN_MOCK_REFUSED) {
      console.error('dan-verify: refusing mock status — see the "start" branch\'s identical guard/comment.');
      return json({ error: 'not_in_mock_mode' }, 400);
    }

    // Mock: deterministically verify on first status check.
    const { data: verification } = await supabase
      .from('identity_verifications')
      .update({ status: 'verified', verified_at: new Date().toISOString() })
      .eq('provider_session_id', sessionId)
      .eq('user_id', user.id)
      .select()
      .single();

    if (verification) {
      await supabase
        .from('profiles')
        .update({ verification_level: 1 }) // 1 = DAN verified, spec section 10
        .eq('user_id', user.id);
    }

    return json({ status: verification ? 'verified' : 'pending' });
  }

  return json({ error: 'invalid_action' }, 400);
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
