-- ХУВААЛЦ — admin dashboard backend (Phase 11, spec sections 22, 29, 30,
-- 34). Every earlier phase that flagged something as "waiting on the
-- admin dashboard" gets closed here:
--
-- 1. Asset moderation (Phase 3's own header comment on `createAsset`:
--    "Revisit this default once admin approval exists"). New listings no
--    longer publish immediately — they land in `pending_review` and stay
--    invisible to everyone but their owner and admins until approved.
--    This also closes a real, previously-undocumented gap: nothing ever
--    stopped a client from setting `assets.status` to `'published'`
--    directly via `assets_update_own`'s RLS (owner-writable, no column
--    restriction) — a trigger below is the first thing in this schema to
--    actually gate that column.
-- 2. Commission settings (Phase 4's `create_booking` hardcoded 10%,
--    "TODO(Phase 11): source this from an admin-configurable settings
--    table once one exists"). `platform_settings` is that table.
-- 3. Payout *processing* (Phase 7 only ever built the request side —
--    `payouts` could reach `pending` and nothing further).
--    `admin_process_payout` is what finally moves one to
--    `processing`/`paid`/`failed` and, on `paid`, actually deducts
--    `available_balance`.
-- 4. Dispute resolution (Phase 9's `restore_booking_status_after_dispute_resolution`
--    reacts correctly to `disputes.status` changing, but nothing besides
--    direct database access could ever change it).
--    `admin_resolve_dispute` is that action now — and replaces
--    `disputes_update_admin`'s direct-RLS-write path entirely, since a
--    direct write bypassed `audit_logs` (spec section 30: "every
--    sensitive admin action must write here" — true in the *comment*
--    since Phase 0, never actually enforced for admin table writes until
--    now).
-- 5. Abuse/content report resolution (`reports`, spec section 26) — same
--    "existed since Phase 0/1, never had an admin action wired to it"
--    story.
--
-- Every RPC below shares one shape: `security definer`, checks
-- `public.is_admin(auth.uid())` itself (not just relying on a `grant`),
-- and calls `log_admin_action` before returning — so an admin action that
-- doesn't get logged is a bug in this file, not something an admin could
-- ever cause by skipping a step.

-- ---------------------------------------------------------------------
-- Shared audit-logging helper
-- ---------------------------------------------------------------------
--
-- Deliberately NOT granted to `authenticated` (or left at Postgres's
-- default grant-to-public for new functions) — only the admin RPCs below
-- call it, from inside their own `security definer` context, which
-- doesn't need an explicit grant (a function's owner can always execute
-- functions it owns). Letting a client call this directly would only
-- ever let them log a fake, misleading entry attributed to themselves —
-- not a privilege escalation, but pointless to allow.
create or replace function public.log_admin_action(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (actor_id, action, target_type, target_id, metadata)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_metadata);
end;
$$;

revoke all on function public.log_admin_action(text, text, uuid, jsonb) from public;

-- ---------------------------------------------------------------------
-- Asset moderation
-- ---------------------------------------------------------------------

alter table public.assets add column if not exists moderation_note text;

comment on column public.assets.moderation_note is
  'Set by admin_reject_asset/admin_suspend_asset with the reason shown to '
  'the owner; cleared by resubmit_asset_for_review and admin_approve_asset.';

-- The gap this closes: assets_update_own (0002) lets an owner UPDATE any
-- column on their own asset, status included — nothing ever stopped
-- `.update({'status': 'published'})` from the client. This trigger is
-- the actual enforcement: every new asset lands in pending_review
-- regardless of what the client sent, and after that, status can only
-- change via an admin action or the one self-service transition an owner
-- legitimately needs (resubmitting a rejected listing).
create or replace function public.enforce_asset_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'pending_review';
    return new;
  end if;

  -- tg_op = 'UPDATE'
  if new.status is distinct from old.status then
    if public.is_admin(auth.uid()) then
      -- admin RPCs below are the only intended callers of an
      -- admin-driven transition; this still allows it either way since
      -- an admin acting through some future direct path shouldn't be
      -- blanket-blocked by this trigger.
      null;
    elsif auth.uid() = old.owner_id and old.status = 'draft' and new.status = 'pending_review' then
      -- resubmit_asset_for_review's only job.
      null;
    else
      raise exception 'not_authorized_status_change';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_asset_status_transition on public.assets;
