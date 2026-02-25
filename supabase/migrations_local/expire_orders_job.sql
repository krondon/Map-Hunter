-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the job to run every 15 minutes
-- This updates orders that remain 'pending' after their expires_at time
SELECT cron.schedule(
  'expire_old_orders', -- Job name
  '*/15 * * * *',      -- Cron expression (every 15 mins)
  $$
    UPDATE public.clover_orders
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at < NOW();
  $$
);
