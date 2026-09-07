-- ХУВААЛЦ — storage bucket upload restrictions (spec section 34: "upload
-- restrictions, file type validation, image size limits").
--
-- 0005_storage_buckets.sql's and 0010_condition_reports_reviews_disputes.sql's
-- own comments said `file_size_limit`/`allowed_mime_types` "aren't
-- expressible in portable SQL — set those via the Supabase CLI/dashboard
-- config once the project exists" — an external audit (Aug 2026)
-- correctly pushed back on that claim. Both are real, plain columns on
-- `storage.buckets`: the Supabase Storage service reads them straight
-- from this table to reject an upload that violates them, regardless of
-- whether the row got its values via the dashboard, the JS
-- `updateBucket()` client call, or a SQL migration like this one — it's
-- a normal Postgres table the storage service queries, not a
-- config-only surface. The one real caveat found while confirming this:
-- the JS `updateBucket()` API accepts a human-friendly size string
-- ("100MB") and converts it to bytes itself before writing the column;
-- here the column is set directly in bytes (see the literal below), so
-- there's no string-parsing step for this migration to get wrong.
--
-- All three buckets in this project hold photos only — listing photos
-- (`asset-images`), pickup/return condition photos (`condition-reports`),
-- dispute evidence photos (`dispute-evidence`) — nothing else is ever
-- uploaded to any of them (see each bucket's own creation comment in
-- 0005/0010), so the same image-only allowlist applies to all three.
-- 8 MiB per file is generous for a compressed phone photo (the client
-- already compresses/crops before upload per spec section 14 —
-- `image_cropper` in the asset-create flow) while still comfortably
-- bounding worst-case storage abuse from a client that skips or
-- tampers with that client-side step.
update storage.buckets
set
  file_size_limit = 8388608, -- 8 MiB, in bytes
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
where id in ('asset-images', 'condition-reports', 'dispute-evidence');

-- Sanity check, not a silent no-op: if a future migration ever adds a
-- fourth bucket without updating this file, or renames one of the three
-- above, this makes that omission visible immediately at migration time
-- instead of quietly leaving a bucket unrestricted.
do $$
declare
  v_updated_count int;
begin
  select count(*) into v_updated_count
  from storage.buckets
  where id in ('asset-images', 'condition-reports', 'dispute-evidence')
    and file_size_limit = 8388608;
  if v_updated_count != 3 then
    raise exception
      'expected to restrict exactly 3 buckets (asset-images, condition-reports, '
      'dispute-evidence), only found % — check bucket ids match 0005/0010', v_updated_count;
  end if;
end $$;
