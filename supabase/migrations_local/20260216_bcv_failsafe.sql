-- Migration: BCV Fail-Safe ("26 Hour Rule")
-- Date: 2026-02-16
-- Purpose: Guard function to block withdrawals when BCV exchange rate is stale
--
-- SECURITY PRINCIPLE: It is better to deny a legitimate withdrawal
-- than to allow one with an incorrect exchange rate.

-- ============================================
-- 1. CREATE GUARD FUNCTION
-- ============================================
-- Returns TRUE if the BCV rate has been updated within the last 26 hours.
-- Returns FALSE if the rate is stale (>26h) or has never been updated (NULL).
-- Used by: api_withdraw_funds Edge Function, Flutter UI indicators.

CREATE OR REPLACE FUNCTION public.is_bcv_rate_valid()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE  -- safe to cache within a single query/transaction
AS $$
DECLARE
  last_update timestamptz;
BEGIN
  SELECT updated_at INTO last_update
  FROM public.app_config
  WHERE key = 'bcv_exchange_rate';

  -- NULL = never updated = STALE → block withdrawals
  IF last_update IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 26 hours = 1 day + 2 hours of grace period
  -- If the cron runs at 12:00 AM and fails, admins have until 2:00 AM
  -- the next day to notice and fix it manually.
  RETURN (now() - last_update) < INTERVAL '26 hours';
END;
$$;

-- ============================================
-- 2. GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION public.is_bcv_rate_valid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_bcv_rate_valid() TO service_role;

-- ============================================
-- 3. VERIFICATION TEST SCRIPT (run manually)
-- ============================================
-- Uncomment and run in SQL Editor to verify:
/*
-- TEST 1: Simulate stale rate (30 hours ago)
UPDATE app_config SET updated_at = now() - INTERVAL '30 hours' WHERE key = 'bcv_exchange_rate';
SELECT is_bcv_rate_valid(); -- Expected: FALSE

-- TEST 2: Simulate fresh rate (just now)
UPDATE app_config SET updated_at = now() WHERE key = 'bcv_exchange_rate';
SELECT is_bcv_rate_valid(); -- Expected: TRUE

-- TEST 3: Simulate NULL (never updated)
UPDATE app_config SET updated_at = NULL WHERE key = 'bcv_exchange_rate';
SELECT is_bcv_rate_valid(); -- Expected: FALSE

-- RESTORE to current time:
UPDATE app_config SET updated_at = now() WHERE key = 'bcv_exchange_rate';
*/
