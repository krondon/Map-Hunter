-- Drop view to ensure clean recreation
DROP VIEW IF EXISTS user_activity_feed;

CREATE OR REPLACE VIEW user_activity_feed AS
SELECT 
    wl.id::text AS id,
    wl.user_id,
    -- Wallet Ledger: Amount is the quantity of clovers (Int)
    CAST(wl.amount AS INTEGER) AS clover_quantity,
    -- Wallet Ledger: No direct fiat exchange in ledger usually, so 0 or NULL
    NULL::numeric AS fiat_amount,
    
    CASE
        WHEN wl.amount >= 0 THEN 'deposit'::text
        ELSE 'withdrawal'::text
    END AS type,
    'completed'::text AS status,
    wl.created_at,
    COALESCE(wl.description, CASE WHEN wl.amount >= 0 THEN 'Recarga' ELSE 'Retiro' END) AS description,
    NULL::text AS payment_url
FROM wallet_ledger wl

UNION ALL

SELECT 
    co.id::text AS id,
    co.user_id,
    -- Clover Orders: Clovers amount is in extra_data (Int)
    CAST(COALESCE(co.extra_data->>'clovers_amount', '0') AS INTEGER) AS clover_quantity,
    -- Clover Orders: Amount is the Price in Fiat (Numeric)
    co.amount AS fiat_amount,
    
    'deposit'::text AS type,
    co.status,
    co.created_at,
    'Compra de Tréboles'::text AS description,
    co.payment_url
FROM clover_orders co
WHERE co.status <> ALL (ARRAY['success'::text, 'paid'::text]);
