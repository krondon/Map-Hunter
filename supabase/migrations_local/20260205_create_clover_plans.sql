-- Migration: Create clover_plans table for predefined purchase plans
-- Date: 2026-02-05
-- Purpose: Security-focused refactor - prices are now server-side controlled

-- ============================================
-- 1. CREATE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.clover_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  clovers_quantity integer NOT NULL,
  price_usd numeric NOT NULL,
  is_active boolean DEFAULT true,
  icon_url text,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT clover_plans_pkey PRIMARY KEY (id),
  CONSTRAINT clover_plans_clovers_quantity_check CHECK (clovers_quantity > 0),
  CONSTRAINT clover_plans_price_check CHECK (price_usd > 0)
);

-- ============================================
-- 2. ENABLE RLS
-- ============================================
ALTER TABLE public.clover_plans ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 3. RLS POLICIES
-- ============================================

-- SELECT: Any user (authenticated or anonymous) can read active plans
CREATE POLICY "clover_plans_select_active"
  ON public.clover_plans FOR SELECT
  USING (is_active = true);

-- ALL (INSERT/UPDATE/DELETE): Only service_role or admins
-- Note: Edge Functions use service_role key, bypassing RLS
-- Admin panel should use authenticated users with 'admin' role
CREATE POLICY "clover_plans_admin_all"
  ON public.clover_plans FOR ALL
  USING (
    auth.jwt() ->> 'role' = 'service_role' OR
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- ============================================
-- 4. INSERT DEFAULT PLANS (USD Prices)
-- ============================================
INSERT INTO public.clover_plans (name, clovers_quantity, price_usd, icon_url, sort_order) VALUES
  ('Básico', 50, 5.00, '🍀', 1),
  ('Pro', 150, 12.00, '🍀🍀', 2),
  ('Élite', 500, 35.00, '🍀🍀🍀', 3)
ON CONFLICT DO NOTHING;

-- ============================================
-- 5. ADD plan_id COLUMN TO clover_orders (optional FK)
-- ============================================
ALTER TABLE public.clover_orders 
ADD COLUMN IF NOT EXISTS plan_id uuid REFERENCES public.clover_plans(id);

-- ============================================
-- 6. CREATE INDEX FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_clover_plans_active 
  ON public.clover_plans(is_active) 
  WHERE is_active = true;
