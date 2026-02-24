-- Migration: Unified Transaction Plans Table
-- Replaces clovers_plans and withdrawal_plans with a single table

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.transaction_plans (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    -- 'amount' represents the Token Quantity (Clovers)
    amount integer NOT NULL CHECK (amount > 0),
    -- 'price' represents the Money Value in USD (Cost to buy OR Value to withdraw)
    price numeric NOT NULL CHECK (price > 0),
    -- 'type' distinguishes between buying clovers and withdrawing funds
    type text NOT NULL CHECK (type IN ('buy', 'withdraw')),
    is_active boolean DEFAULT true,
    icon_url text, -- E.g. '🍀', '💸' or URL
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT transaction_plans_pkey PRIMARY KEY (id)
);

-- 2. Enable RLS
ALTER TABLE public.transaction_plans ENABLE ROW LEVEL SECURITY;

-- 3. Policies
-- Public Read Access
CREATE POLICY "Public read access"
    ON public.transaction_plans FOR SELECT
    USING (true);

-- Admin Full Access
CREATE POLICY "Admin full access"
    ON public.transaction_plans FOR ALL
    USING (
        auth.jwt() ->> 'role' = 'service_role' OR
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

-- 4. Migrate Data (Optional - Mapping existing plans)
-- Migrate Clover Plans (Buy)
INSERT INTO public.transaction_plans (id, name, amount, price, type, is_active, icon_url, sort_order)
SELECT id, name, clovers_quantity, price_usd, 'buy', is_active, icon_url, sort_order
FROM public.clover_plans
ON CONFLICT (id) DO NOTHING;

-- Migrate Withdrawal Plans (Withdraw)
INSERT INTO public.transaction_plans (id, name, amount, price, type, is_active, icon_url, sort_order)
SELECT id, name, clovers_cost, amount_usd, 'withdraw', is_active, NULL, 0 -- Assuming no sort_order/icon in old table
FROM public.withdrawal_plans
ON CONFLICT (id) DO NOTHING;

-- 5. Create Index
CREATE INDEX IF NOT EXISTS idx_transaction_plans_type_active 
    ON public.transaction_plans(type, is_active);
