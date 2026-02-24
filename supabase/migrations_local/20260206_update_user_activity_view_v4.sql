-- Drop previous views (V3)
DROP VIEW IF EXISTS user_activity_feed;

-- Create View V4: Using transaction_plans
CREATE OR REPLACE VIEW user_activity_feed AS

-- 1. WALLET LEDGER (Completed)
SELECT 
    wl.id::text AS id,
    wl.user_id,
    CAST(wl.amount AS INTEGER) AS clover_quantity,
    tp.price AS fiat_amount, -- Price from transaction_plans
    CASE
        WHEN wl.amount >= 0 THEN 'deposit'::text
        ELSE 'withdrawal'::text
    END AS type,
    'completed'::text AS status,
    wl.created_at,
    COALESCE(wl.description, CASE WHEN wl.amount >= 0 THEN 'Recarga' ELSE 'Retiro' END) AS description,
    NULL::text AS payment_url
FROM wallet_ledger wl
-- Join Unified Plan Table
LEFT JOIN transaction_plans tp 
    ON (wl.metadata->>'plan_id') IS NOT NULL 
    AND (wl.metadata->>'plan_id')::uuid = tp.id

UNION ALL

-- 2. ORDERS (Pending/Failed)
SELECT 
    co.id::text AS id,
    co.user_id,
    CAST(tp.amount AS INTEGER) AS clover_quantity,
    tp.price AS fiat_amount,
    'deposit'::text AS type,
    co.status,
    co.created_at,
    'Compra de Tréboles'::text AS description,
    co.payment_url
FROM clover_orders co
LEFT JOIN transaction_plans tp ON co.plan_id = tp.id
WHERE co.status <> ALL (ARRAY['success'::text, 'paid'::text]);
