
DECLARE
    v_power_slug text;
    v_power_duration integer;
    v_has_shield boolean;
    v_quantity integer;
BEGIN
    -- 1. Obtener detalles del poder
    SELECT slug, duration INTO v_power_slug, v_power_duration 
    FROM public.powers WHERE id = p_power_id;

    -- 2. Verificar si el atacante tiene el poder disponible
    SELECT quantity INTO v_quantity 
    FROM public.player_powers 
    WHERE game_player_id = p_caster_id AND power_id = p_power_id;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
        RETURN json_build_object('success', false, 'reason', 'no_quantity');
    END IF;

    -- 3. Verificar si el objetivo tiene un escudo activo
    SELECT EXISTS (
        SELECT 1 FROM public.active_powers 
        WHERE target_id = p_target_id 
        AND power_slug = 'shield'
        AND expires_at > now()
    ) INTO v_has_shield;

    -- 4. Lógica de resolución
    IF v_has_shield THEN
        -- ELIMINAR EL ESCUDO (Se consume al proteger)
        DELETE FROM public.active_powers 
        WHERE target_id = p_target_id AND power_slug = 'shield';

        -- REGISTRAR EVENTO DE BLOQUEO (Para el feedback del defensor)
        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
        VALUES (p_event_id, p_caster_id, p_target_id, p_power_id, v_power_slug, 'shield_blocked');

        -- DESCONTAR PODER AL ATACANTE
        UPDATE public.player_powers 
        SET quantity = quantity - 1 
        WHERE game_player_id = p_caster_id AND power_id = p_power_id;

        RETURN json_build_object('success', true, 'blocked', true, 'reason', 'shield_absorbed');

    ELSE
        -- NO HAY ESCUDO: APLICAR EL PODER
        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (p_event_id, p_caster_id, p_target_id, p_power_id, v_power_slug, now() + (v_power_duration || ' seconds')::interval);

        -- REGISTRAR EVENTO DE ÉXITO
        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
        VALUES (p_event_id, p_caster_id, p_target_id, p_power_id, v_power_slug, 'success');

        -- DESCONTAR PODER AL ATACANTE
        UPDATE public.player_powers 
        SET quantity = quantity - 1 
        WHERE game_player_id = p_caster_id AND power_id = p_power_id;

        RETURN json_build_object('success', true, 'blocked', false, 'reason', 'applied');
    END IF;
END;
