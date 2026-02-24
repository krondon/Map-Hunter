-- Migration: Fix Race Completion & Prize Distribution (Robust)
-- Created: 2026-02-19
-- Purpose: 
-- 1. Ensure 'final_placement' is saved in 'game_players' to prevent position corruption.
-- 2. Allow 'register_race_finisher' to result in prize distribution even if called efficiently.
-- 3. Cleanup conflicting functions.

-- Drop conflicting function if it exists to ensure no triggers use it
DROP FUNCTION IF EXISTS public.check_and_set_winner(uuid, uuid, integer, integer);

-- Redefine distribute_event_prizes to be safe/idempotent
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

  -- 2. Idempotency Check: Si ya se distribuyeron premios, devolver éxito con los resultados previos
  IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
     -- Recuperar resultados previos si es posible, o simplemente devolver éxito
     RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true, 'already_distributed', true);
  END IF;

  -- 3. Define Distribution Shares
  IF v_event_record.configured_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_event_record.configured_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE -- Default 3 or more
    v_shares := ARRAY[0.50, 0.30, 0.20]; 
  END IF;

  -- 4. Count ALL Participants for Pot Calculation
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
      -- Finalizar evento sin premios
      UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id;
      RETURN json_build_object('success', true, 'message', 'Evento finalizado sin premios (Bote 0)', 'pot', 0);
  END IF;

  -- 6. Select Winners (Top N)
  v_rank := 0;
  
  -- Se seleccionan candidatos que hayan completado o estén activos (si el admin fuerza el cierre)
  -- Prioridad: Más pistas completadas, menor tiempo.
  FOR v_winners IN 
    SELECT * 
    FROM game_players 
    WHERE event_id = p_event_id 
    AND status IN ('active', 'completed')
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_event_record.configured_winners
  LOOP
    v_rank := v_rank + 1;
    
    -- Get share for this rank
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
            
            -- C. Add to results
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


-- Redefine register_race_finisher to be robust and set final_placement
CREATE OR REPLACE FUNCTION register_race_finisher(
  p_event_id uuid,
  p_user_id uuid
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_status text;
  v_configured_winners int;
  v_total_participants int;
  v_winners_count int;
  v_user_status text;
  v_position int;
  v_prize_amount int;
  v_is_already_finisher boolean;
  v_current_placement int;
BEGIN
  -- A. Bloqueo Evento
  SELECT status, configured_winners
  INTO v_event_status, v_configured_winners
  FROM events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- B. Validar Estado del Usuario
  SELECT status, final_placement INTO v_user_status, v_current_placement
  FROM game_players
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- Si ya completó, verifiquemos si necesitamos distribuir premios (caso borde)
  -- o simplemente devolver su info.
  IF v_user_status = 'completed' THEN
     -- Recuperar el premio si se le dio
     SELECT amount INTO v_prize_amount 
     FROM prize_distributions 
     WHERE event_id = p_event_id AND user_id = p_user_id;

     -- Si el evento ya está completed, retornamos que finalizó.
     RETURN json_build_object(
        'success', true, 
        'message', 'Ya has completado esta carrera', 
        'position', v_current_placement,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
     );
  END IF;

  -- Si el evento ya terminó (y el usuario NO estaba 'completed'), técnicamente llegó tarde.
  -- Pero lo marcamos como 'completed' con posición > winners?
  IF v_event_status = 'completed' THEN
     -- UPDATE status anyway so they see the result screen?
     -- Or reject?
     -- Let's reject for logic simplicity, OR accept as non-winner?
     -- Prompt implies "se esta corrompiendo la posicion".
     -- Let's mark them completed but with no prize.
     
     -- Count winners just to give a position
     SELECT COUNT(*) INTO v_winners_count FROM game_players WHERE event_id = p_event_id AND status = 'completed';
     v_position := v_winners_count + 1;

     UPDATE game_players
     SET status = 'completed', finish_time = NOW(), final_placement = v_position, completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id)
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object('success', true, 'position', v_position, 'prize', 0, 'race_completed', true);
  END IF;

  IF v_user_status != 'active' THEN
     RETURN json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  END IF;


  -- C. Contar ganadores actuales
  SELECT COUNT(*) INTO v_winners_count
  FROM game_players
  WHERE event_id = p_event_id AND status = 'completed';

  -- D. Calcular Posición
  v_position := v_winners_count + 1;

  -- E. Registrar Finalización y POSICIÓN (CRITICAL FIX)
  UPDATE game_players
  SET 
    status = 'completed',
    finish_time = NOW(),
    completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id),
    final_placement = v_position -- Guardar la posición
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- G. Resolver Apuestas (Si es el PRIMER ganador)
  -- Esto garantiza que las apuestas se paguen inmediatamente al detectar un ganador.
  -- Se asume que resolve_event_bets existe y maneja internamente si ya se resolvieron.
  IF v_position = 1 THEN
     PERFORM public.resolve_event_bets(p_event_id, p_user_id);
  END IF;

  -- H. Verificar si se cierra el evento (Podio Lleno O Último Participante)
  -- NOTA: v_total_participants incluye al usuario actual que acabamos de marcar como completed.
  SELECT COUNT(*) INTO v_total_participants
  FROM game_players
  WHERE event_id = p_event_id 
  AND status IN ('active', 'completed'); 

  IF (v_position >= v_configured_winners) OR (v_position >= v_total_participants) THEN
      
      -- Llamada a premios
      PERFORM distribute_event_prizes(p_event_id);
      
      -- Recuperar mi premio
      SELECT amount INTO v_prize_amount 
      FROM prize_distributions 
      WHERE event_id = p_event_id AND user_id = p_user_id;

      RETURN json_build_object(
        'success', true, 
        'position', v_position, 
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
      );
  END IF;

  -- Retorno normal (No se cerró el evento aún)
  RETURN json_build_object(
    'success', true, 
    'position', v_position, 
    'prize', 0,
    'race_completed', false
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;
