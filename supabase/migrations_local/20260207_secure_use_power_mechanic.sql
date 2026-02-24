-- Migration: Secure use_power_mechanic with auth.uid() validation
-- Date: 2026-02-07
-- Purpose: Prevent impersonation attacks by validating that the caller owns the caster

CREATE OR REPLACE FUNCTION public.use_power_mechanic(
    p_caster_id uuid,
    p_target_id uuid,
    p_power_slug text
) returns json
language plpgsql
SECURITY DEFINER
SET search_path = public
as $$
DECLARE
    v_power_id uuid;
    v_power_duration int;
    v_event_id uuid;
    v_now timestamptz := timezone('utc', now());
    v_shield_row_id uuid;
    v_shield_power_id uuid;
    v_return_row_id uuid;
    v_return_power_id uuid;
    v_returned boolean := false;
    v_returned_by_name text;
    v_final_caster uuid := p_caster_id;
    v_final_target uuid := p_target_id;
    v_attacker_lives int;
    v_target_lives int;
    v_rival_record record;
BEGIN
    -- 0. SECURITY: Validate caller owns the caster
    -- Prevents impersonation attacks where a malicious client sends another player's ID
    IF NOT EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.id = p_caster_id AND gp.user_id = auth.uid()
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- 1. OBTENCIÓN DE DATOS BÁSICOS
    SELECT event_id INTO v_event_id FROM public.game_players WHERE id = p_caster_id;
    
    -- Obtener ID y duración del poder usado
    SELECT id, duration INTO v_power_id, v_power_duration FROM public.powers WHERE slug = p_power_slug;
    
    IF v_power_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'power_not_found');
    END IF;

    -- 2. CONSUMO DE MUNICIÓN (Solo si es el caster original quien paga)
    UPDATE public.player_powers 
    SET quantity = quantity - 1, last_used_at = v_now
    WHERE game_player_id = p_caster_id AND power_id = v_power_id AND quantity > 0;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'no_ammo');
    END IF;

    -- 3. AUTO-BUFFS (Return, Shield, Invisibility)
    IF p_power_slug IN ('invisibility', 'shield', 'return') THEN
        
        -- Validación especial para ESCUDO: No permitir apilar
        IF p_power_slug = 'shield' AND EXISTS (SELECT 1 FROM public.active_powers WHERE target_id = p_caster_id AND power_slug = 'shield') THEN
             UPDATE public.player_powers SET quantity = quantity + 1 WHERE game_player_id = p_caster_id AND power_id = v_power_id;
             RETURN json_build_object('success', false, 'error', 'shield_already_active');
        END IF;

        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, p_caster_id, p_caster_id, v_power_id, p_power_slug, 
                CASE 
                    WHEN p_power_slug = 'shield' THEN v_now + interval '1 year'
                    WHEN p_power_slug = 'return' THEN v_now + interval '1 year'
                    ELSE v_now + (COALESCE(v_power_duration, 20) || ' seconds')::interval
                END);
        
        RETURN json_build_object('success', true, 'action', p_power_slug || '_activated');
    END IF;

    -- 4. ATAQUE DE ÁREA (Blur Screen)
    IF p_power_slug = 'blur_screen' THEN
        DECLARE
            v_caster_affected boolean := false;
            v_return_row_id_blur uuid;
            v_returned_by_name_blur text;
        BEGIN
        FOR v_rival_record IN 
            SELECT id FROM public.game_players 
            WHERE event_id = v_event_id AND id != p_caster_id
        LOOP
            -- Check Escudo Individual (Prioridad 1)
            SELECT id, power_id INTO v_shield_row_id, v_shield_power_id FROM public.active_powers 
            WHERE target_id = v_rival_record.id AND power_slug = 'shield' LIMIT 1;
            
            IF v_shield_row_id IS NOT NULL THEN
                -- Escudo bloquea el ataque
                DELETE FROM public.active_powers WHERE id = v_shield_row_id;
                INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                VALUES (v_event_id, p_caster_id, v_rival_record.id, v_shield_power_id, 'shield_break', v_now + interval '4 seconds');
                
                INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                VALUES (v_event_id, p_caster_id, v_rival_record.id, v_power_id, p_power_slug, 'shield_blocked');
            ELSE
                -- Check Return Individual (Prioridad 2)
                SELECT id INTO v_return_row_id_blur FROM public.active_powers 
                WHERE target_id = v_rival_record.id AND power_slug = 'return' AND expires_at > v_now LIMIT 1;
                
                IF v_return_row_id_blur IS NOT NULL THEN
                    -- Return activo: consumir y reflejar al caster
                    DELETE FROM public.active_powers WHERE id = v_return_row_id_blur;
                    
                    -- Obtener nombre del jugador que reflejó
                    SELECT name INTO v_returned_by_name_blur FROM public.profiles 
                    WHERE id = (SELECT user_id FROM public.game_players WHERE id = v_rival_record.id);
                    
                    -- Aplicar blur al CASTER (solo una vez aunque varios tengan return)
                    IF NOT v_caster_affected THEN
                        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                        VALUES (v_event_id, v_rival_record.id, p_caster_id, v_power_id, p_power_slug, 
                                v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                        v_caster_affected := true;
                    END IF;
                    
                    -- Log de reflexión
                    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                    VALUES (v_event_id, p_caster_id, v_rival_record.id, v_power_id, p_power_slug, 'reflected');
                ELSE
                    -- Sin escudo ni return: aplicar blur normalmente al rival
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, p_caster_id, v_rival_record.id, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                    
                    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                    VALUES (v_event_id, p_caster_id, v_rival_record.id, v_power_id, p_power_slug, 'success');
                END IF;
            END IF;
        END LOOP;
        
        -- Retornar con información de reflexión si hubo (DENTRO del bloque donde las variables están en scope)
        IF v_caster_affected THEN
            RETURN json_build_object('success', true, 'returned', true, 'returned_by_name', v_returned_by_name_blur);
        ELSE
            RETURN json_build_object('success', true, 'message', 'broadcast_complete');
        END IF;
        END;
    END IF;

    -- 5. ATAQUES DIRECTOS
    
    -- A. Check Invisibilidad
    IF EXISTS (SELECT 1 FROM public.active_powers WHERE target_id = p_target_id AND power_slug = 'invisibility' AND expires_at > v_now) THEN
        UPDATE public.player_powers SET quantity = quantity + 1 WHERE game_player_id = p_caster_id AND power_id = v_power_id;
        RETURN json_build_object('success', false, 'error', 'target_invisible');
    END IF;

    -- B. Check Escudo (Prioridad Media: Bloquea el ataque antes de Return)
    SELECT id INTO v_shield_row_id FROM public.active_powers 
    WHERE target_id = p_target_id AND power_slug = 'shield' AND expires_at > v_now LIMIT 1;

    IF v_shield_row_id IS NOT NULL THEN
        -- 1. Consumir el escudo
        DELETE FROM public.active_powers WHERE id = v_shield_row_id;
        
        -- 2. Log del bloqueo
        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
        VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'shield_blocked');

        -- 3. Retornar éxito (el ataque fue "exitoso" en ser procesado, pero bloqueado)
        -- Importante: No se inserta el poder dañino en active_powers.
        RETURN json_build_object('success', true, 'blocked', true, 'reason', 'shield_absorbed');
    END IF;
    -- Obtener efecto return activo
    SELECT id INTO v_return_row_id FROM public.active_powers 
    WHERE target_id = p_target_id AND power_slug = 'return' AND expires_at > v_now LIMIT 1;
    
    IF v_return_row_id IS NOT NULL THEN
       -- 1. Consumir el poder 'return' del defensor
       DELETE FROM public.active_powers WHERE id = v_return_row_id;
       
       -- 2. Intercambio de roles
       v_returned := true;
       v_final_caster := p_target_id; -- Defensor contrataca
       v_final_target := p_caster_id; -- Atacante recibe su propia medicina
       
       -- 3. Log
       INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
       VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'reflected');
       
       -- 4. Nombre visual
       SELECT name INTO v_returned_by_name FROM public.profiles 
       WHERE id = (SELECT user_id FROM public.game_players WHERE id = p_target_id);
    END IF;
    
    -- D. Ejecución del Efecto (Reflejado o Normal)
    -- CASO 1: Reflejado (Return activado)
    IF v_returned THEN
        IF p_power_slug = 'life_steal' THEN
           -- Modificar vidas (Atacante pierde, Defensor gana)
           UPDATE public.game_players SET lives = GREATEST(lives - 1, 0) WHERE id = v_final_target;
           UPDATE public.game_players SET lives = LEAST(lives + 1, 3) WHERE id = v_final_caster;
        END IF;

        -- Insertar efecto contra el NUEVO target (el atacante original)
        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, v_final_caster, v_final_target, v_power_id, p_power_slug, 
                v_now + (GREATEST(COALESCE(v_power_duration, 10), 5) || ' seconds')::interval);

        RETURN json_build_object('success', true, 'returned', true, 'returned_by_name', v_returned_by_name);
    END IF;

    -- CASO 2: Normal (Life Steal)
    IF p_power_slug = 'life_steal' THEN
       SELECT lives INTO v_target_lives FROM public.game_players WHERE id = p_target_id FOR UPDATE;
       -- Si no tiene vidas, no se consume el efecto visual (pero sí la carga, según lógica anterior? O refund?)
       -- En lógica anterior (Dart) se consumía. Aquí mantenemos update inicial (consumo).
       
       IF v_target_lives <= 0 THEN
           RETURN json_build_object('success', true, 'stolen', false, 'reason', 'target_no_lives');
       END IF;
       
       UPDATE public.game_players SET lives = GREATEST(lives - 1, 0) WHERE id = p_target_id;
       UPDATE public.game_players SET lives = LEAST(lives + 1, 3) WHERE id = p_caster_id;
       
       INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
       VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'success');
       
       INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
       VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, v_now + interval '5 seconds');

       RETURN json_build_object('success', true);
    END IF;

    -- CASO 3: Normal (Otros)
    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
    VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 
            v_now + (GREATEST(COALESCE(v_power_duration, 10), 5) || ' seconds')::interval);
            
    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
    VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'success');
    
    RETURN json_build_object('success', true);

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback occurirá automáticamente, pero retornamos JSON de error limpio
        RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
