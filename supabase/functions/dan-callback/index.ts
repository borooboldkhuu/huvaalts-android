// ХУВААЛЦ — DAN (ХУР / sso.gov.mn) OAuth callback endpoint.
//
// This is the `redirect_uri` registered with ХУР for this integration
// (`DAN_REDIRECT_URI` — must match exactly). ХУР redirects the *citizen's
// browser* here after they consent (or decline) on sso.gov.mn's own
// consent page — see `dan-verify/index.ts`'s header comment for how the
// two functions split the OAuth flow and why it has to split that way.
//
// DIFFERENT FROM EVERY OTHER FUNCTION IN THIS PROJECT: this one is called
// directly by a citizen's browser via a 302 redirect, not by the Flutter
// app via `supabase.functions.invoke`. There is no Supabase session/JWT
// on this request — it must be deployed with JWT verification disabled:
//
//   supabase functions deploy dan-callback --no-verify-jwt
//
// (or the equivalent `[functions.dan-callback] verify_jwt = false` in
// `supabase/config.toml`). Without that flag, Supabase's platform-level
// auth check rejects the request with 401 before this code ever runs, and
// ХУР gets an error page instead of the citizen.
//
// Identity here is established entirely by `state`: `dan-verify`'s
// `start` action generated an unguessable, single-use value and recorded
// it on a `pending` `identity_verifications` row before ever sending the
// citizen to sso.gov.mn. If the `state` this request carries doesn't
// match exactly one `pending` row, the request is rejected outright —
// that check *is* this endpoint's CSRF/replay defense, standing in for
// the client-side `state`-equality check a normal OAuth redirect flow
// would do (there is no "client" here to do it).
//
// ⚠ See `dan-verify/index.ts`'s header comment for an unresolved
// question about whether this OAuth2 flow (sso.gov.mn) is actually the
// currently-correct way to reach WS100101_getCitizenIDCardInfo in
// production, versus XYP's separate signature-based service API —
// confirm against your own registered integration's documentation
// before relying on this in production.
//
// PRIVACY: the citizen payload ХУР returns (name, register number, ID
// card fields) is read only long enough to check success/failure and to
// cross-check `regnum` against the self-reported `identity_details` row
// (see the success path below) — neither the raw payload nor any of its
// individual fields are ever written to a table.
//
// WHAT THE CITIZEN SEES: a small static HTML page (no app UI, no build
// step — this runs outside the Flutter app entirely) telling them to
// return to the app, plus a best-effort attempt to reopen it via a
// `huvalts://` deep link. That scheme is NOT registered yet — this repo
// has no `android`/`ios` platform projects (see README "Known issues"),
// so there's nowhere to add the intent-filter / `CFBundleURLSchemes`
// entry until `flutter create` has been run locally. Until then this is
// a harmless no-op (the browser just doesn't know the scheme) and the
// flow still works correctly: `VerificationScreen`'s existing "I've
// completed consent" button (see its header comment) already re-triggers
// a status poll when the citizen manually switches back to the app, and
// by then this function has long since finished writing the real
// verified/failed outcome. Wiring the deep link is a pure UX
// enhancement (auto-resume instead of a manual tap) for later, not a
// correctness requirement — deliberately not bundling a new deep-link
// package/native config into this change untested.

