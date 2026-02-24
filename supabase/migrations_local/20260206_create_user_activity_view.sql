-- Migration: Create user_activity_feed view
-- Description: Unifies wallet_ledger (completed transactions) and clover_orders (pending/failed/expired) into a single feed.

DROP VIEW IF EXISTS public.user_activity_feed;

CREATE OR REPLACE VIEW public.user_activity_feed AS
SELECT
    -- Wallet Ledger (Completed Transactions)
    wl.id::text AS id,
    wl.user_id,
    wl.amount,
    CASE 
        WHEN wl.amount >= 0 THEN 'deposit' 
        ELSE 'withdrawal' 
    END AS type,
    'completed' AS status,
    wl.created_at,
    COALESCE(wl.description, CASE WHEN wl.amount >= 0 THEN 'Recarga' ELSE 'Retiro' END) AS description,
    NULL::text AS payment_url
FROM
    public.wallet_ledger wl

UNION ALL

SELECT
    -- Clover Orders (Pending/Failed/Expired/Error)
    -- Explicitly CAST id to text if it's uuid or bigint in source to match ledger
    co.id::text AS id,
    co.user_id,
    co.amount,
    'deposit' AS type, -- Orders are always intents to deposit (buy clovers)
    co.status,
    co.created_at,
    'Intento de Compra' AS description,
    co.payment_url
FROM
    public.clover_orders co
WHERE
    co.status NOT IN ('success', 'paid'); -- Exclude successful ones as they should be in ledger

-- Grant permissions (if needed for anon/authenticated access depending on Supabase setup)
GRANT SELECT ON public.user_activity_feed TO authenticated;
GRANT SELECT ON public.user_activity_feed TO service_role;

-- RLS equivalent note: Views in Postgres < 15 do not automatically enforce RLS of underlying tables unless defined with security_invoker.
-- Supabase frequently uses Postgres 15+.
-- To be safe, we can make it a security invoker view if supported, or wrapped in a function.
-- However, for standard Supabase RLS transparency:
-- ALTER VIEW public.user_activity_feed SET (security_invoker = true); 
-- (Uncomment the above line if your Postgres version supports it, typically PG15+)
