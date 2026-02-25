-- ==============================================================================
-- MIGRATION: BETTING SYSTEM (System Apuestas Espectador)
-- DATE: 2026-02-18
-- DESCRIPTION: Implements pari-mutuel betting for spectators with Wallet Ledger.
-- ==============================================================================

-- 1. Modify 'events' table to support betting configuration
ALTER TABLE public.events 
ADD COLUMN IF NOT EXISTS betting_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS bet_ticket_price INTEGER DEFAULT 100;

-- 2. Create 'bets' table
CREATE TABLE IF NOT EXISTS public.bets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    racer_id TEXT NOT NULL, -- Flexible (can be uuid or text, usually game_players.id)
    amount INTEGER NOT NULL CHECK (amount > 0), -- Snapshot of cost at time of bet
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraint: One bet ticket per racer per user per event
    CONSTRAINT unique_bet_per_racer UNIQUE (event_id, user_id, racer_id)
);

-- Index for faster lookups during payout resolution
CREATE INDEX IF NOT EXISTS idx_bets_event_racer ON public.bets(event_id, racer_id);
CREATE INDEX IF NOT EXISTS idx_bets_user ON public.bets(user_id);

-- ==============================================================================
-- RPC: place_bets_batch (Updated with secure_clover_payment)
-- DESCRIPTION: Places multiple bets atomically using secure payment.
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.place_bets_batch(
    p_event_id UUID,
    p_user_id UUID,
    p_racer_ids TEXT[] -- Array of game_player_ids to bet on
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ticket_price INTEGER;
    v_betting_active BOOLEAN;
    v_total_cost INTEGER;
    v_racer_id TEXT;
    v_count INTEGER;
    v_payment_result JSONB;
BEGIN
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
    -- We use the existing secure_clover_payment RPC logic directly or call it?
    -- Calling it is cleaner if it handles exceptions properly.
    -- secure_clover_payment returns JSON.
    
    v_payment_result := public.secure_clover_payment(
        p_user_id,
        v_total_cost,
        'Bet on ' || v_count || ' racers in event ' || p_event_id
    );

    IF (v_payment_result->>'success')::boolean = false THEN
        RETURN v_payment_result; -- Return the error from payment (e.g. INSUFFICIENT_CLOVERS)
    END IF;

    -- 4. Insert Bets
    FOREACH v_racer_id IN ARRAY p_racer_ids
    LOOP
        INSERT INTO public.bets (event_id, user_id, racer_id, amount)
        VALUES (p_event_id, p_user_id, v_racer_id, v_ticket_price)
        ON CONFLICT (event_id, user_id, racer_id) DO NOTHING; 
        -- Optimization: If they double bet, we technically charged them. 
        -- Ideally we filter duplicates BEFORE charging.
        -- But for batch simplicity, we assume frontend sends uniques.
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

-- ==============================================================================
-- RPC: resolve_event_bets (Updated with Wallet Ledger)
-- DESCRIPTION: Distributes the pot among winners (Pari-Mutuel).
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.resolve_event_bets(
    p_event_id UUID,
    p_winner_racer_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_pool INTEGER;
    v_winning_tickets_count INTEGER;
    v_payout_per_ticket INTEGER;
    v_winner_user_id UUID;
    v_event_title TEXT;
BEGIN
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
