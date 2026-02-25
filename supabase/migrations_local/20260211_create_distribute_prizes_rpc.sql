-- RPC: Distribute Event Prizes
-- Created: 2026-02-11
-- Logic: 
-- 1. Counts ALL participants (active, completed, banned, suspended, eliminated) for Pot Calculation.
-- 2. Calculates Pot = Participants * EntryFee * 0.70.
-- 3. Distributes Pot to top winners based on configured_winners.
-- 4. 3 Winners -> 50%, 30%, 20%
-- 5. 2 Winners -> 70%, 30%
-- 6. 1 Winner  -> 100%

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

  IF v_event_record.status = 'completed' AND v_event_record.completed_at IS NOT NULL THEN
     -- Check if prizes already distributed (Idempotency)
     IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
        RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true);
     END IF;
  END IF;

  -- 2. Define Distribution Shares based on configured_winners
  -- percentages of the 70% pot.
  IF v_event_record.configured_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_event_record.configured_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE -- Default 3 or more (though likely capped at 3 by UI)
    v_shares := ARRAY[0.50, 0.30, 0.20]; 
  END IF;

  -- 3. Count ALL Participants (Paying users)
  -- Valid statuses for payment count: active, completed, banned, suspended, eliminated.
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes válidos');
  END IF;

  -- 4. Calculate Pot
  -- Ensure entry_fee is numeric/int
  v_total_collected := v_participant_count * (COALESCE(v_event_record.entry_fee, 0));
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      -- Mark completed anyway? Or just return.
      UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id;
      RETURN json_build_object('success', true, 'message', 'Evento finalizado sin premios (Bote 0)', 'pot', 0);
  END IF;

  -- 5. Select Winners (Top N)
  v_rank := 0;
  
  FOR v_winners IN 
    SELECT * 
    FROM game_players 
    WHERE event_id = p_event_id 
    AND status IN ('active', 'completed') -- Only active/completed can win? purely logic choice.
    -- Ranking Logic: Completed Clues DESC, Finish Time ASC (Nulls Last for active)
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_event_record.configured_winners
  LOOP
    v_rank := v_rank + 1;
    
    -- Get share for this rank
    IF v_rank <= array_length(v_shares, 1) THEN
        v_share := v_shares[v_rank];
        v_prize_amount := floor(v_distributable_pot * v_share); -- Floor to avoid decimals issues

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
            
            -- C. Add to results
            v_distribution_results := array_append(v_distribution_results, jsonb_build_object(
                'user_id', v_winners.user_id,
                'rank', v_rank,
                'amount', v_prize_amount
            ));
        END IF;
    END IF;
  END LOOP;

  -- 6. Finalize Event
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
