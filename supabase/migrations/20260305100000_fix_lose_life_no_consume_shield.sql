-- Fix: lose_life no debe consumir el escudo/devolución.
-- La protección (is_protected) solo debe romperse por ataques de otros jugadores
-- (manejados por combat_events / execute_combat_power), no por perder vidas en minijuegos.

CREATE OR REPLACE FUNCTION "public"."lose_life"("p_user_id" "uuid", "p_event_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    current_lives integer;
    new_lives integer;
BEGIN
    -- Select with locking
    SELECT lives INTO current_lives
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player not found (Event: %, User: %)', p_event_id, p_user_id;
    END IF;

    -- Perder una vida en un minijuego NO consume la protección defensiva.
    -- El escudo y la devolución solo se rompen por ataques de otros jugadores
    -- (combat_events: shield_blocked, reflected).

    IF current_lives > 0 THEN
        new_lives := current_lives - 1;
    ELSE
        new_lives := 0;
    END IF;

    UPDATE public.game_players
    SET lives = new_lives,
        updated_at = now()
    WHERE event_id = p_event_id AND user_id = p_user_id;

    RETURN new_lives;
END;
$$;

-- ============================================================================
-- Fix: cleanup_expired_defenses no debe desactivar shield/return por expires_at.
-- Escudo y devolución son event-driven (solo se rompen por combat_events).
-- Solo la invisibilidad es temporal y debe limpiarse por expiración.
-- ============================================================================
CREATE OR REPLACE FUNCTION "public"."cleanup_expired_defenses"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    fixed_count integer;
BEGIN
    -- Solo limpia protección de jugadores cuyo poder activo era INVISIBILIDAD (temporal).
    -- Escudo y devolución persisten hasta ser rotos por un ataque (combat_event).
    WITH updated_rows AS (
        UPDATE public.game_players gp
        SET is_protected = false,
            updated_at = NOW()
        WHERE gp.is_protected = true
        AND NOT EXISTS (
            SELECT 1 
            FROM public.active_powers ap
            WHERE ap.target_id = gp.id
            AND ap.power_slug = 'invisibility'
            AND ap.expires_at > NOW()
        )
        -- Solo desproteger si NO tienen shield/return activo en active_powers
        AND NOT EXISTS (
            SELECT 1
            FROM public.active_powers ap2
            WHERE ap2.target_id = gp.id
            AND ap2.power_slug IN ('shield', 'return')
        )
        RETURNING 1
    )
    SELECT count(*) INTO fixed_count FROM updated_rows;

    IF fixed_count > 0 THEN
        RAISE NOTICE 'Cleaned up % expired defense states.', fixed_count;
    END IF;
END;
$$;

-- ============================================================================
-- Fix: cleanup_expired_powers no debe borrar filas de shield/return por expires_at.
-- Escudo y devolución solo se eliminan via combat_events (shield_blocked/reflected).
-- ============================================================================
CREATE OR REPLACE FUNCTION "public"."cleanup_expired_powers"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.game_players
  SET is_frozen = false, frozen_until = null
  WHERE is_frozen = true AND frozen_until < now();

  -- No borrar shield/return expirados por tiempo: son event-driven
  DELETE FROM public.active_powers
  WHERE expires_at < now()
    AND power_slug NOT IN ('shield', 'return');
END;
$$;
