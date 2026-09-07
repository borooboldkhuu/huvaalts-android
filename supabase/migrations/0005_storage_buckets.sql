-- ХУВААЛЦ — Supabase Storage buckets (spec sections 14, 34).
--
-- `asset-images`: public-read (listing photos are meant to be publicly
-- visible, same as any marketplace), write-restricted to the asset's own
-- owner. Client uploads to `asset-images/{asset_id}/{filename}` — the
-- owner check below parses the asset id out of the object path's first
-- folder segment via `storage.foldername`.
--
-- File type/size validation (spec section 34: "upload restrictions, file
-- type validation, image size limits") happens client-side before upload
-- (compression/crop — spec section 14) and should additionally be
-- enforced via bucket-level `file_size_limit`/`allowed_mime_types` once
-- the Supabase CLI/dashboard config for this project exists; those aren't
-- expressible as a portable SQL migration, so they're called out here
-- rather than silently skipped.

insert into storage.buckets (id, name, public)
values ('asset-images', 'asset-images', true)
on conflict (id) do nothing;

create policy "asset_images_owner_write"
on storage.objects
for all
using (
  bucket_id = 'asset-images'
  and exists (
    select 1 from public.assets a
    where a.id::text = (storage.foldername(name))[1]
      and a.owner_id = auth.uid()
  )
)
with check (
  bucket_id = 'asset-images'
  and exists (
    select 1 from public.assets a
    where a.id::text = (storage.foldername(name))[1]
      and a.owner_id = auth.uid()
  )
);

-- `condition-reports`: before/after pickup photos (spec section 25).
-- Private — only booking participants (and admins) should ever read
-- these, so unlike asset-images this bucket is NOT public; reads go
-- through signed URLs issued to participants (application code, not this
-- migration — noted here so the bucket's privacy intent isn't lost).
insert into storage.buckets (id, name, public)
values ('condition-reports', 'condition-reports', false)
on conflict (id) do nothing;

create policy "condition_reports_participant_write"
on storage.objects
for all
using (
  bucket_id = 'condition-reports'
  and exists (
    select 1 from public.bookings b
    where b.id::text = (storage.foldername(name))[1]
      and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
  )
)
with check (
  bucket_id = 'condition-reports'
  and exists (
    select 1 from public.bookings b
    where b.id::text = (storage.foldername(name))[1]
      and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
  )
);
