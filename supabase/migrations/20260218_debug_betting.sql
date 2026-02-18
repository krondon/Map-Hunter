-- RPC: Debug Betting Status
-- Purpose: Returns diagnostic info about betting for an event.

CREATE OR REPLACE FUNCTION public.debug_betting_status(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_event_exists BOOLEAN;
    v_betting_active BOOLEAN;
    v_ticket_price INTEGER;
    v_bet_count INTEGER;
    v_total_amount INTEGER;
    v_last_bet JSONB;
    v_racer_id_type TEXT;
BEGIN
    -- Check Event
    SELECT EXISTS(SELECT 1 FROM events WHERE id = p_event_id), betting_active, bet_ticket_price
    INTO v_event_exists, v_betting_active, v_ticket_price
    FROM events WHERE id = p_event_id;

    -- Check Bets
    SELECT COUNT(*), COALESCE(SUM(amount), 0)
    INTO v_bet_count, v_total_amount
    FROM bets WHERE event_id = p_event_id;

    -- Get Last Bet
    SELECT jsonb_build_object('id', id, 'racer_id', racer_id, 'amount', amount, 'created_at', created_at)
    INTO v_last_bet
    FROM bets WHERE event_id = p_event_id ORDER BY created_at DESC LIMIT 1;

    -- Check Column Type (Indirectly via pg_typeof or just knowing schema)
    -- We can try to see if racer_id is compatible with UUID
    
    RETURN jsonb_build_object(
        'event_exists', v_event_exists,
        'betting_active', v_betting_active,
        'ticket_price', v_ticket_price,
        'bet_count', v_bet_count,
        'total_amount', v_total_amount,
        'last_bet', v_last_bet
    );
END;
$$;
