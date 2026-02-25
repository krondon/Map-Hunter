-- Migration: BCV Auto-Update System
-- Date: 2026-02-15
-- Purpose: Create exchange rate history table for audit trail
--          and set up pg_cron job for daily automatic updates

-- ============================================
-- 1. CREATE EXCHANGE RATE HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.exchange_rate_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rate numeric,                         -- The new rate (NULL if scraping failed)
  previous_rate numeric,                -- The rate before this update
  source text NOT NULL DEFAULT 'manual', -- 'bcv_scraper', 'manual', 'bcv_error'
  error_message text,                   -- Error details when source = 'bcv_error'
  scraped_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Add comment for documentation
COMMENT ON TABLE public.exchange_rate_history IS 
  'Audit trail for BCV exchange rate changes. Each row records a rate update or failed attempt.';

-- ============================================
-- 2. ENABLE RLS
-- ============================================
ALTER TABLE public.exchange_rate_history ENABLE ROW LEVEL SECURITY;

-- SELECT: Admins can view history
CREATE POLICY "exchange_rate_history_admin_select"
  ON public.exchange_rate_history FOR SELECT
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- INSERT: Allow service_role (Edge Functions) to insert
CREATE POLICY "exchange_rate_history_service_insert"
  ON public.exchange_rate_history FOR INSERT
  WITH CHECK (
    auth.jwt() ->> 'role' = 'service_role'
  );

-- Full access for service_role (covers cron job inserts)
CREATE POLICY "exchange_rate_history_service_all"
  ON public.exchange_rate_history FOR ALL
  USING (
    auth.jwt() ->> 'role' = 'service_role'
  );

-- ============================================
-- 3. INDEX FOR EFFICIENT QUERIES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_exchange_rate_history_scraped_at
  ON public.exchange_rate_history(scraped_at DESC);

CREATE INDEX IF NOT EXISTS idx_exchange_rate_history_source
  ON public.exchange_rate_history(source);

-- ============================================
-- 4. PG_CRON JOB (Daily at 12:00 AM Venezuela time)
-- ============================================
-- NOTE: pg_cron and pg_net extensions must be enabled in your Supabase project.
--       Go to Dashboard → Database → Extensions and enable both.
--
-- The cron job uses pg_net to make an HTTP POST to the Edge Function.
-- Venezuela timezone (America/Caracas) is UTC-4, so 12:00 AM = 04:00 UTC.
--
-- IMPORTANT: Replace the placeholders below with your actual values:
--   - YOUR_SUPABASE_PROJECT_URL: e.g. https://xyzabc.supabase.co
--   - YOUR_SERVICE_ROLE_KEY: found in Dashboard → Settings → API → service_role key
--
-- Run this MANUALLY in the SQL Editor after deploying the Edge Function:

/*
-- Enable extensions (run once if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Schedule the cron job: every day at 04:00 UTC (12:00 AM Venezuela / America/Caracas)
SELECT cron.schedule(
  'update-bcv-rate',           -- Job name
  '0 4 * * *',                 -- Cron expression: 04:00 UTC = 00:00 VET
  $$
  SELECT net.http_post(
    url := 'YOUR_SUPABASE_PROJECT_URL/functions/v1/update-rate',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Verify the job was created:
-- SELECT * FROM cron.job WHERE jobname = 'update-bcv-rate';

-- To remove the job if needed:
-- SELECT cron.unschedule('update-bcv-rate');
*/