create trigger enforce_asset_status_transition
  before insert or update on public.assets
  for each row execute function public.enforce_asset_status_transition();

-- `asset_cards` (0004) already respects RLS via `security_invoker`, so an
-- admin querying it already sees every status (assets_select_published_or_own
-- includes `public.is_admin(auth.uid())`) — it just didn't expose
-- `moderation_note` yet. Re-declared here with that one column appended;
-- every other column is identical to 0004's definition, in the same
-- order, so nothing that already selects from this view breaks.
create or replace view public.asset_cards
with (security_invoker = true)
as
select
  a.id,
  a.owner_id,
  a.category_id,
  a.title,
  a.price_per_hour,
  a.price_per_day,
  a.price_per_week,
  coalesce(a.price_per_day, a.price_per_hour, a.price_per_week) as display_price,
  a.deposit_amount,
  a.currency,
  a.latitude,
  a.longitude,
  a.location_label,
  a.status,
  a.is_featured,
  a.view_count,
  a.favorite_count,
  a.created_at,
  p.display_name as owner_display_name,
  p.verification_level as owner_verification_level,
  (
    select ai.storage_path
    from public.asset_images ai
    where ai.asset_id = a.id
    order by ai.sort_order asc
    limit 1
  ) as primary_image_path,
  coalesce(
    (
      select avg(r.rating)::numeric(3, 2)
      from public.reviews r
      join public.bookings b on b.id = r.booking_id
      where b.asset_id = a.id
    ),
    0
  ) as asset_rating,
  (
    select count(*)
    from public.reviews r
    join public.bookings b on b.id = r.booking_id
    where b.asset_id = a.id
  ) as asset_review_count,
  a.moderation_note
from public.assets a
join public.profiles p on p.user_id = a.owner_id;

comment on view public.asset_cards is
  'Read-optimized projection for browse/search cards, and (as of Phase 11) '
  'the admin moderation queue — an admin session sees every status via '
  'security_invoker RLS, not just published. Not writable — write '
  'through public.assets directly.';

create or replace function public.admin_approve_asset(p_asset_id uuid)
returns public.assets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset public.assets;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;

  update public.assets
    set status = 'published', moderation_note = null
    where id = p_asset_id and status = 'pending_review'
    returning * into v_asset;

  if not found then
    raise exception 'asset_not_pending_review';
  end if;

  perform public.log_admin_action('asset.approve', 'asset', p_asset_id, '{}'::jsonb);

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  values (v_asset.owner_id, 'asset_approved', 'Listing approved', v_asset.title, '/asset/' || v_asset.id);

  return v_asset;
end;
$$;

revoke all on function public.admin_approve_asset(uuid) from public;
grant execute on function public.admin_approve_asset(uuid) to authenticated;

create or replace function public.admin_reject_asset(p_asset_id uuid, p_reason text)
returns public.assets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset public.assets;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'reason_required';
  end if;

  update public.assets
    set status = 'draft', moderation_note = p_reason
    where id = p_asset_id and status = 'pending_review'
    returning * into v_asset;

  if not found then
    raise exception 'asset_not_pending_review';
  end if;

  perform public.log_admin_action('asset.reject', 'asset', p_asset_id, jsonb_build_object('reason', p_reason));

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  values (v_asset.owner_id, 'asset_rejected', 'Listing needs changes', p_reason, '/asset/' || v_asset.id);

  return v_asset;
end;
$$;

revoke all on function public.admin_reject_asset(uuid, text) from public;
grant execute on function public.admin_reject_asset(uuid, text) to authenticated;