import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const danError = url.searchParams.get('error');

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // The citizen declined consent, or ХУР reported some other
  // authorization-stage error — nothing to exchange, just record it.
  if (danError || !code || !state) {
    if (state) {
      await supabase
        .from('identity_verifications')
        .update({ status: 'cancelled' })
        .eq('provider_session_id', state)
        .eq('status', 'pending');
    }
    return htmlResponse(failureHtml());
  }

  // Look up the pending row this `state` was minted for. Anything else —
  // no match, already resolved, expired — is treated as invalid rather
  // than guessed at; a `pending` row is only ever consumed once.
  const { data: verification, error: lookupError } = await supabase
    .from('identity_verifications')
    .select('id, user_id')
    .eq('provider_session_id', state)
    .eq('status', 'pending')
    .maybeSingle();

  if (lookupError || !verification) {
    return htmlResponse(failureHtml());
  }

  const clientId = Deno.env.get('DAN_CLIENT_ID');
  const clientSecret = Deno.env.get('DAN_CLIENT_SECRET');
  const redirectUri = Deno.env.get('DAN_REDIRECT_URI');
  if (!clientId || !clientSecret || !redirectUri) {
    console.error('dan-callback: missing DAN_CLIENT_ID/DAN_CLIENT_SECRET/DAN_REDIRECT_URI secret');
    await markFailed(supabase, verification.id);
    return htmlResponse(failureHtml());
  }

  try {
    // 1. Exchange the one-time authorization code for an access token —
    // server-to-server, the citizen's browser is not involved in this
    // request.
    const tokenBody = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      client_id: clientId,
    });
    const tokenRes = await fetch('https://sso.gov.mn/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: tokenBody.toString(),
    });
    if (!tokenRes.ok) {
      console.error('dan-callback: token exchange failed', tokenRes.status, await safeText(tokenRes));
      await markFailed(supabase, verification.id);
      return htmlResponse(failureHtml());
    }
    const tokenJson = (await tokenRes.json()) as { access_token?: string };
    const accessToken = tokenJson.access_token;
    if (!accessToken) {
      console.error('dan-callback: token response had no access_token');
      await markFailed(supabase, verification.id);
      return htmlResponse(failureHtml());
    }

    // 2. Use the access token to fetch the citizen data the granted scope
    // covers (just the ID-card lookup — see `dan-verify`'s
    // DAN_SERVICE_STRUCTURE). This is the one place the raw citizen
    // payload exists — read the success flag and discard the rest; see
    // this file's header comment on why nothing else from it gets
    // persisted.
    //
    // Confirmed product decision: WS100101_getCitizenIDCardInfo's full
    // response (firstname/lastname/surname, regnum, civilId, birthDate,
    // address fields, the ID photo, etc. — see ХУР's service docs for the
    // complete field list) is used for verification only, matching this
    // schema's existing privacy stance. Only `resultCode` is read below;
    // nothing else from `response` is even parsed. If a future feature
    // wants any of those fields (e.g. pre-filling `profiles.display_name`
    // from `firstname`/`lastname`), that's a deliberate follow-up with
    // its own review — not something to start doing quietly here.
    //
    // Per the OAuth flow's own example (not the general service
    // catalogue's input/output table, which also documents a
    // civilID/regnum *input* for this service), WS100101 is called here
    // with no request params — the citizen is already identified by
    // having authenticated on sso.gov.mn during the consent step, so ХУР
    // resolves "this service, for whoever just logged in" rather than
    // needing civilID/regnum supplied. If ХУР ever requires those two as
    // explicit params for this integration, add them to `dan-verify`'s
    // `DAN_SERVICE_STRUCTURE['params']` — nothing here would need to
    // change beyond that.
    const serviceRes = await fetch('https://sso.gov.mn/oauth2/api/v1/service', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!serviceRes.ok) {
      console.error('dan-callback: service call failed', serviceRes.status, await safeText(serviceRes));
      await markFailed(supabase, verification.id);
      return htmlResponse(failureHtml());
    }
    const serviceJson = (await serviceRes.json()) as Array<{
      services?: Record<string, Record<string, unknown> & { resultCode?: number }>;
    }>;
    const citizenResult = serviceJson
      .flatMap((entry) => (entry.services ? Object.values(entry.services) : []))
      .find((s) => typeof s.resultCode === 'number');
    const verified = citizenResult?.resultCode === 0;

    if (!verified) {
      await markFailed(supabase, verification.id);
      return htmlResponse(failureHtml());
    }

    // Anti-fraud cross-check (added after an external audit, Aug 2026,
    // flagged its absence): `resultCode === 0` only proves *some* citizen
    // successfully authenticated on ХУР's own consent page — it does NOT
    // prove that citizen is the same person who typed a surname/given
    // name/register number into this app's own registration form
    // (`identity_details`, 0017). Without this check, a user could
    // register under a fabricated or someone else's name/regnum, then
    // complete DAN consent as themselves, and still walk away with a
    // "DAN verified" badge attached to the fabricated identity. Compares
    // ХУР's own regnum for the authenticated citizen (if this response
    // shape includes one findable by `extractRegnum` below — see this
    // file's header comment on why the exact shape isn't confirmed)
    // against what this user self-reported; mismatch fails verification
    // instead of silently trusting `resultCode` alone. Per this file's
    // existing privacy stance, the regnum is used only for this
    // comparison and never itself written to any table.
    const returnedRegnum = extractRegnum(citizenResult);
    if (returnedRegnum) {
      const { data: selfReported } = await supabase
        .from('identity_details')
        .select('register_number')
        .eq('user_id', verification.user_id)
        .maybeSingle();
      if (!selfReported) {
        console.error(
          'dan-callback: no identity_details row for user',
          verification.user_id,
          '— nothing to cross-check the ХУР-authenticated regnum against; proceeding without it.',
        );
      } else if (normalizeRegnum(selfReported.register_number as string) !== normalizeRegnum(returnedRegnum)) {
        console.error(
          'dan-callback: regnum mismatch for user',
          verification.user_id,
          '— self-reported identity_details does not match the ХУР-authenticated citizen.',
        );
        await markFailed(supabase, verification.id);
        return htmlResponse(failureHtml());
      }
    } else {
      // Shape genuinely uncertain (see header comment) — logged loudly
      // rather than silently accepted, so a real production response
      // that DOES carry a parseable regnum gets noticed and
      // `extractRegnum` extended, instead of this check quietly never
      // actually running.
      console.error(
        'dan-callback: could not locate a regnum field in the WS100101 response shape for user',
        verification.user_id,
        '— identity cross-check skipped for this verification.',
      );
    }

    // `.eq('status', 'pending')` guard: two near-simultaneous deliveries
    // of the same callback (a double-fire from a browser prefetcher or
    // retry) both pass the earlier `.eq('status', 'pending')` lookup
    // before either writes. Without this guard, if one delivery reached
    // this success path while the other's token exchange failed and
    // called `markFailed` (below), whichever write landed last would win
    // — possibly reverting an already-verified row back to 'failed' while
    // `profiles.verification_level` stayed bumped, an inconsistent state.
    // This mirrors the pattern the cancellation branch above already used
    // for the same reason.
    await supabase
      .from('identity_verifications')
      .update({ status: 'verified', verified_at: new Date().toISOString() })
      .eq('id', verification.id)
      .eq('status', 'pending');

    await supabase
      .from('profiles')
      .update({ verification_level: 1 }) // 1 = DAN verified, spec section 10
      .eq('user_id', verification.user_id);

    return htmlResponse(successHtml());
  } catch (e) {
    console.error('dan-callback: unexpected error', e);
    await markFailed(supabase, verification.id);
    return htmlResponse(failureHtml());
  }
});

