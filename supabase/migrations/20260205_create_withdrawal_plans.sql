-- Migration: Create withdrawal_plans table for predefined withdrawal options
-- Date: 2026-02-05
-- Purpose: Separate table for withdrawal plans (different from purchase plans)

-- ============================================
-- 1. CREATE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.withdrawal_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  clovers_cost integer NOT NULL,          -- Cost in clovers (what user pays)
  amount_usd numeric NOT NULL,            -- Amount in USD (before conversion)
  is_active boolean DEFAULT true,
  icon text DEFAULT '💸',
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT withdrawal_plans_pkey PRIMARY KEY (id),
  CONSTRAINT withdrawal_plans_clovers_check CHECK (clovers_cost > 0),
  CONSTRAINT withdrawal_plans_amount_check CHECK (amount_usd > 0)
);

-- ============================================
-- 2. ENABLE RLS
-- ============================================
ALTER TABLE public.withdrawal_plans ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 3. RLS POLICIES
-- ============================================

-- SELECT: Any user can read active plans
CREATE POLICY "withdrawal_plans_select_active"
  ON public.withdrawal_plans FOR SELECT
  USING (is_active = true);

-- ALL: Only admins can modify
CREATE POLICY "withdrawal_plans_admin_all"
  ON public.withdrawal_plans FOR ALL
  USING (
    auth.jwt() ->> 'role' = 'service_role' OR
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ============================================
-- 4. INSERT DEFAULT WITHDRAWAL PLANS
-- ============================================
-- Note: clovers_cost = what user spends, amount_usd = what user receives
INSERT INTO public.withdrawal_plans (name, clovers_cost, amount_usd, icon, sort_order) VALUES
  ('Retiro Pequeño', 50, 5.00, '💵', 1),
  ('Retiro Mediano', 100, 10.00, '💰', 2),
  ('Retiro Grande', 250, 25.00, '🤑', 3)
ON CONFLICT DO NOTHING;

-- ============================================
-- 5. CREATE INDEX
-- ============================================
CREATE INDEX IF NOT EXISTS idx_withdrawal_plans_active 
  ON public.withdrawal_plans(is_active) 
  WHERE is_active = true;