-- For a listing that was live and later found to violate the rules —
-- distinct from a reject, which only ever applies to a not-yet-published
-- listing still in pending_review.
create or replace function public.admin_suspend_asset(p_asset_id uuid, p_reason text)
returns public.assets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asset public.assets;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'reason_required';
  end if;

  update public.assets
    set status = 'suspended', moderation_note = p_reason
    where id = p_asset_id and status = 'published'
    returning * into v_asset;

  if not found then
    raise exception 'asset_not_published';
  end if;

  perform public.log_admin_action('asset.suspend', 'asset', p_asset_id, jsonb_build_object('reason', p_reason));

  insert into public.notifications (user_id, event_type, title, body, deep_link)
  values (v_asset.owner_id, 'asset_suspended', 'Listing suspended', p_reason, '/asset/' || v_asset.id);

  return v_asset;
end;
$$;

revoke all on function public.admin_suspend_asset(uuid, text) from public;
grant execute on function public.admin_suspend_asset(uuid, text) to authenticated;

-- Owner-facing, not admin-facing: the only self-service status change
-- enforce_asset_status_transition allows. Also clears the old rejection
-- note, since it no longer describes the (presumably now-edited) listing.
create or replace function public.resubmit_asset_for_review(p_asset_id uuid)
returns public.assets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_asset public.assets;
begin
  if v_uid is null then
    raise exception 'auth_required';
  end if;

  update public.assets
    set status = 'pending_review', moderation_note = null
    where id = p_asset_id and owner_id = v_uid and status = 'draft'
    returning * into v_asset;

  if not found then
    raise exception 'asset_not_rejected';
  end if;

  return v_asset;
end;
$$;

