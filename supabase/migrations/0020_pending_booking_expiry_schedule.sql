-- ХУВААЛЦ — schedules 0019's public.expire_stale_pending_bookings() to
-- actually run, via pg_cron.
--
-- Kept in its own migration, separate from 0019's function definitions,
-- on purpose: `pg_cron` is an allow-listed extension on Supabase-hosted
-- projects (enable it once via Dashboard → Database → Extensions, or it
-- may already be enabled) and ships by default on self-hosted Supabase's
-- Postgres image, but it is NOT guaranteed to be available/permitted on
-- every Postgres instance this schema might ever be applied to. If this
-- specific migration fails on your instance, the fix is not to force
-- pg_cron — delete/skip this file and call
-- `select public.expire_stale_pending_bookings();` from whatever
-- external scheduler you do have (a cron job on a small server, a CI
-- scheduled workflow, etc.) hitting the database directly with a
-- role that has EXECUTE on that function. 0019 itself has no dependency
-- on pg_cron and always applies cleanly either way.
--
-- No secrets are involved here on purpose: this schedules a direct SQL
-- call, not an HTTP call to an Edge Function, so there's no service-role
-- key to store in a Postgres setting.
create extension if not exists pg_cron;

-- Re-runnable: unschedule any previous job of the same name before
-- scheduling fresh, so applying this migration twice (or hand-running it
-- again after an edit) doesn't error or duplicate the job.
do $$
begin
  perform cron.unschedule('expire-stale-pending-bookings');
exception when others then
  null; -- no such job yet — fine, we schedule it below
end $$;

-- Hourly is far more often than the 48h TTL strictly needs, but the
-- function is cheap (a handful of stale-at-most rows per run, `skip
-- locked` so it never blocks on an in-flight transition) and running
-- hourly keeps the worst-case "stuck past TTL" window small.
select cron.schedule(
  'expire-stale-pending-bookings',
  '0 * * * *',
  $$select public.expire_stale_pending_bookings();$$
);
