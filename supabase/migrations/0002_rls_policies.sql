-- ХУВААЛЦ — Row Level Security
-- Principle (spec section 32): users can read public assets; edit only
-- their own assets; read only their own private bookings; access only
-- their own wallet; access conversations they belong to. Admins get
-- elevated access through `public.admin_users` + these policies, never
-- through a client-supplied flag. Service-role (used only by Edge
-- Functions) bypasses RLS entirely per Supabase default — never expose
-- the service-role key to Flutter (spec section 32/34).

create or replace function public.is_admin(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_users a where a.user_id = uid);
$$;

-- ---------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.identity_verifications enable row level security;
alter table public.categories enable row level security;
alter table public.assets enable row level security;
alter table public.asset_images enable row level security;
alter table public.asset_availability enable row level security;
alter table public.asset_rules enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_items enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.payouts enable row level security;
alter table public.reviews enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.condition_reports enable row level security;
alter table public.disputes enable row level security;
alter table public.favorites enable row level security;
alter table public.reports enable row level security;
alter table public.promotions enable row level security;
alter table public.admin_users enable row level security;
alter table public.audit_logs enable row level security;

-- ---------------------------------------------------------------------
-- users / profiles
-- ---------------------------------------------------------------------

create policy users_select_own on public.users
  for select using (id = auth.uid() or public.is_admin(auth.uid()));

create policy users_update_own on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());

-- Profiles are the *public* view — readable by anyone (signed in or not),
-- editable only by the owner.
create policy profiles_select_all on public.profiles
  for select using (true);

create policy profiles_update_own on public.profiles
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy profiles_insert_own on public.profiles
  for insert with check (user_id = auth.uid());

-- Identity verification rows are private — never publicly listable, and
-- never expose national ID / raw provider payload even to the owner
-- (those fields don't exist on this table — only status/level).
create policy identity_verifications_select_own on public.identity_verifications
  for select using (user_id = auth.uid() or public.is_admin(auth.uid()));

create policy identity_verifications_insert_own on public.identity_verifications
  for insert with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- categories (public reference data — admin-managed)
-- ---------------------------------------------------------------------

create policy categories_select_all on public.categories
  for select using (true);

create policy categories_admin_write on public.categories
  for all using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- assets (spec section 32: read public assets; edit only own)
-- ---------------------------------------------------------------------

create policy assets_select_published_or_own on public.assets
  for select using (
    status = 'published' or owner_id = auth.uid() or public.is_admin(auth.uid())
  );

create policy assets_insert_own on public.assets
  for insert with check (owner_id = auth.uid());

create policy assets_update_own on public.assets
  for update using (owner_id = auth.uid() or public.is_admin(auth.uid()))
  with check (owner_id = auth.uid() or public.is_admin(auth.uid()));

create policy assets_delete_own on public.assets
  for delete using (owner_id = auth.uid() or public.is_admin(auth.uid()));

-- asset_images / asset_availability / asset_rules follow the parent asset's
-- visibility — public if the asset is published, editable only by owner.

create policy asset_images_select on public.asset_images
  for select using (
    exists (
      select 1 from public.assets a
      where a.id = asset_images.asset_id
        and (a.status = 'published' or a.owner_id = auth.uid() or public.is_admin(auth.uid()))
    )
  );

create policy asset_images_write_own on public.asset_images
  for all using (
    exists (select 1 from public.assets a where a.id = asset_images.asset_id and a.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.assets a where a.id = asset_images.asset_id and a.owner_id = auth.uid())
  );

create policy asset_availability_select on public.asset_availability
  for select using (
    exists (
      select 1 from public.assets a
      where a.id = asset_availability.asset_id
        and (a.status = 'published' or a.owner_id = auth.uid() or public.is_admin(auth.uid()))
    )
  );

create policy asset_availability_write_own on public.asset_availability
  for all using (
    exists (select 1 from public.assets a where a.id = asset_availability.asset_id and a.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.assets a where a.id = asset_availability.asset_id and a.owner_id = auth.uid())
  );

create policy asset_rules_select on public.asset_rules
  for select using (
    exists (
      select 1 from public.assets a
      where a.id = asset_rules.asset_id
        and (a.status = 'published' or a.owner_id = auth.uid() or public.is_admin(auth.uid()))
    )
  );

create policy asset_rules_write_own on public.asset_rules
  for all using (
    exists (select 1 from public.assets a where a.id = asset_rules.asset_id and a.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.assets a where a.id = asset_rules.asset_id and a.owner_id = auth.uid())
  );

-- ---------------------------------------------------------------------
-- bookings (spec section 32: read only own private bookings)
-- ---------------------------------------------------------------------

create policy bookings_select_participant on public.bookings
  for select using (
    renter_id = auth.uid() or owner_id = auth.uid() or public.is_admin(auth.uid())
  );

-- Bookings are created via a backend RPC/Edge Function (needs
-- authoritative price + availability recheck) in production; this policy
-- allows the renter-authenticated insert path while price fields are
-- still enforced by the CHECK/exclusion constraints in 0001.
create policy bookings_insert_renter on public.bookings
  for insert with check (renter_id = auth.uid());

create policy bookings_update_participant on public.bookings
  for update using (
    renter_id = auth.uid() or owner_id = auth.uid() or public.is_admin(auth.uid())
  );

create policy booking_items_select_participant on public.booking_items
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_items.booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid() or public.is_admin(auth.uid()))
    )
  );

