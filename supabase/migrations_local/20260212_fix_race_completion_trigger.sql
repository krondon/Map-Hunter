-- Migration: Fix Race Completion Trigger Logic
-- Created: 2026-02-12
-- Purpose: 
-- Fixes a bug where prize distribution was ONLY triggered if winners_count == configured_winners (default 3).
-- This caused events with fewer participants (e.g. 1 or 2 players) to NEVER distribute prizes automatically.
--
-- Change:
-- Now triggers distribution if (positions_filled >= configured_winners) OR (positions_filled >= total_active_participants).
-- Also retrieves and returns the actual prize won immediately.

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
  v_entry_fee int;
  v_total_participants int;
  v_pot_total numeric;
  v_winners_count int;
  v_user_status text;
  v_is_already_finisher boolean;
  v_position int;
  v_prize_amount int;
  v_prize_share numeric;
  v_result json;
BEGIN
  -- A. Validaciones Iniciales (Bloqueo Row-Level para el Evento)
  SELECT status, configured_winners, entry_fee
  INTO v_event_status, v_configured_winners, v_entry_fee
  FROM events
  WHERE id = p_event_id
  FOR UPDATE; -- LOCK para evitar condiciones de carrera en cierre de evento

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  IF v_event_status = 'completed' THEN
     RETURN json_build_object('success', false, 'message', 'El evento ya ha finalizado', 'race_completed', true);
  END IF;

  -- B. Validar Estado del Usuario
  SELECT status INTO v_user_status
  FROM game_players
  WHERE event_id = p_event_id AND user_id = p_user_id;

  IF v_user_status = 'completed' THEN
     RETURN json_build_object('success', false, 'message', 'Ya has completado esta carrera');
  END IF;

  IF v_user_status != 'active' THEN
     RETURN json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  END IF;

  -- NEW STEP: Get Total Participants (Active + Completed) to determine if everyone finished
  -- We include active and completed.
  SELECT COUNT(*) INTO v_total_participants
  FROM game_players
  WHERE event_id = p_event_id 
  AND status IN ('active', 'completed');

  -- C. Contar ganadores actuales COMPLETED (con bloqueo para consistencia)
  SELECT COUNT(*) INTO v_winners_count
  FROM game_players
  WHERE event_id = p_event_id AND status = 'completed';

  -- Si ya hay suficientes ganadores (aunque el evento no esté 'completed' por latencia), rechazar
  IF v_winners_count >= v_configured_winners THEN
     -- Auto-cerrar si no lo estaba
     UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id;
     RETURN json_build_object('success', false, 'message', 'Podio completo', 'race_completed', true);
  END IF;

  -- D. Calcular Posición
  v_position := v_winners_count + 1;

  -- E. Registrar Finalización (Update game_players)
  UPDATE game_players
  SET 
    status = 'completed',
    finish_time = NOW(),
    completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id) -- Asegurar max clues
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- G. Verificar si el evento debe cerrarse FINALMENTE 
  -- FIX: Close if we reached configured winners OR if we are the last active participant
  -- Note: v_total_participants includes the user we just updated (was active, now completed is still in set)
  -- v_winners_count was count BEFORE update.
  -- v_position is current rank.
  -- If v_position == v_total_participants, then everyone has finished!
  
  IF (v_position >= v_configured_winners) OR (v_position >= v_total_participants) THEN
      UPDATE events 
      SET 
        status = 'completed', 
        winner_id = (CASE WHEN v_position = 1 THEN p_user_id ELSE winner_id END), -- Registrar 1ro como winner principal si se desea
        completed_at = NOW() 
      WHERE id = p_event_id;

      -- AUTO-DISTRIBUTE PRIZES
      PERFORM distribute_event_prizes(p_event_id);

      -- Retrieve the assigned prize for this user
      SELECT amount INTO v_prize_amount 
      FROM prize_distributions 
      WHERE event_id = p_event_id AND user_id = p_user_id;
      
      -- Return extra flag
       RETURN json_build_object(
        'success', true, 
        'position', v_position, 
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
      );
  END IF;

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
