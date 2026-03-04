-- =============================================================================
-- MIGRACIÓN: Fix submit_clue_answer RPC signature for PostgREST named params
-- Fecha: 2026-03-03
-- Objetivo: Garantizar que la función use parámetros nombrados
--           (p_clue_id, p_answer) para evitar PGRST202 en llamadas RPC.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.submit_clue_answer(
    p_clue_id BIGINT,
    p_answer TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_clue RECORD;
    v_gp_id UUID;
    v_event_id UUID;
    v_next_clue RECORD;
    v_is_already_completed BOOLEAN;
    v_coins_earned INTEGER;
    v_new_balance INTEGER;
    v_total_players INTEGER;
    v_position INTEGER;
    v_xp_reward INTEGER;
    v_current_total_xp BIGINT;
    v_new_total_xp BIGINT;
    v_new_level INTEGER;
    v_new_partial_xp BIGINT;
    v_xp_for_next INTEGER;
    v_profession TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_clue FROM clues WHERE id = p_clue_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Clue not found');
    END IF;

    v_event_id := v_clue.event_id;

    IF v_clue.riddle_answer IS NOT NULL AND v_clue.riddle_answer != '' THEN
        IF LOWER(TRIM(p_answer)) != LOWER(TRIM(v_clue.riddle_answer)) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Incorrect answer');
        END IF;
    END IF;

    SELECT is_completed INTO v_is_already_completed
    FROM user_clue_progress
    WHERE user_id = v_user_id AND clue_id = p_clue_id;

    IF v_is_already_completed IS NOT TRUE THEN
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked, completed_at)
        VALUES (v_user_id, p_clue_id, true, false, NOW())
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET is_completed = true, completed_at = NOW(), is_locked = false;

        UPDATE game_players
        SET
            completed_clues_count = completed_clues_count + 1,
            last_active = NOW()
        WHERE user_id = v_user_id AND event_id = v_event_id
        RETURNING id, coins INTO v_gp_id, v_new_balance;

        SELECT COUNT(*) INTO v_total_players FROM game_players WHERE event_id = v_event_id;

        SELECT position INTO v_position FROM (
            SELECT user_id, RANK() OVER (ORDER BY completed_clues_count DESC, last_active ASC) as position
            FROM game_players
            WHERE event_id = v_event_id
        ) r WHERE r.user_id = v_user_id;

        IF v_position = 1 THEN
            v_coins_earned := floor(random() * (80-50+1) + 50);
        ELSIF v_position = v_total_players AND v_total_players > 1 THEN
            v_coins_earned := floor(random() * (150-120+1) + 120);
        ELSE
            v_coins_earned := floor(random() * (120-80+1) + 80);
        END IF;

        UPDATE game_players SET coins = coins + v_coins_earned WHERE id = v_gp_id
        RETURNING coins INTO v_new_balance;

        SELECT total_xp, level, profession INTO v_current_total_xp, v_new_level, v_profession
        FROM profiles WHERE id = v_user_id;

        v_xp_reward := COALESCE(v_clue.xp_reward, 50);
        v_new_total_xp := v_current_total_xp + v_xp_reward;

        v_new_level := 1;
        v_new_partial_xp := v_new_total_xp;
        LOOP
            v_xp_for_next := v_new_level * 100;
            EXIT WHEN v_new_partial_xp < v_xp_for_next;
            v_new_partial_xp := v_new_partial_xp - v_xp_for_next;
            v_new_level := v_new_level + 1;
        END LOOP;

        UPDATE profiles SET
            total_xp = v_new_total_xp,
            experience = v_new_partial_xp,
            level = v_new_level,
            updated_at = NOW()
        WHERE id = v_user_id;

    ELSE
        SELECT coins INTO v_new_balance FROM game_players WHERE user_id = v_user_id AND event_id = v_event_id;
        v_coins_earned := 0;
    END IF;

    SELECT * INTO v_next_clue
    FROM clues
    WHERE event_id = v_event_id AND sequence_index > v_clue.sequence_index
    ORDER BY sequence_index ASC
    LIMIT 1;

    IF v_next_clue IS NOT NULL THEN
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked)
        VALUES (v_user_id, v_next_clue.id, false, false)
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET is_locked = false;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Clue completed successfully',
        'raceCompleted', (v_next_clue IS NULL),
        'coins_earned', v_coins_earned,
        'new_balance', v_new_balance,
        'eventId', v_event_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'detail', SQLSTATE
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_clue_answer(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_clue_answer(BIGINT, TEXT) TO service_role;

NOTIFY pgrst, 'reload schema';
