-- ХУВААЛЦ — AI listing assistant usage log + rate limit (Phase 10, spec
-- sections 14, 51: "AI listing assistant — auto-fill listing details from
-- photos").
--
-- This table exists for one reason: the `suggest-listing-from-photo` Edge
-- Function is the first endpoint in this project that would call an
-- expensive third-party API per request once a real vision provider is
-- wired in (spec section 51's "implement the adapter/interface and a safe
-- mock environment" — see that function's own header comment for why it's
-- mock-only today, same story as DAN and payments). Nothing before this
-- needed server-side rate limiting; this does, so it doesn't stay a
-- documented gap the way earlier "still to build" lists called out for
-- other endpoints. `mock` records whether a given call actually reached a
-- real provider or the mock branch, so a real-provider cost/usage report
-- later doesn't double-count mock-mode calls that cost nothing.

create table public.ai_listing_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  photo_count int not null check (photo_count >= 0),
  mock boolean not null,
  created_at timestamptz not null default now()
);

create index ai_listing_suggestions_user_id_created_at_idx
  on public.ai_listing_suggestions (user_id, created_at);

alter table public.ai_listing_suggestions enable row level security;

-- Read-only for the client — lets the create-listing screen show
-- "X requests left today" without a round trip through the Edge
-- Function. No insert/update/delete policy at all: only the Edge
-- Function's service-role client writes here, since a client-writable
-- rate-limit log would let anyone bypass the limit it exists to enforce.
create policy ai_listing_suggestions_select_own on public.ai_listing_suggestions
  for select using (user_id = auth.uid());
