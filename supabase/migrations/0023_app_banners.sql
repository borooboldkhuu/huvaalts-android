-- ХУВААЛЦ — admin-manageable app-open banners.
--
-- Adds `public.app_banners`: images an admin uploads that show to every
-- signed-in user as a rotating popup the first time Home renders after
-- app open (`HomeScreen`'s post-frame check — see
-- `app_banner_popup.dart`). Follows the same admin-authored-content
-- shape `public.promotions` already established (0001_init_schema.sql /
-- 0013_security_perf_hardening.sql) — public SELECT of active rows,
-- admin-only write via `is_admin()`, one `security definer` RPC pair for
-- upsert + delete rather than direct table writes — but unlike
-- promotions this table only ever holds an image reference plus display
-- order: the popup has no tap-through action (confirmed with the user —
-- closing it, or swiping to the next banner, is the only interaction).
--
-- `identity_details` (0017) taught us table-level GRANTs aren't implicit
-- here even though every other table in this schema never needed one
-- spelled out — so this migration grants explicitly rather than assuming
-- Supabase's project-level defaults cover a brand-new table too.

create table public.app_banners (
  id uuid primary key default gen_random_uuid(),
  storage_path text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- `set_updated_at()` (0001) is only wired up via a fixed table-name array
-- in that migration's own `do $$ ... $$` block, not applied generically —
-- a table created later has to add its own trigger, same as
-- `identity_details_set_updated_at` did in 0017.
create trigger app_banners_set_updated_at before update on public.app_banners
  for each row execute function public.set_updated_at();

alter table public.app_banners enable row level security;

-- Public read of active banners only (mirrors `promotions_select_active`
-- from 0002) — an admin managing the list also needs to see inactive
-- ones, hence the `is_admin` escape hatch every other admin-content
-- table's select policy already uses.
create policy app_banners_select_active on public.app_banners
  for select using (is_active = true or public.is_admin(auth.uid()));

create policy app_banners_admin_write on public.app_banners
  for all using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

grant select on public.app_banners to authenticated;
-- No insert/update/delete grant to authenticated at all, admin included —
-- every write goes through the two `security definer` RPCs below, same
-- reasoning as `admin_upsert_promotion`'s own comment: one audited path,
-- not direct table access even for admins.

-- ---------------------------------------------------------------------
-- Storage: a dedicated public-read, admin-only-write bucket.
-- ---------------------------------------------------------------------
--
-- Not `asset-images` — that bucket's write policy ties access to
-- `assets.owner_id` via the object path's first folder segment
-- (0005_storage_buckets.sql), a check with no meaning for a banner image
-- that has no owning asset. `file_size_limit`/`allowed_mime_types` set
-- directly on creation (0021 already established these are real,
-- enforced columns, not dashboard-only config) instead of a follow-up
-- migration.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-banners',
  'app-banners',
  true,
  8388608, -- 8 MiB, same limit 0021 set for every other image bucket
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

create policy "app_banners_storage_admin_write" on storage.objects
for all
using (bucket_id = 'app-banners' and public.is_admin(auth.uid()))
with check (bucket_id = 'app-banners' and public.is_admin(auth.uid()));

-- ---------------------------------------------------------------------
-- Admin RPCs
-- ---------------------------------------------------------------------

create or replace function public.admin_upsert_app_banner(
  p_id uuid,
  p_storage_path text,
  p_sort_order int,
  p_is_active boolean
)
returns public.app_banners
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.app_banners;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;
  if p_storage_path is null or length(trim(p_storage_path)) = 0 then
    raise exception 'image_required';
  end if;

  if p_id is null then
    insert into public.app_banners (storage_path, sort_order, is_active)
    values (p_storage_path, coalesce(p_sort_order, 0), coalesce(p_is_active, true))
    returning * into v_row;
    perform public.log_admin_action('banner.create', 'app_banner', v_row.id, '{}'::jsonb);
  else
    update public.app_banners
    set storage_path = p_storage_path,
        sort_order = coalesce(p_sort_order, 0),
        is_active = coalesce(p_is_active, true)
    where id = p_id
    returning * into v_row;

    if not found then
      raise exception 'banner_not_found';
    end if;
    perform public.log_admin_action('banner.update', 'app_banner', v_row.id, '{}'::jsonb);
  end if;

  return v_row;
end;
$$;

revoke all on function public.admin_upsert_app_banner(uuid, text, int, boolean) from public;
grant execute on function public.admin_upsert_app_banner(uuid, text, int, boolean) to authenticated;

-- A real delete (not `promotions`' soft `is_active = false` deactivate) —
-- a disabled banner image left around forever is just dead storage with
-- no history worth keeping, unlike a promotion's discount terms. This
-- does NOT remove the underlying Storage object (no trigger does that
-- cleanup here) — a known, documented gap, not a silent one; an orphaned
-- file in `app-banners` costs storage but is otherwise harmless since
-- nothing serves it once its row is gone.
create or replace function public.admin_delete_app_banner(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted_id uuid;
begin
  if not public.is_admin(auth.uid()) then
    raise exception 'not_authorized';
  end if;

  delete from public.app_banners where id = p_id returning id into v_deleted_id;
  if v_deleted_id is null then
    raise exception 'banner_not_found';
  end if;

  perform public.log_admin_action('banner.delete', 'app_banner', v_deleted_id, '{}'::jsonb);
end;
$$;

revoke all on function public.admin_delete_app_banner(uuid) from public;
grant execute on function public.admin_delete_app_banner(uuid) to authenticated;
