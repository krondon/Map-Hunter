-- Migration: Refactor bets.racer_id to reference profiles.id
-- Description: Changes racer_id from TEXT to UUID and adds FK to profiles. Updates RPCs.

-- 1. Clean up incompatible data (Optional: Remove if you want to try keeping data)
TRUNCATE TABLE public.bets;

-- 2. Alter Table
ALTER TABLE public.bets
    ALTER COLUMN racer_id TYPE UUID USING racer_id::uuid,
    ADD CONSTRAINT bets_racer_id_fkey FOREIGN KEY (racer_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 3. Drop old RPCs (signatures change)
DROP FUNCTION IF EXISTS public.place_bets_batch(uuid, uuid, text[]);
DROP FUNCTION IF EXISTS public.resolve_event_bets(uuid, text);

-- 4. Recreate RPC: place_bets_batch
CREATE OR REPLACE FUNCTION public.place_bets_batch(
    p_event_id UUID,
    p_user_id UUID,
    p_racer_ids UUID[] -- Changed to UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ticket_price INTEGER;
    v_betting_active BOOLEAN;
    v_total_cost INTEGER;
    v_racer_id UUID;
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

-- 5. Recreate RPC: resolve_event_bets
CREATE OR REPLACE FUNCTION public.resolve_event_bets(
    p_event_id UUID,
    p_winner_racer_id UUID -- Changed to UUID
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
    -- Get Event Title
    SELECT title INTO v_event_title FROM events WHERE id = p_event_id;

    -- 1. Calculate Total Pool
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
        v_payout_per_ticket := FLOOR(v_total_pool / v_winning_tickets_count);

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
