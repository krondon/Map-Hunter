-- =============================================================================
-- MIGRACIÓN: RPCs para get-clues y skip-clue (Alta Concurrencia 200+)
-- Fecha: 2026-03-03
-- Objetivo: Migrar endpoints restantes de game-play Edge Function a RPCs
--           atómicos para reducir conexiones y latencia.
-- =============================================================================

-- =============================================================================
-- 1. RPC: get_clues_with_progress
-- Reemplaza: game-play/get-clues
-- Antes: 2 queries + procesamiento en Edge Function
-- Ahora: 1 sola llamada, lógica sequencial en SQL
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_clues_with_progress(
    p_event_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB := '[]'::JSONB;
    v_clue RECORD;
    v_progress RECORD;
    v_prev_completed BOOLEAN := TRUE; -- Primera pista siempre desbloqueada
    v_is_completed BOOLEAN;
    v_is_locked BOOLEAN;
    v_clue_json JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    -- Iterar sobre las pistas del evento en orden secuencial
    FOR v_clue IN
        SELECT c.id, c.event_id, c.sequence_index, c.title, c.description,
               c.hint, c.type, c.puzzle_type, c.minigame_url,
               c.riddle_question, c.xp_reward, c.created_at,
               c.latitude, c.longitude
        FROM clues c
        WHERE c.event_id = p_event_id
        ORDER BY c.sequence_index ASC
    LOOP
        -- Obtener progreso del usuario para esta pista
        SELECT ucp.is_completed, ucp.is_locked
        INTO v_progress
        FROM user_clue_progress ucp
        WHERE ucp.user_id = v_user_id AND ucp.clue_id = v_clue.id;

        -- Lógica secuencial (Mario Kart Style)
        v_is_locked := NOT v_prev_completed;
        v_is_completed := COALESCE(v_progress.is_completed, FALSE);

        -- Integrity Check: Una pista no puede estar completada si está bloqueada
        IF v_is_locked THEN
            v_is_completed := FALSE;
        END IF;

        -- Construir JSON de la pista (SIN riddle_answer por seguridad)
        v_clue_json := jsonb_build_object(
            'id', v_clue.id,
            'event_id', v_clue.event_id,
            'sequence_index', v_clue.sequence_index,
            'title', v_clue.title,
            'description', v_clue.description,
            'hint', v_clue.hint,
            'type', v_clue.type,
            'puzzle_type', v_clue.puzzle_type,
            'minigame_url', v_clue.minigame_url,
            'riddle_question', v_clue.riddle_question,
            'xp_reward', v_clue.xp_reward,
            'created_at', v_clue.created_at,
            'latitude', v_clue.latitude,
            'longitude', v_clue.longitude,
            'is_completed', v_is_completed,
            'isCompleted', v_is_completed,
            'is_locked', v_is_locked
        );

        v_result := v_result || v_clue_json;

        -- Actualizar para la siguiente iteración
        v_prev_completed := v_is_completed;
    END LOOP;

    RETURN v_result;
END;
$$;


-- =============================================================================
-- 2. RPC: skip_clue_rpc
-- Reemplaza: game-play/skip-clue
-- Antes: 4 queries secuenciales en Edge Function
-- Ahora: 1 sola llamada atómica
-- =============================================================================
CREATE OR REPLACE FUNCTION public.skip_clue_rpc(
    p_clue_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_clue RECORD;
    v_next_clue RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- 1. Obtener datos de la pista
    SELECT * INTO v_clue FROM clues WHERE id = p_clue_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Clue not found');
    END IF;

    -- 2. Marcar pista como completada (skip)
    INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked, completed_at)
    VALUES (v_user_id, p_clue_id, true, false, NOW())
    ON CONFLICT (user_id, clue_id)
    DO UPDATE SET is_completed = true, completed_at = NOW(), is_locked = false;

    -- 3. Desbloquear siguiente pista
    SELECT id INTO v_next_clue
    FROM clues
    WHERE event_id = v_clue.event_id AND sequence_index > v_clue.sequence_index
    ORDER BY sequence_index ASC
    LIMIT 1;

    IF v_next_clue IS NOT NULL THEN
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked)
        VALUES (v_user_id, v_next_clue.id, false, false)
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET is_locked = false;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Clue skipped');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- Permisos
GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clues_with_progress(UUID) TO service_role;

GRANT EXECUTE ON FUNCTION public.skip_clue_rpc(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.skip_clue_rpc(BIGINT) TO service_role;
