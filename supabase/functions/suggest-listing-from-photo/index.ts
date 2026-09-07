// ХУВААЛЦ — AI listing assistant backend endpoint (Phase 10, spec sections
// 14, 51: "AI listing assistant — auto-fill listing details from photos").
//
// Same posture as dan-verify and initiate-payment/mock-complete-payment:
// the Flutter app never talks to a vision API directly (no such API key
// belongs in the client binary), it always calls this function, and this
// function's own AI_LISTING_MODE secret decides whether it answers with
// an honest mock or a real provider — the Flutter side
// (SupabaseListingAssistantRepository) never changes when that flips.
//
// STATUS: AI_LISTING_MODE defaults to 'mock'. No vision-capable API key
// was available when this was written, so this does NOT pretend to
// recognize what's in a photo — that would violate this project's "never
// claim a feature works unless it actually does" rule. The mock branch
// below is honest about that limit: it returns a *structural* prefill
// (a fill-in-the-blanks description template, a neutral default
// condition, and a list of spec *field names* worth filling in — never
// fabricated field *values*, since nothing here actually looked at pixel
// content) rather than inventing a plausible-sounding title/brand/model
// out of nothing. It still logs every call (`ai_listing_suggestions`) and
// enforces a rate limit, since that's real infrastructure a production
// vision integration would need on day one regardless of which provider
// answers.
//
// TO GO LIVE: set the `AI_LISTING_MODE=production` Edge Function secret,
// add whatever provider API key it needs as its own secret, and replace
// the `TODO(production)` branch below with a real call — decode `photos`
// (already base64 in the request body), send them to a vision-capable
// model, and map its response onto the same
// `{ titleSuggestion, descriptionSuggestion, conditionSuggestion,
// suggestedSpecFields }` shape the mock branch returns, so
// `ListingSuggestion.fromJson` on the Flutter side doesn't need to change.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const AI_LISTING_MODE = Deno.env.get('AI_LISTING_MODE') ?? 'mock';

// Deliberately generous since mock mode costs nothing real — this exists
// so the rate-limit *mechanism* is in place and tested before a real,
// actually-expensive provider is ever wired in, not because mock calls
// need throttling today. Revisit downward once AI_LISTING_MODE=production
// has a real per-call cost.
const MAX_CALLS_PER_DAY = 30;

const MAX_PHOTOS_PER_CALL = 3;

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

  let body: { photos?: string[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  const photos = Array.isArray(body.photos) ? body.photos.slice(0, MAX_PHOTOS_PER_CALL) : [];
  if (photos.length === 0) {
    return json({ error: 'at_least_one_photo_required' }, 400);
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countError } = await supabase
    .from('ai_listing_suggestions')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', since);

  if (countError) {
    return json({ error: 'rate_limit_check_failed' }, 500);
  }
  if ((count ?? 0) >= MAX_CALLS_PER_DAY) {
    return json({ error: 'rate_limited' }, 429);
  }

  if (AI_LISTING_MODE !== 'mock') {
    // TODO(production): send `photos` (base64) to a real vision-capable
    // model and map its response onto the shape returned below.
    return json({ error: 'ai_listing_production_adapter_not_implemented' }, 501);
  }

  await supabase.from('ai_listing_suggestions').insert({
    user_id: user.id,
    photo_count: photos.length,
    mock: true,
  });

  const photoWord = photos.length === 1 ? 'зурган дээр' : `${photos.length} зурган дээр`;

  return json({
    mock: true,
    title_suggestion: null,
    description_suggestion:
      `Энэ ${photoWord} үндэслэн: юу болохыг, ямар зориулалттайг, ` +
      'болон онцлог давуу талыг дурдана уу.',
    condition_suggestion: 'good',
    suggested_spec_fields: ['brand', 'model', 'color', 'year'],
  });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
