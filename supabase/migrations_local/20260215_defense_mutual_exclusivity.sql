-- ============================================================
-- Migration: Defense Mutual Exclusivity Fix
-- Date: 2026-02-15
-- 
-- Fixes the "solapamiento" (overlap) bug where defense powers
-- (Shield, Invisibility, Return) can interfere with each other.
--
-- Root causes addressed:
--   1. Invisibility was excluded from is_protected check
--   2. Shield/Return consumption didn't always clear is_protected
--   3. No deactivation RPC for timed defenses (invisibility)
--
-- Builds on: 20260214_shield_consistency_fix.sql
-- ============================================================

-- ============================================================
-- 0. PRE-REQUISITE: Ensure updated_at column exists
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'game_players' AND column_name = 'updated_at') THEN
        ALTER TABLE public.game_players ADD COLUMN updated_at timestamptz DEFAULT now();
    END IF;
END $$;

-- ============================================================
-- 1. NEW RPC: deactivate_defense
--    Called by the client when a timed defense (invisibility)
--    expires. Atomically clears is_protected and active_powers.
-- ============================================================
CREATE OR REPLACE FUNCTION public.deactivate_defense(
    p_game_player_id uuid
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Security: Validate caller owns the player
    IF NOT EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.id = p_game_player_id AND gp.user_id = auth.uid()
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- Clear protection flag
    UPDATE public.game_players 
    SET is_protected = false, updated_at = now() 
    WHERE id = p_game_player_id AND is_protected = true;

    -- Clean up any expired defense rows in active_powers
    DELETE FROM public.active_powers 
    WHERE target_id = p_game_player_id 
      AND power_slug IN ('shield', 'return', 'invisibility')
      AND expires_at <= now();

    RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- 2. UPDATE use_power_mechanic:
--    - Include invisibility in the is_protected mutual exclusion
--    - Return defense_slug in response for frontend tracking
-- ============================================================
CREATE OR REPLACE FUNCTION public.use_power_mechanic(
    p_caster_id uuid, 
    p_target_id uuid, 
    p_power_slug text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_power_id uuid;
    v_power_duration int;
    v_event_id uuid;
    v_now timestamptz := timezone('utc', now());
    v_caster_is_protected boolean;
    v_target_is_protected boolean;
    v_defense_slug text;
    v_final_caster uuid := p_caster_id;
    v_final_target uuid := p_target_id;
    v_returned boolean := false;
    v_returned_by_name text;
    v_target_lives int;
BEGIN
    -- 0. SECURITY: Validate caller owns the caster
    IF NOT EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.id = p_caster_id AND gp.user_id = auth.uid()
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- 1. OBTENCIÓN DE DATOS BÁSICOS
    SELECT event_id, is_protected INTO v_event_id, v_caster_is_protected 
    FROM public.game_players WHERE id = p_caster_id;
    
    -- Obtener ID y duración del poder usado
    SELECT id, duration INTO v_power_id, v_power_duration FROM public.powers WHERE slug = p_power_slug;
    
    IF v_power_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'power_not_found');
    END IF;

    -- 2. CONSUMO DE MUNICIÓN
    UPDATE public.player_powers 
    SET quantity = quantity - 1, last_used_at = v_now
    WHERE game_player_id = p_caster_id AND power_id = v_power_id AND quantity > 0;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'no_ammo');
    END IF;

    -- 3. DEFENSE POWERS (Shield, Return, Invisibility) - UNIFIED MUTUAL EXCLUSIVITY
    --    FIX: Now includes 'invisibility' in the defense block
    IF p_power_slug IN ('shield', 'return', 'invisibility') THEN
        
        -- Check if ALREADY protected (Mutual Exclusion for ALL defense powers)
        IF v_caster_is_protected THEN
             -- Refund ammo
             UPDATE public.player_powers SET quantity = quantity + 1 
             WHERE game_player_id = p_caster_id AND power_id = v_power_id;
             RETURN json_build_object('success', false, 'error', 'defense_already_active');
        END IF;

        -- Activate Protection atomically
        UPDATE public.game_players SET is_protected = true, updated_at = now() 
        WHERE id = p_caster_id;

        -- Insert into active_powers for UI/Logging
        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, p_caster_id, p_caster_id, v_power_id, p_power_slug, 
                CASE 
                    WHEN p_power_slug = 'shield' THEN v_now + interval '1 year'
                    WHEN p_power_slug = 'return' THEN v_now + interval '1 year'
                    ELSE v_now + (COALESCE(v_power_duration, 20) || ' seconds')::interval
                END);
        
        -- FIX: Return defense_slug so frontend knows which defense was activated
        RETURN json_build_object(
            'success', true, 
            'action', p_power_slug || '_activated',
            'defense_slug', p_power_slug
        );
    END IF;

    -- 4. ATAQUE DE ÁREA (Blur Screen)
    IF p_power_slug = 'blur_screen' THEN
        DECLARE
            v_aoe_target_id uuid;
            v_aoe_is_protected boolean;
            v_aoe_defense_slug text;
            v_aoe_final_caster uuid;
            v_aoe_final_target uuid;
            v_aoe_returned boolean;
            v_aoe_returned_by_name text;
        BEGIN
            FOR v_aoe_target_id IN 
                SELECT id FROM public.game_players 
                WHERE event_id = v_event_id AND id != p_caster_id AND status != 'spectator'
            LOOP
                v_aoe_returned := false;
                v_aoe_final_caster := p_caster_id;
                v_aoe_final_target := v_aoe_target_id;

                -- Check Protection
                SELECT is_protected INTO v_aoe_is_protected FROM public.game_players WHERE id = v_aoe_target_id;
                
                IF v_aoe_is_protected THEN
                    -- Identify Defense Type (now includes invisibility)
                    SELECT power_slug INTO v_aoe_defense_slug FROM public.active_powers 
                    WHERE target_id = v_aoe_target_id AND power_slug IN ('shield', 'return', 'invisibility') 
                    ORDER BY created_at DESC LIMIT 1;
                    
                    -- Consume Protection
                    UPDATE public.game_players SET is_protected = false, updated_at = now() 
                    WHERE id = v_aoe_target_id;
                    -- Clean Visuals
                    DELETE FROM public.active_powers 
                    WHERE target_id = v_aoe_target_id 
                      AND power_slug IN ('shield', 'return', 'invisibility');
                    
                    -- Handle Return vs Shield/Invisibility
                    IF v_aoe_defense_slug = 'return' THEN
                         v_aoe_returned := true;
                         v_aoe_final_caster := v_aoe_target_id;
                         v_aoe_final_target := p_caster_id;
                         
                         INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                         VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'reflected');
                         
                         SELECT name INTO v_aoe_returned_by_name FROM public.profiles 
                         WHERE id = (SELECT user_id FROM public.game_players WHERE id = v_aoe_target_id);
                    ELSE
                        -- Log standard block (Shield or Invisibility)
                        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                        VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'shield_blocked');
                    END IF;
                END IF;

                -- Apply Effect (If not protected OR if Returned)
                IF NOT v_aoe_is_protected THEN
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                    
                    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'success');
                ELSIF v_aoe_returned THEN
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, v_aoe_final_caster, v_aoe_final_target, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                END IF;
                
            END LOOP;
            
            RETURN json_build_object('success', true, 'message', 'broadcast_complete');
        END;
    END IF;
    
    -- 5. Check if target is protected (Centralized Check)
    SELECT is_protected INTO v_target_is_protected FROM public.game_players WHERE id = p_target_id;

    -- Handle Invisibility (Special case: invisible targets can't be targeted directly)
    IF EXISTS (SELECT 1 FROM public.active_powers WHERE target_id = p_target_id AND power_slug = 'invisibility' AND expires_at > v_now) THEN
        UPDATE public.player_powers SET quantity = quantity + 1 WHERE game_player_id = p_caster_id AND power_id = v_power_id;
        RETURN json_build_object('success', false, 'error', 'target_invisible');
    END IF;

    -- BLOCK BY PROTECTION (Shield, Return, or Invisibility acting as defense)
    IF v_target_is_protected THEN
        
        -- Determine TYPE of protection from active_powers
        SELECT power_slug INTO v_defense_slug FROM public.active_powers 
        WHERE target_id = p_target_id AND power_slug IN ('shield', 'return', 'invisibility') 
        ORDER BY created_at DESC LIMIT 1;

        -- Consume Protection Atomically
        UPDATE public.game_players SET is_protected = false, updated_at = now() WHERE id = p_target_id;
        
        -- Clean Visuals
        DELETE FROM public.active_powers 
        WHERE target_id = p_target_id 
          AND power_slug IN ('shield', 'return', 'invisibility');

        -- A. RETURN LOGIC (reflects attack)
        IF v_defense_slug = 'return' THEN
            v_final_caster := p_target_id; 
            v_final_target := p_caster_id;
            v_returned := true;
            
            INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
            VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'reflected');

            SELECT name INTO v_returned_by_name FROM public.profiles 
            WHERE id = (SELECT user_id FROM public.game_players WHERE id = p_target_id);
        
        -- B. SHIELD / INVISIBILITY LOGIC (blocks attack, no reflection)
        ELSE 
            INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
            VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'shield_blocked');

            RETURN json_build_object('success', true, 'blocked', true, 'reason', 'shield_absorbed');
        END IF;
    END IF;

    -- 6. EXECUTE EFFECT (Direct or Reflected)
    
    IF v_returned THEN
        IF p_power_slug = 'life_steal' THEN
           UPDATE public.game_players SET lives = GREATEST(lives - 1, 0) WHERE id = v_final_target;
           UPDATE public.game_players SET lives = LEAST(lives + 1, 3) WHERE id = v_final_caster;
        END IF;

        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, v_final_caster, v_final_target, v_power_id, p_power_slug, 
                v_now + (GREATEST(COALESCE(v_power_duration, 10), 5) || ' seconds')::interval);

        RETURN json_build_object('success', true, 'returned', true, 'returned_by_name', v_returned_by_name);
    END IF;

    -- Normal Hit (Life Steal)
    IF p_power_slug = 'life_steal' THEN
       SELECT lives INTO v_target_lives FROM public.game_players WHERE id = p_target_id FOR UPDATE;
       
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

    -- Normal Hit (Others)
    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
    VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 
            v_now + (GREATEST(COALESCE(v_power_duration, 10), 5) || ' seconds')::interval);
            
    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
    VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'success');
    
    RETURN json_build_object('success', true);

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
