-- Drop previous views
DROP VIEW IF EXISTS user_activity_feed;

-- Create View V7: Using Direct Foreign Key 'order_id'
CREATE OR REPLACE VIEW user_activity_feed AS

-- 1. WALLET LEDGER (Completed Transactions)
SELECT 
    wl.id::text AS id,
    wl.user_id,
    CAST(wl.amount AS INTEGER) AS clover_quantity,
    
    -- FIAT AMOUNT RESOLUTION CHAIN
    COALESCE(
        -- Priority 1: Plan Price (if linked via metadata plan_id)
        tp.price, 
        
        -- Priority 2: Linked Order Amount via Foreign Key (The column I missed!)
        co_fk.amount,
        
        -- Priority 3: Linked Order via Metadata (Legacy/Backup)
        co_meta.amount,
        
        -- Priority 4: Metadata Snapshots
        CAST(wl.metadata->>'amount_usd' AS numeric), 
        CAST(wl.metadata->>'price_usd' AS numeric), 
        
        0
    ) AS fiat_amount,
    
    CASE
        WHEN wl.amount >= 0 THEN 'deposit'::text
        ELSE 'withdrawal'::text
    END AS type,
    'completed'::text AS status,
    wl.created_at,
    COALESCE(wl.description, CASE WHEN wl.amount >= 0 THEN 'Recarga' ELSE 'Retiro' END) AS description,
    NULL::text AS payment_url
FROM wallet_ledger wl

-- JOIN 1: Unified Plan Table
LEFT JOIN transaction_plans tp 
    ON (wl.metadata->>'plan_id') IS NOT NULL 
    AND (wl.metadata->>'plan_id')::uuid = tp.id

-- JOIN 2: Clover Orders via DIRECT FOREIGN KEY 'order_id' (The Solution)
LEFT JOIN clover_orders co_fk 
    ON wl.order_id = co_fk.id

-- JOIN 3: Clover Orders via Metadata (Backup)
LEFT JOIN clover_orders co_meta
    ON (wl.metadata->>'order_id') IS NOT NULL 
    AND (
        wl.metadata->>'order_id' = co_meta.pago_pago_order_id 
        OR wl.metadata->>'order_id' = co_meta.id::text
    )

UNION ALL

-- 2. ORDERS (Pending/Failed)
SELECT 
    co.id::text AS id,
    co.user_id,
    -- Clover Quantity
    COALESCE(
        CAST(tp.amount AS INTEGER), 
        CAST(co.extra_data->>'clovers_amount' AS INTEGER), 
        CAST(co.extra_data->>'clovers_quantity' AS INTEGER),
        0
    ) AS clover_quantity,
    
    -- Fiat Amount
    COALESCE(
        tp.price, 
        CAST(co.extra_data->>'price_usd' AS numeric), 
        CAST(co.extra_data->>'amount_usd' AS numeric),
        co.amount
    ) AS fiat_amount,
    
    'deposit'::text AS type,
    co.status,
    co.created_at,
    'Compra de Tréboles'::text AS description,
    co.payment_url
FROM clover_orders co
LEFT JOIN transaction_plans tp ON co.plan_id = tp.id
WHERE co.status <> ALL (ARRAY['success'::text, 'paid'::text]);
