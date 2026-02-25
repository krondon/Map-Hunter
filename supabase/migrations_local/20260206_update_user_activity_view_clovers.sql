-- Drop existing view
DROP VIEW IF EXISTS user_activity_feed;

-- Recreate view with corrected amount logic (Clovers vs Fiat)
CREATE OR REPLACE VIEW user_activity_feed AS
SELECT 
    wl.id::text AS id,
    wl.user_id,
    wl.amount AS amount, -- Already in Clovers
    NULL::numeric AS fiat_amount,
    CASE
        WHEN wl.amount >= 0::numeric THEN 'deposit'::text
        ELSE 'withdrawal'::text
    END AS type,
    'completed'::text AS status,
    wl.created_at,
    COALESCE(wl.description,
        CASE
            WHEN wl.amount >= 0::numeric THEN 'Recarga'::text
            ELSE 'Retiro'::text
        END) AS description,
    NULL::text AS payment_url
FROM wallet_ledger wl

UNION ALL

SELECT 
    co.id::text AS id,
    co.user_id,
    -- Extract Clovers amount from extra_data, fallback to 0 if missing.
    -- Note: co.amount is usually the Fiat amount (VES/USD).
    COALESCE((co.extra_data->>'clovers_amount')::numeric, 0) AS amount, 
    co.amount AS fiat_amount,
    'deposit'::text AS type, -- Orders are usually deposits (purchases)
    co.status,
    co.created_at,
    'Intento de Compra'::text AS description,
    co.payment_url
FROM clover_orders co
-- Exclude completed orders as they should appear in wallet_ledger
WHERE co.status <> ALL (ARRAY['success'::text, 'paid'::text]);