async function markFailed(
  supabase: ReturnType<typeof createClient>,
  verificationId: string,
): Promise<void> {
  // `.eq('status', 'pending')` guard — see the success path's identical
  // comment above. Without it, a failure racing behind an already-
  // successful verification on the same row could revert it, leaving
  // `identity_verifications.status = 'failed'` while
  // `profiles.verification_level` stays bumped from the success path.
  await supabase
    .from('identity_verifications')
    .update({ status: 'failed' })
    .eq('id', verificationId)
    .eq('status', 'pending');
}

// Defensive extraction — the exact field name/casing for a citizen's
// register number in a WS100101_getCitizenIDCardInfo response is not
// confirmed against a real payload (see this file's header comment on
// why); tries the plausible names/nesting from the ХУР guide's own
// examples rather than assuming one, the same "uncertain external shape"
// pattern `wire-topup-webhook/index.ts`'s `extractPaymentIntent` uses.
function extractRegnum(service: Record<string, unknown> | undefined): string | undefined {
  if (!service || typeof service !== 'object') return undefined;
  const candidates = ['regnum', 'regNum', 'registerNumber', 'register_number', 'civilId', 'civilID'];
  for (const key of candidates) {
    const value = service[key];
    if (typeof value === 'string' && value.trim().length > 0) return value;
  }
  // Some ХУР response shapes nest the actual citizen fields one level
  // deeper under `result`/`data` rather than flat on the service object.
  const nested = (service.result as Record<string, unknown> | undefined) ?? (service.data as Record<string, unknown> | undefined);
  if (nested && typeof nested === 'object') {
    return extractRegnum(nested);
  }
  return undefined;
}

function normalizeRegnum(value: string): string {
  return value.replace(/\s+/g, '').toUpperCase();
}

async function safeText(res: Response): Promise<string> {
  try {
    return await res.text();
  } catch {
    return '';
  }
}

function htmlResponse(body: string): Response {
  return new Response(body, { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

// Static copy only — nothing from the request (code/state/error) is ever
// interpolated into these pages, so there's no reflected-content risk to
// sanitize against.
function pageShell(message: string, sub: string): string {
  return `<!doctype html>
<html lang="mn">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ХУВААЛЦ — Баталгаажуулалт</title>
<style>
  body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; background: #F7F7F5; color: #111;
         display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; }
  .card { max-width: 360px; text-align: center; }
  h1 { font-size: 20px; margin-bottom: 8px; }
  p { color: #6B6B6B; font-size: 15px; line-height: 1.5; }
</style>
<script>
  // Best-effort auto-return to the app — harmless no-op until the
  // \`huvalts://\` scheme is registered in the native projects (see this
  // file's header comment). Not required for the flow to work correctly.
  try { window.location.href = 'huvalts://dan-callback'; } catch (e) {}
</script>
</head>
<body>
  <div class="card">
    <h1>${message}</h1>
    <p>${sub}</p>
  </div>
</body>
</html>`;
}

function successHtml(): string {
  return pageShell('Баталгаажуулалт амжилттай боллоо', 'Та ХУВААЛЦ апп руу буцаж болно.');
}

function failureHtml(): string {
  return pageShell(
    'Баталгаажуулалт амжилтгүй боллоо',
    'Та ХУВААЛЦ апп руу буцаад дахин оролдоно уу.',
  );
}