-- ---------------------------------------------------------------------
-- payments (spec section 32/34: client never marks payment successful)
-- ---------------------------------------------------------------------

create policy payments_select_participant on public.payments
  for select using (
    payer_id = auth.uid()
    or exists (
      select 1 from public.bookings b
      where b.id = payments.booking_id and b.owner_id = auth.uid()
    )
    or public.is_admin(auth.uid())
  );

-- No client insert/update policy: payments are created and transitioned
-- exclusively by backend Edge Functions using the service-role key, after
-- verifying the payment provider's webhook signature. This is intentional
-- — the absence of an insert/update policy denies those operations to
-- authenticated clients by default under RLS.

create policy payment_events_select_admin on public.payment_events
  for select using (public.is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- wallet (spec section 32: access only own wallet)
-- ---------------------------------------------------------------------

create policy wallets_select_own on public.wallets
  for select using (user_id = auth.uid() or public.is_admin(auth.uid()));

-- No client write policy — wallet balances are mutated only by backend
-- functions reacting to confirmed payment/payout events (spec section 34:
-- never trust client-side wallet balance).

create policy wallet_transactions_select_own on public.wallet_transactions
  for select using (wallet_user_id = auth.uid() or public.is_admin(auth.uid()));

create policy payouts_select_own on public.payouts
  for select using (user_id = auth.uid() or public.is_admin(auth.uid()));

create policy payouts_insert_own on public.payouts
  for insert with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- reviews
-- ---------------------------------------------------------------------

create policy reviews_select_all on public.reviews
  for select using (true);

create policy reviews_insert_participant on public.reviews
  for insert with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.bookings b
      where b.id = reviews.booking_id
        and b.status = 'completed'
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------------
-- chat (spec section 32: access only conversations they belong to)
-- ---------------------------------------------------------------------

create policy conversations_select_member on public.conversations
  for select using (
    exists (
      select 1 from public.conversation_members m
      where m.conversation_id = conversations.id and m.user_id = auth.uid()
    )
  );

create policy conversation_members_select_own on public.conversation_members
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.conversation_members m2
      where m2.conversation_id = conversation_members.conversation_id and m2.user_id = auth.uid()
    )
  );

create policy conversation_members_update_own on public.conversation_members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy messages_select_member on public.messages
  for select using (
    exists (
      select 1 from public.conversation_members m
      where m.conversation_id = messages.conversation_id and m.user_id = auth.uid()
    )
  );

create policy messages_insert_member on public.messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversation_members m
      where m.conversation_id = messages.conversation_id
        and m.user_id = auth.uid()
        and m.is_blocked = false
    )
  );

-- ---------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------

create policy notifications_select_own on public.notifications
  for select using (user_id = auth.uid());

create policy notifications_update_own on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- condition reports / disputes / reports / favorites
-- ---------------------------------------------------------------------

create policy condition_reports_select_participant on public.condition_reports
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = condition_reports.booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid() or public.is_admin(auth.uid()))
    )
  );

create policy condition_reports_insert_participant on public.condition_reports
  for insert with check (
    submitted_by = auth.uid()
    and exists (
      select 1 from public.bookings b
      where b.id = condition_reports.booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

create policy disputes_select_participant on public.disputes
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = disputes.booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
    or public.is_admin(auth.uid())
  );

create policy disputes_insert_participant on public.disputes
  for insert with check (
    raised_by = auth.uid()
    and exists (
      select 1 from public.bookings b
      where b.id = disputes.booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

create policy disputes_update_admin on public.disputes
  for update using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

create policy favorites_select_own on public.favorites
  for select using (user_id = auth.uid());

create policy favorites_write_own on public.favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy reports_insert_own on public.reports
  for insert with check (reporter_id = auth.uid());

create policy reports_select_own_or_admin on public.reports
  for select using (reporter_id = auth.uid() or public.is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- promotions (public read of active promos; admin write)
-- ---------------------------------------------------------------------

create policy promotions_select_active on public.promotions
  for select using (is_active = true or public.is_admin(auth.uid()));

create policy promotions_admin_write on public.promotions
  for all using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- admin_users / audit_logs — admin-only, no client self-service
-- ---------------------------------------------------------------------

create policy admin_users_select_admin on public.admin_users
  for select using (public.is_admin(auth.uid()));

create policy audit_logs_select_admin on public.audit_logs
  for select using (public.is_admin(auth.uid()));

-- No insert/update/delete policies for admin_users or audit_logs from the
-- client role at all — both are written exclusively by backend
-- Edge Functions using the service-role key (spec sections 30, 32).
