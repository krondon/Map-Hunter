-- Migration: Create app_config table for global configuration
-- Date: 2026-02-05
-- Purpose: Store BCV exchange rate for USD -> VES conversion in withdrawals

-- ============================================
-- 1. CREATE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.app_config (
  key text NOT NULL,
  value jsonb NOT NULL,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id),
  CONSTRAINT app_config_pkey PRIMARY KEY (key)
);

-- ============================================
-- 2. ENABLE RLS
-- ============================================
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 3. RLS POLICIES
-- ============================================

-- SELECT: Any authenticated user can read config
CREATE POLICY "app_config_select_all"
  ON public.app_config FOR SELECT
  USING (true);

-- INSERT/UPDATE/DELETE: Only admins can modify
CREATE POLICY "app_config_admin_write"
  ON public.app_config FOR ALL
  USING (
    auth.jwt() ->> 'role' = 'service_role' OR
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ============================================
-- 4. INSERT INITIAL EXCHANGE RATE
-- ============================================
-- NOTE: Update this value to the current BCV rate after deployment!
INSERT INTO public.app_config (key, value) 
VALUES ('bcv_exchange_rate', '1.00')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- 5. CREATE HELPER FUNCTION FOR EASY ACCESS
-- ============================================
CREATE OR REPLACE FUNCTION public.get_exchange_rate()
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  rate numeric;
BEGIN
  SELECT (value::text)::numeric INTO rate
  FROM public.app_config
  WHERE key = 'bcv_exchange_rate';
  
  -- Default to 1 if not found (safety fallback)
  RETURN COALESCE(rate, 1.0);
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_exchange_rate() TO authenticated;
