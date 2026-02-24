-- Migration: Restore Wallet Ledger Descriptions & Fix Types
-- Created: 2026-02-19
-- Purpose: 
-- 1. Restore the detailed 'wallet_ledger' logging in 'distribute_event_prizes' (overwritten by previous fix).
-- 2. Restore the detailed 'wallet_ledger' logging in 'resolve_event_bets'.
-- 3. Ensure 'resolve_event_bets' accepts UUID for racer_id (fixing a regression to TEXT).

-- 1. Update distribute_event_prizes (Robust + Detailed Logging)
CREATE OR REPLACE FUNCTION distribute_event_prizes(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_record RECORD;
  v_participant_count INT;
  v_distributable_pot NUMERIC;
  v_total_collected NUMERIC;
  v_winners RECORD;
  v_prize_amount NUMERIC;
  v_share NUMERIC;
  v_rank INT;
  v_distribution_results JSONB[] := ARRAY[]::JSONB[];
  v_shares NUMERIC[];
BEGIN
  -- 1. Lock Event & Get Details
  SELECT * INTO v_event_record FROM events WHERE id = p_event_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- 2. Idempotency Check
  IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
     RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true, 'already_distributed', true);
  END IF;

  -- 3. Define Distribution Shares
  IF v_event_record.configured_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_event_record.configured_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE 
    v_shares := ARRAY[0.50, 0.30, 0.20]; 
  END IF;

  -- 4. Count ALL Participants
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes válidos');
  END IF;

  -- 5. Calculate Pot
  v_total_collected := v_participant_count * (COALESCE(v_event_record.entry_fee, 0));
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id;
      RETURN json_build_object('success', true, 'message', 'Evento finalizado sin premios (Bote 0)', 'pot', 0);
  END IF;

  -- 6. Select Winners (Top N)
  v_rank := 0;
  
  FOR v_winners IN 
    SELECT * 
    FROM game_players 
    WHERE event_id = p_event_id 
    AND status IN ('active', 'completed')
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_event_record.configured_winners
  LOOP
    v_rank := v_rank + 1;
    
    IF v_rank <= array_length(v_shares, 1) THEN
        v_share := v_shares[v_rank];
        v_prize_amount := floor(v_distributable_pot * v_share);

        IF v_prize_amount > 0 THEN
            -- A. Update User Wallet
            UPDATE profiles 
            SET clovers = COALESCE(clovers, 0) + v_prize_amount
            WHERE id = v_winners.user_id;

            -- B. Record Distribution Log
            INSERT INTO prize_distributions 
            (event_id, user_id, position, amount, pot_total, participants_count, entry_fee, rpc_success)
            VALUES 
            (p_event_id, v_winners.user_id, v_rank, v_prize_amount, v_distributable_pot, v_participant_count, v_event_record.entry_fee, true);
            
            -- C. [RESTORED] Log to Wallet Ledger
            -- This explicitly describes the transaction as a Prize
            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
              v_winners.user_id,
              v_prize_amount,
              'Premio Competencia: ' || v_event_record.title || ' (Posición ' || v_rank || ')',
              jsonb_build_object('type', 'event_prize', 'event_id', p_event_id, 'rank', v_rank)
            );

            -- D. Add to results
            v_distribution_results := array_append(v_distribution_results, jsonb_build_object(
                'user_id', v_winners.user_id,
                'rank', v_rank,
                'amount', v_prize_amount
            ));
        END IF;
    END IF;
  END LOOP;

  -- 7. Finalize Event
  UPDATE events 
  SET status = 'completed', 
      completed_at = NOW(),
      winner_id = (SELECT user_id FROM game_players WHERE event_id = p_event_id ORDER BY completed_clues_count DESC, finish_time ASC LIMIT 1)
  WHERE id = p_event_id;

  RETURN json_build_object(
    'success', true, 
    'pot_total', v_total_collected,
    'distributable_pot', v_distributable_pot,
    'winners_count', v_rank,
    'results', v_distribution_results
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;


-- 2. Update resolve_event_bets (Detailed Logging + UUID fix)
CREATE OR REPLACE FUNCTION public.resolve_event_bets(
    p_event_id UUID,
    p_winner_racer_id UUID -- Ensured UUID to match table schema
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
        -- [RESTORED] Log to Wallet Ledger (Spanish)
        INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
        SELECT 
            user_id, 
            v_payout_per_ticket, 
            'Apuesta Ganada: ' || COALESCE(v_event_title, 'Evento'), 
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
