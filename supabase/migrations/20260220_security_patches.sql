-- ==============================================================================
-- MIGRATION: SECURITY PATCHES V1
-- DATE: 2026-02-19
-- DESCRIPTION: Fixes IDOR, Privilege Escalation, and Data Exposure vulnerabilities.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Helper Function: is_admin
-- DESCRIPTION: Centralized check for admin privileges.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of creator (postgres) to read profiles/roles securely
SET search_path = public -- Secure search_path
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = p_user_id AND role = 'admin'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 2. FIX: IDOR in place_bets_batch
-- PROBLEM: Previous version accepted any p_user_id.
-- SOLUTION: STRICT validation against auth.uid().
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_bets_batch(
    p_event_id UUID,
    p_user_id UUID,
    p_racer_ids TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ticket_price INTEGER;
    v_betting_active BOOLEAN;
    v_total_cost INTEGER;
    v_racer_id TEXT;
    v_count INTEGER;
    v_payment_result JSONB;
BEGIN
    -- [SECURITY PATCH] IDOR Protection
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Security Violation: You can only place bets for yourself.';
    END IF;

    -- 1. Validate Event & Betting State
    SELECT bet_ticket_price, betting_active 
    INTO v_ticket_price, v_betting_active
    FROM public.events 
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    IF v_betting_active = FALSE THEN
        RETURN jsonb_build_object('success', false, 'message', 'Betting is closed for this event');
    END IF;

    v_count := array_length(p_racer_ids, 1);
    IF v_count IS NULL OR v_count = 0 THEN
         RETURN jsonb_build_object('success', false, 'message', 'No racers selected');
    END IF;

    -- 2. Calculate Cost
    v_total_cost := v_ticket_price * v_count;

    -- 3. Execute Payment (Atomic Deduction & Logging)
    v_payment_result := public.secure_clover_payment(
        p_user_id,
        v_total_cost,
        'Bet on ' || v_count || ' racers in event ' || p_event_id
    );

    IF (v_payment_result->>'success')::boolean = false THEN
        RETURN v_payment_result; 
    END IF;

    -- 4. Insert Bets
    FOREACH v_racer_id IN ARRAY p_racer_ids
    LOOP
        INSERT INTO public.bets (event_id, user_id, racer_id, amount)
        VALUES (p_event_id, p_user_id, v_racer_id, v_ticket_price)
        ON CONFLICT (event_id, user_id, racer_id) DO NOTHING; 
    END LOOP;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Bets placed successfully',
        'total_cost', v_total_cost,
        'new_balance', (v_payment_result->>'new_balance')
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. FIX: Privilege Escalation in resolve_event_bets
-- PROBLEM: Any authenticated user could trigger bet resolution.
-- SOLUTION: Require is_admin(auth.uid()) or is_superuser.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_event_bets(
    p_event_id UUID,
    p_winner_racer_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_pool INTEGER;
    v_winning_tickets_count INTEGER;
    v_payout_per_ticket INTEGER;
    v_event_title TEXT;
BEGIN
    -- [SECURITY PATCH] Check Admin Privileges
    -- We allow service_role (superuser) OR admin users
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can resolve event bets.';
    END IF;

    -- Get Event Title for logs
    SELECT title INTO v_event_title FROM events WHERE id = p_event_id;

    -- 1. Calculate Total Pool (All bets for event)
    SELECT COALESCE(SUM(amount), 0) INTO v_total_pool
    FROM public.bets
    WHERE event_id = p_event_id;

    IF v_total_pool = 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'No bets placed, no payout.');
    END IF;

    -- 2. Count Winning Tickets
    SELECT COUNT(*) INTO v_winning_tickets_count
    FROM public.bets
    WHERE event_id = p_event_id AND racer_id = p_winner_racer_id;

    -- 3. Distribute Payouts
    IF v_winning_tickets_count > 0 THEN
        -- Standard Pari-Mutuel: Pool / Winners
        v_payout_per_ticket := FLOOR(v_total_pool / v_winning_tickets_count);

        -- Bulk Update Winners
        WITH winners AS (
            SELECT user_id
            FROM public.bets
            WHERE event_id = p_event_id AND racer_id = p_winner_racer_id
        ),
        updated_profiles AS (
            UPDATE public.profiles
            SET clovers = clovers + v_payout_per_ticket
            FROM winners
            WHERE profiles.id = winners.user_id
            RETURNING profiles.id
        )
        -- Log to Wallet Ledger for each winner
        INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
        SELECT 
            user_id, 
            v_payout_per_ticket, 
            'Win: Bet payout for ' || COALESCE(v_event_title, 'Event'), 
            jsonb_build_object('type', 'bet_payout', 'event_id', p_event_id, 'racer_id', p_winner_racer_id)
        FROM winners;

        RETURN jsonb_build_object(
            'success', true, 
            'payout_per_ticket', v_payout_per_ticket,
            'total_winners', v_winning_tickets_count,
            'house_win', false
        );
    ELSE
        RETURN jsonb_build_object(
            'success', true, 
            'message', 'House Win (No winning tickets)',
            'house_win', true,
            'amount_kept', v_total_pool
        );
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. FIX: Data Exposure (RLS & View)
-- PROBLEM: 'bets' table was public. PII (who bet on what) was exposed.
-- SOLUTION: Enable RLS on 'bets'. Create VIEW for aggregate stats.
-- ------------------------------------------------------------------------------

-- Enable RLS
ALTER TABLE public.bets ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see only their own bets
DROP POLICY IF EXISTS "Users can view their own bets" ON public.bets;
CREATE POLICY "Users can view their own bets"
ON public.bets FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can place bets (Insert own)
DROP POLICY IF EXISTS "Users can place their own bets" ON public.bets;
CREATE POLICY "Users can place their own bets"
ON public.bets FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Admins can view all bets (Optional, for backend/admin panel)
DROP POLICY IF EXISTS "Admins can view all bets" ON public.bets;
CREATE POLICY "Admins can view all bets"
ON public.bets FOR SELECT
USING (public.is_admin(auth.uid()));

-- Policy: Service Role has full access (Default, but explicit is good)
-- Supabase service_role bypasses RLS by default, so not strictly needed, 
-- but good to remember if switching to restricted role.

-- VIEW: event_pools
-- Aggregates bets to show total pot WITHOUT exposing user IDs or amounts per user.
CREATE OR REPLACE VIEW public.event_pools AS
SELECT 
    event_id, 
    COALESCE(SUM(amount), 0) as total_pot,
    COUNT(*) as total_bets
FROM public.bets
GROUP BY event_id;

-- Grant access to the view (authenticated users need to see pots)
GRANT SELECT ON public.event_pools TO authenticated;
GRANT SELECT ON public.event_pools TO anon;
