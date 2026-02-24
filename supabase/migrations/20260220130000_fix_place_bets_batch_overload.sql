-- =============================================================
-- Migration: Fix place_bets_batch overload ambiguity (PGRST203)
-- Problem:   Two overloads exist: TEXT[] (from security_patches)
--            and UUID[] (from refactor). PostgREST can't resolve.
-- Solution:  Drop the stale TEXT[] version; keep and update
--            UUID[] with all security patches applied.
-- =============================================================

-- Step 1: Drop the stale TEXT[] overload
DROP FUNCTION IF EXISTS public.place_bets_batch(UUID, UUID, TEXT[]);

-- Step 2: Replace the canonical UUID[] version with IDOR fix
CREATE OR REPLACE FUNCTION public.place_bets_batch(
    p_event_id UUID,
    p_user_id UUID,
    p_racer_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ticket_price INTEGER;
    v_betting_active BOOLEAN;
    v_event_status TEXT;
    v_total_cost INTEGER;
    v_racer_id UUID;
    v_count INTEGER;
    v_payment_result JSONB;
BEGIN
    -- [SECURITY PATCH] IDOR Protection: only the authenticated user can place their own bets
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Security Violation: You can only place bets for yourself.';
    END IF;

    -- 1. Validate Event & Betting State
    SELECT bet_ticket_price, betting_active, status
    INTO v_ticket_price, v_betting_active, v_event_status
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    IF v_event_status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Betting is only allowed while event is pending');
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

    -- 3. Atomic Payment
    v_payment_result := public.secure_clover_payment(
        p_user_id,
        v_total_cost,
        'Bet on ' || v_count || ' racers in event ' || p_event_id
    );

    IF (v_payment_result->>'success')::boolean = false THEN
        RETURN v_payment_result;
    END IF;

    -- 4. Insert Bets (UUID racer_id)
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

GRANT EXECUTE ON FUNCTION public.place_bets_batch(UUID, UUID, UUID[]) TO authenticated;
