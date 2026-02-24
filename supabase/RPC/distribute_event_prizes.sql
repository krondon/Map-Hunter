-- =============================================================
-- Migration: Fix distribute_event_prizes logic
-- Purpose: 
-- 1. Always assign final_placement and winner_id, even if pot is 0.
-- 2. Allow register_race_finisher to call it without admin privileges
--    when the race is actually finished, but prevent premature calls.
-- =============================================================

CREATE OR REPLACE FUNCTION distribute_event_prizes(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_record RECORD;
  v_participant_count INT;
  v_completed_count INT;
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

  -- 4. Count ALL Participants (excludes spectators)
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes válidos');
  END IF;

  -- 4.5. Check if race is finished or if caller is admin
  SELECT COUNT(*) INTO v_completed_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status = 'completed';

  IF v_completed_count < v_event_record.configured_winners AND v_completed_count < v_participant_count THEN
    -- Only admins can force distribute prizes before the race is finished
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RETURN json_build_object('success', false, 'message', 'La carrera aún no ha terminado o no tienes permisos para forzar la distribución.');
    END IF;
  END IF;

  -- 5. Finalize Event (ALWAYS, even if pot is 0)
  UPDATE events 
  SET status = 'completed', 
      completed_at = NOW(),
      winner_id = (SELECT user_id FROM game_players WHERE event_id = p_event_id AND status != 'spectator' ORDER BY completed_clues_count DESC, finish_time ASC LIMIT 1)
  WHERE id = p_event_id;

  -- 6. Assign final_placement to ALL non-spectator participants (ALWAYS)
  UPDATE game_players gp
  SET final_placement = ranked.pos
  FROM (
    SELECT id,
      ROW_NUMBER() OVER (
        ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST, last_active ASC NULLS LAST
      ) AS pos
    FROM game_players
    WHERE event_id = p_event_id
      AND status != 'spectator'
  ) AS ranked
  WHERE gp.id = ranked.id;

  -- 7. Calculate Pot
  v_total_collected := COALESCE(v_event_record.pot, 0);
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      RETURN json_build_object('success', true, 'message', 'Evento finalizado sin premios (Bote 0)', 'pot', 0);
  END IF;

  -- 8. Select Winners (Top N) and distribute prizes
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
            
            -- C. Log to Wallet Ledger
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
