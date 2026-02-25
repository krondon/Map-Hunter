-- Migration: Shield Consistency Fix
-- Date: 2026-02-14
-- Purpose: Centralize shield protection in game_players table and ensure mutual exclusivity

-- 1. Add is_protected column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'game_players' AND column_name = 'is_protected') THEN
        ALTER TABLE public.game_players ADD COLUMN is_protected boolean DEFAULT false;
    END IF;
END $$;

-- 2. Update lose_life to respect is_protected
CREATE OR REPLACE FUNCTION public.lose_life(
    p_user_id uuid,
    p_event_id uuid
) returns integer
language plpgsql
SECURITY DEFINER
SET search_path = public
as $$
DECLARE
    current_lives integer;
    new_lives integer;
    v_is_protected boolean;
BEGIN
    -- Select with locking
    SELECT lives, is_protected INTO current_lives, v_is_protected
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player not found (Event: %, User: %)', p_event_id, p_user_id;
    END IF;

    -- CHECK PROTECTION
    IF v_is_protected THEN
        -- Consume protection atomically
        UPDATE public.game_players
        SET is_protected = false,
            updated_at = now()
        WHERE event_id = p_event_id AND user_id = p_user_id;
        
        -- Also try to clean up the visual effect if possible (best effort)
        -- We won't error if this fails, as the state of truth is is_protected
        DELETE FROM public.active_powers 
        WHERE target_id = (SELECT id FROM public.game_players WHERE event_id = p_event_id AND user_id = p_user_id) 
        AND power_slug IN ('shield', 'return');

        -- Return current lives (no damage taken)
        RETURN current_lives; 
    END IF;

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

-- 3. Update use_power_mechanic to manage is_protected
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
    v_target_is_protected boolean;
    v_caster_is_protected boolean;
    v_returned boolean := false;
    v_returned_by_name text;
    v_final_caster uuid := p_caster_id;
    v_final_target uuid := p_target_id;
    v_target_lives int;
    v_rival_record record;
    v_defense_slug text;
BEGIN
    -- 0. SECURITY: Validate caller owns the caster
    IF NOT EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.id = p_caster_id AND gp.user_id = auth.uid()
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- 1. OBTENCIÓN DE DATOS BÁSICOS
    SELECT event_id, is_protected INTO v_event_id, v_caster_is_protected FROM public.game_players WHERE id = p_caster_id;
    
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

    -- 3. DEFENSE POWERS (Shield, Return) - MUTUAL EXCLUSIVITY CHECK
    IF p_power_slug IN ('shield', 'return') THEN
        
        -- Check if ALREADY protected (Mutual Exclusion for ALL defense powers)
        IF v_caster_is_protected THEN
             -- Refund ammo
             UPDATE public.player_powers SET quantity = quantity + 1 WHERE game_player_id = p_caster_id AND power_id = v_power_id;
             RETURN json_build_object('success', false, 'error', 'defense_already_active');
        END IF;

        -- Activate Protection
        UPDATE public.game_players SET is_protected = true WHERE id = p_caster_id;

        -- Still insert into active_powers for UI/Logging
        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, p_caster_id, p_caster_id, v_power_id, p_power_slug, 
                v_now + interval '1 year'); 
        
        RETURN json_build_object('success', true, 'action', p_power_slug || '_activated');
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
                    -- Identify Defense Type
                    SELECT power_slug INTO v_aoe_defense_slug FROM public.active_powers 
                    WHERE target_id = v_aoe_target_id AND power_slug IN ('shield', 'return') 
                    ORDER BY created_at DESC LIMIT 1;
                    
                    -- Consume Protection
                    UPDATE public.game_players SET is_protected = false WHERE id = v_aoe_target_id;
                     -- Clean Visuals
                    DELETE FROM public.active_powers WHERE target_id = v_aoe_target_id AND power_slug IN ('shield', 'return');
                    
                    -- Log Block
                    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'shield_blocked');
                    
                    -- Handle Return
                    IF v_aoe_defense_slug = 'return' THEN
                         v_aoe_returned := true;
                         v_aoe_final_caster := v_aoe_target_id; -- Victim acts as caster
                         v_aoe_final_target := p_caster_id;     -- Original Caster is new target
                         
                         INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                         VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'reflected');
                         
                         SELECT name INTO v_aoe_returned_by_name FROM public.profiles 
                         WHERE id = (SELECT user_id FROM public.game_players WHERE id = v_aoe_target_id);
                    END IF;
                END IF;

                -- Apply Effect (If not protected OR if Returned)
                IF NOT v_aoe_is_protected THEN
                    -- Normal Hit on Rival
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                    
                    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'success');
                ELSIF v_aoe_returned THEN
                    -- Hit on Original Caster (Reflected)
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, v_aoe_final_caster, v_aoe_final_target, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                END IF;
                
            END LOOP;
            
            RETURN json_build_object('success', true, 'message', 'broadcast_complete');
        END;
    END IF;
    
    -- Check if target is protected (Centralized Check)
    SELECT is_protected INTO v_target_is_protected FROM public.game_players WHERE id = p_target_id;

    -- Handle Invisibility (Special case from active_powers)
    IF EXISTS (SELECT 1 FROM public.active_powers WHERE target_id = p_target_id AND power_slug = 'invisibility' AND expires_at > v_now) THEN
        UPDATE public.player_powers SET quantity = quantity + 1 WHERE game_player_id = p_caster_id AND power_id = v_power_id;
        RETURN json_build_object('success', false, 'error', 'target_invisible');
    END IF;

    -- BLOCK BY SHIELD/PROTECTION
    IF v_target_is_protected THEN
        
        -- Determine TYPE of protection from active_powers (fallback to shield if missing or ambiguity)
        SELECT power_slug INTO v_defense_slug FROM public.active_powers 
        WHERE target_id = p_target_id AND power_slug IN ('shield', 'return') 
        ORDER BY created_at DESC LIMIT 1;

        -- Consume Protection Atomically
        UPDATE public.game_players SET is_protected = false WHERE id = p_target_id;
        
        -- Clean Visuals
        DELETE FROM public.active_powers WHERE target_id = p_target_id AND power_slug IN ('shield', 'return');

        -- A. RETURN LOGIC
        IF v_defense_slug = 'return' THEN
            -- Swap roles
            v_final_caster := p_target_id; 
            v_final_target := p_caster_id;
            v_returned := true;
            
            -- Log Reflection
            INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
            VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'reflected');

            -- Get name for UI
            SELECT name INTO v_returned_by_name FROM public.profiles 
            WHERE id = (SELECT user_id FROM public.game_players WHERE id = p_target_id);

            -- Apply effect to original attacker (Reflected)
             -- Logic continues below...
        
        -- B. SHIELD LOGIC (Default)
        ELSE 
            -- Log Block
            INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
            VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'shield_blocked');

            RETURN json_build_object('success', true, 'blocked', true, 'reason', 'shield_absorbed');
        END IF;
    END IF;

    -- EXECUTE EFFECT (Direct or Reflected)
    
    -- If Returned, apply to new target (Attacker)
    IF v_returned THEN
        -- Life Steal logic handling for reflection
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
       
       -- Short visual for life steal
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