revoke all on function public.resubmit_asset_for_review(uuid) from public;
grant execute on function public.resubmit_asset_for_review(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Commission settings
-- ---------------------------------------------------------------------
--
-- Single-row table (`id` pinned to 1 by the check constraint) rather than
-- a generic key/value settings table — commission is the only
-- admin-configurable platform setting spec section 20 actually asks for
-- this phase; a broader settings table can grow from this one later
-- without a breaking migration.
create table public.platform_settings (
  id smallint primary key default 1 check (id = 1),
  commission_percent numeric(5, 2) not null default 10 check (commission_percent between 0 and 100),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (id)
);

insert into public.platform_settings (id, commission_percent) values (1, 10)
  on conflict (id) do nothing;

alter table public.platform_settings enable row level security;

-- Public read (transparency — a renter/owner can see the current
-- platform commission) — no client write policy; only
-- admin_update_commission_percent below writes here.
create policy platform_settings_select_all on public.platform_settings
  for select using (true);

create or replace function public.admin_update_commission_percent(p_percent numeric)
returns public.platform_settings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.platform_settings;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_percent < 0 or p_percent > 100 then
    raise exception 'invalid_commission_percent';
  end if;

  update public.platform_settings
    set commission_percent = p_percent, updated_at = now(), updated_by = auth.uid()
    where id = 1
    returning * into v_settings;

  perform public.log_admin_action(
    'platform_settings.update_commission', 'platform_settings', null,
    jsonb_build_object('commission_percent', p_percent)
  );

  return v_settings;
end;
$$;

revoke all on function public.admin_update_commission_percent(numeric) from public;
grant execute on function public.admin_update_commission_percent(numeric) to authenticated;

-- create_booking (0006), re-declared with the exact same signature —
-- only change is v_commission now comes from platform_settings instead
-- of a hardcoded 10, closing the TODO(Phase 11) on its own header
-- comment. Every other line is unchanged.
create or replace function public.create_booking(
  p_asset_id uuid,
  p_start_date date,
  p_end_date date
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_renter_id uuid := auth.uid();
  v_asset public.assets%rowtype;
  v_nights int;
  v_commission numeric(5, 2);
  v_rental_amount numeric(12, 2);
  v_platform_fee numeric(12, 2);
  v_deposit numeric(12, 2);
  v_total numeric(12, 2);
  v_booking public.bookings;
begin
  if v_renter_id is null then
    raise exception 'auth_required';
  end if;

  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'invalid_date_range';
  end if;

  if p_start_date < current_date then
    raise exception 'invalid_date_range';
  end if;

  select * into v_asset from public.assets where id = p_asset_id and status = 'published' for update;
  if not found then
    raise exception 'asset_not_found';
  end if;

  if v_asset.owner_id = v_renter_id then
    raise exception 'cannot_book_own_asset';
  end if;

  if v_asset.price_per_day is null then
    raise exception 'asset_missing_daily_price';
  end if;

  if exists (
    select 1
    from public.asset_availability av
    where av.asset_id = p_asset_id
      and av.is_blocked = true
      and daterange(av.start_date, av.end_date, '[]') && daterange(p_start_date, p_end_date, '[]')
  ) then
    raise exception 'dates_unavailable';
  end if;

  select coalesce(commission_percent, 10) into v_commission from public.platform_settings where id = 1;
  if v_commission is null then
    v_commission := 10;
  end if;

  v_nights := greatest(p_end_date - p_start_date, 1);
  v_rental_amount := round(v_asset.price_per_day * v_nights, 2);
  v_platform_fee := round(v_rental_amount * v_commission / 100, 2);
  v_deposit := coalesce(v_asset.deposit_amount, 0);
  v_total := v_rental_amount + v_platform_fee + v_deposit;

  begin
    insert into public.bookings (
      asset_id, renter_id, owner_id, start_date, end_date, status,
      rental_amount, platform_fee, delivery_fee, deposit_amount, total_amount, commission_percent
    ) values (
      p_asset_id, v_renter_id, v_asset.owner_id, p_start_date, p_end_date, 'pending',
      v_rental_amount, v_platform_fee, 0, v_deposit, v_total, v_commission
    )
    returning * into v_booking;
  exception
    when exclusion_violation then
      raise exception 'dates_unavailable';
  end;

  insert into public.booking_items (booking_id, kind, label, amount)
  values
    (v_booking.id, 'rental', 'rental', v_rental_amount),
    (v_booking.id, 'platform_fee', 'platform_fee', v_platform_fee),
    (v_booking.id, 'deposit', 'deposit', v_deposit);

  return v_booking;
end;
$$;

revoke all on function public.create_booking(uuid, date, date) from public;
grant execute on function public.create_booking(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------------
-- Payout processing
-- ---------------------------------------------------------------------
--
-- The transition Phase 7's own header comment on validate_payout_request
-- flagged as "Phase 11, not implemented here." Allowed transitions:
-- pending -> processing, pending -> failed, processing -> paid,
-- processing -> failed. Anything else (including touching an
-- already-paid/failed payout) is rejected — those are terminal.
-- `available_balance` is only ever deducted on the processing -> paid
-- transition, matching real-world payout timing (money hasn't actually
-- left until it's confirmed sent, not merely "being processed").
create or replace function public.admin_process_payout(
  p_payout_id uuid,
  p_new_status text,
  p_destination_reference text default null
)
returns public.payouts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payout public.payouts;
  v_from_status text;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_new_status not in ('processing', 'paid', 'failed') then
    raise exception 'invalid_status';
  end if;

  select * into v_payout from public.payouts where id = p_payout_id for update;
  if not found then
    raise exception 'payout_not_found';
  end if;
  v_from_status := v_payout.status;

  if v_from_status = 'pending' and p_new_status not in ('processing', 'failed') then
    raise exception 'invalid_status_transition';
  end if;
  if v_from_status = 'processing' and p_new_status not in ('paid', 'failed') then
    raise exception 'invalid_status_transition';
  end if;
  if v_from_status not in ('pending', 'processing') then
    raise exception 'invalid_status_transition'; -- paid/failed are terminal
  end if;

  if p_new_status = 'paid' then
    update public.wallets
      set available_balance = available_balance - v_payout.amount, updated_at = now()
      where user_id = v_payout.user_id;

    insert into public.wallet_transactions (wallet_user_id, type, amount, description)
    values (v_payout.user_id, 'payout', -v_payout.amount, 'Payout paid out');
  end if;

  update public.payouts
    set status = p_new_status,
        destination_reference = coalesce(p_destination_reference, destination_reference),
        processed_at = case when p_new_status in ('paid', 'failed') then now() else processed_at end
    where id = p_payout_id
    returning * into v_payout;

  perform public.log_admin_action(
    'payout.process', 'payout', p_payout_id,
    jsonb_build_object('from_status', v_from_status, 'to_status', p_new_status)
  );

  if p_new_status = 'paid' then
    insert into public.notifications (user_id, event_type, title, body, deep_link)
    values (v_payout.user_id, 'payout_paid', 'Payout sent', '', '/wallet');
  elsif p_new_status = 'failed' then
    insert into public.notifications (user_id, event_type, title, body, deep_link)
    values (v_payout.user_id, 'payout_failed', 'Payout failed', '', '/wallet');
  end if;

  return v_payout;
end;
$$;

revoke all on function public.admin_process_payout(uuid, text, text) from public;
grant execute on function public.admin_process_payout(uuid, text, text) to authenticated;

-- wallets.available_balance previously had no non-negative check
-- covering a *decrease* below zero in practice (0010 added the
-- constraint; admin_process_payout is the first thing that could
-- realistically hit it if two payout requests were both approved for
-- more than was actually available) — validate_payout_request (0008)
-- already prevents that at request time, so this is defense in depth,
-- not a gap being newly discovered.

-- ---------------------------------------------------------------------
-- Dispute resolution
-- ---------------------------------------------------------------------
--
-- Replaces disputes_update_admin's direct-write path entirely — see this
-- migration's header comment for why (audit_logs coverage). Reuses
-- restore_booking_status_after_dispute_resolution (0010) unchanged: that
-- trigger fires on any UPDATE to disputes.status regardless of who/what
-- performed it, so this RPC doesn't need to duplicate the
-- booking-restore or participant-notification logic at all.
drop policy if exists disputes_update_admin on public.disputes;

create or replace function public.admin_resolve_dispute(
  p_dispute_id uuid,
  p_new_status text,
  p_resolution_notes text default null
)
returns public.disputes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dispute public.disputes;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_new_status not in ('under_review', 'resolved', 'rejected', 'escalated') then
    raise exception 'invalid_status';
  end if;

  update public.disputes
    set status = p_new_status,
        resolution_notes = coalesce(p_resolution_notes, resolution_notes),
        resolved_by = case when p_new_status in ('resolved', 'rejected') then auth.uid() else resolved_by end,
        updated_at = now()
    where id = p_dispute_id
    returning * into v_dispute;

  if not found then
    raise exception 'dispute_not_found';
  end if;

  perform public.log_admin_action(
    'dispute.resolve', 'dispute', p_dispute_id,
    jsonb_build_object('new_status', p_new_status)
  );

  return v_dispute;
end;
$$;

revoke all on function public.admin_resolve_dispute(uuid, text, text) from public;
grant execute on function public.admin_resolve_dispute(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Abuse/content report resolution
-- ---------------------------------------------------------------------

create or replace function public.admin_resolve_report(p_report_id uuid, p_new_status text)
returns public.reports
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_new_status not in ('reviewed', 'actioned', 'dismissed') then
    raise exception 'invalid_status';
  end if;

  update public.reports
    set status = p_new_status,
        resolved_at = case when p_new_status in ('actioned', 'dismissed') then now() else resolved_at end
    where id = p_report_id
    returning * into v_report;

  if not found then
    raise exception 'report_not_found';
  end if;

  perform public.log_admin_action(
    'report.resolve', 'report', p_report_id,
    jsonb_build_object('new_status', p_new_status)
  );

  return v_report;
end;
$$;

revoke all on function public.admin_resolve_report(uuid, text) from public;
grant execute on function public.admin_resolve_report(uuid, text) to authenticated;
