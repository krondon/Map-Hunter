-- =============================================================================
-- MIGRACIÓN: RPC admin_force_apply_power
-- Fecha: 2026-03-03
-- Propósito: Despliega la función que permite al admin aplicar un poder
--            directamente a un jugador desde el panel de administración,
--            sin consumir munición ni respetar defensas.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_force_apply_power(
    p_event_id uuid,
    p_target_userId uuid,
    p_power_slug text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_userId uuid := auth.uid();
    v_admin_gp_id uuid;
    v_target_gp_id uuid;
    v_power_id uuid;
    v_power_duration int;
    v_now timestamptz := now();
BEGIN
    -- 1. Verificar que el caller es admin
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = v_admin_userId AND role = 'admin'
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- 2. Obtener el game_player_id del target
    SELECT id INTO v_target_gp_id 
    FROM public.game_players 
    WHERE event_id = p_event_id AND user_id = p_target_userId;

    IF v_target_gp_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'target_not_in_event');
    END IF;

    -- 3. Obtener o crear game_player del admin (para FK en active_powers/combat_events)
    SELECT id INTO v_admin_gp_id 
    FROM public.game_players 
    WHERE event_id = p_event_id AND user_id = v_admin_userId;

    IF v_admin_gp_id IS NULL THEN
        INSERT INTO public.game_players (event_id, user_id, status, lives)
        VALUES (p_event_id, v_admin_userId, 'spectator', 0)
        RETURNING id INTO v_admin_gp_id;
    END IF;

    -- 4. Obtener detalles del poder
    SELECT id, duration INTO v_power_id, v_power_duration 
    FROM public.powers WHERE slug = p_power_slug;

    IF v_power_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'power_not_found');
    END IF;

    -- 5. Lógica especial para life_steal (quitar vida al target)
    IF p_power_slug = 'life_steal' THEN
        UPDATE public.game_players 
        SET lives = GREATEST(lives - 1, 0) 
        WHERE id = v_target_gp_id;
        -- El admin no gana vidas; solo quita al target
    END IF;

    -- 6. Aplicar efecto visual (active_powers)
    --    Se ignoran escudos intencionalmente en la versión admin.
    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
    VALUES (p_event_id, v_admin_gp_id, v_target_gp_id, v_power_id, p_power_slug, 
            v_now + (COALESCE(v_power_duration, 20) || ' seconds')::interval);

    -- 7. Registrar evento de combate para auditoría
    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
    VALUES (p_event_id, v_admin_gp_id, v_target_gp_id, v_power_id, p_power_slug, 'admin_force');

    RETURN json_build_object('success', true);
END;
$$;

-- Permitir que usuarios autenticados llamen al RPC
-- (la función verifica internamente que sea admin)
GRANT EXECUTE ON FUNCTION public.admin_force_apply_power(uuid, uuid, text)
    TO "authenticated", "service_role";
