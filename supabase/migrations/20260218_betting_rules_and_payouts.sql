-- Migration: Strict Betting Restrictions & Results
-- Description: Updates place_bets_batch to enforce status check and adds get_user_event_winnings RPC.

-- 1. Update place_bets_batch to strictly check for 'pending' status
CREATE OR REPLACE FUNCTION public.place_bets_batch(
    p_event_id UUID,
    p_user_id UUID,
    p_racer_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ticket_price INTEGER;
    v_betting_active BOOLEAN;
    v_event_status TEXT; -- NEW
    v_total_cost INTEGER;
    v_racer_id UUID;
    v_count INTEGER;
    v_payment_result JSONB;
BEGIN
    -- 1. Validate Event & Betting State
    SELECT bet_ticket_price, betting_active, status -- Added status
    INTO v_ticket_price, v_betting_active, v_event_status
    FROM public.events 
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    -- STRICT RULE: Betting only allowed in 'pending' status
    IF v_event_status <> 'pending' THEN
         RETURN jsonb_build_object('success', false, 'message', 'Betting is closed. The race has started or finished.');
    END IF;

    IF v_betting_active = FALSE THEN
        RETURN jsonb_build_object('success', false, 'message', 'Betting is explicitly closed for this event');
    END IF;

    v_count := array_length(p_racer_ids, 1);
    IF v_count IS NULL OR v_count = 0 THEN
         RETURN jsonb_build_object('success', false, 'message', 'No racers selected');
    END IF;

    -- 2. Calculate Cost
    v_total_cost := v_ticket_price * v_count;

    -- 3. Execute Payment
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

-- 2. Helper RPC to get winnings for a user in an event
-- This avoids complex client-side logic reading wallet_ledger.
CREATE OR REPLACE FUNCTION public.get_user_event_winnings(
    p_event_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_winnings INTEGER := 0;
    v_won BOOLEAN := FALSE;
BEGIN
    -- Sum up all 'bet_payout' type entries in ledger for this event/user
    -- The metadata contains event_id, so we can filter by it.
    -- However, metadata is JSONB.
    
    SELECT COALESCE(SUM(amount), 0) INTO v_winnings
    FROM wallet_ledger
    WHERE user_id = p_user_id
    AND (metadata->>'type') = 'bet_payout'
    AND (metadata->>'event_id') = p_event_id::text;
    
    IF v_winnings > 0 THEN
        v_won := TRUE;
    END IF;

    RETURN jsonb_build_object(
        'won', v_won,
        'amount', v_winnings
    );
END;
$$;
