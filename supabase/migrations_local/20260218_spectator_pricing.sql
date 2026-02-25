-- 1. Add spectator_config to events table
ALTER TABLE "public"."events" 
ADD COLUMN IF NOT EXISTS "spectator_config" jsonb DEFAULT '{}'::jsonb;

COMMENT ON COLUMN "public"."events"."spectator_config" IS 'Configuration for spectator-specific pricing (e.g. {"shield": 10, "freeze": 50})';

-- 2. Update buy_item RPC to handle spectator pricing
CREATE OR REPLACE FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean DEFAULT true, "p_game_player_id" "uuid" DEFAULT NULL::"uuid") 
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
AS $$
DECLARE
    v_game_player_id UUID;
    v_current_coins BIGINT; -- For players (coins)
    v_current_clovers BIGINT; -- For spectators (clovers)
    v_new_balance BIGINT;
    v_power_id UUID;
    v_current_qty INT;
    v_player_status TEXT;
    v_spectator_config JSONB;
    v_final_cost INT;
    v_is_spectator BOOLEAN := FALSE;
BEGIN
    -- 1. Resolve Game Player ID & Status
    IF p_game_player_id IS NOT NULL THEN
        SELECT id, status INTO v_game_player_id, v_player_status
        FROM public.game_players
        WHERE id = p_game_player_id;
    ELSE
        SELECT id, status INTO v_game_player_id, v_player_status
        FROM public.game_players
        WHERE user_id = p_user_id AND event_id = p_event_id
        LIMIT 1;
    END IF;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'Player not found in this event';
    END IF;

    -- Determine if Spectator
    IF v_player_status = 'spectator' THEN
        v_is_spectator := TRUE;
    END IF;

    -- 2. DETERMINE COST (Wait! Logic Shift)
    -- If Spectator, check event config for overrides.
    v_final_cost := p_cost;
    
    IF v_is_spectator THEN
       SELECT spectator_config INTO v_spectator_config
       FROM public.events
       WHERE id = p_event_id;
       
       -- Check if there is a custom price for this item
       IF v_spectator_config IS NOT NULL AND (v_spectator_config->>p_item_id) IS NOT NULL THEN
           v_final_cost := (v_spectator_config->>p_item_id)::INT;
       END IF;
    END IF;

    -- 3. Check Funds
    IF v_is_spectator THEN
        -- SPECTATORS: Pay with CLOVERS from PROFILES
        SELECT clovers INTO v_current_clovers
        FROM public.profiles
        WHERE id = p_user_id;

        IF v_current_clovers IS NULL THEN v_current_clovers := 0; END IF;

        IF v_current_clovers < v_final_cost THEN
            RAISE EXCEPTION 'Insufficient clovers. Required: %, Available: %', v_final_cost, v_current_clovers;
        END IF;
    ELSE
        -- PLAYERS: Pay with COINS from GAME_PLAYERS
        SELECT coins INTO v_current_coins
        FROM public.game_players
        WHERE id = v_game_player_id;

        IF v_current_coins IS NULL THEN 
            v_current_coins := 100; 
            UPDATE public.game_players SET coins = 100 WHERE id = v_game_player_id;
        END IF;

        IF v_current_coins < v_final_cost THEN
            RAISE EXCEPTION 'Insufficient coins. Required: %, Available: %', v_final_cost, v_current_coins;
        END IF;
    END IF;

    -- 4. Inventory Logic
    IF p_item_id = 'extra_life' THEN
         -- Extra Life for PLAYERS Only? Or Spectators too? 
         -- Spectators have lives=0 usually. Let's assume standard logic applies if they buy it.
         -- But typically spectators don't need lives.
         -- If spectator buys extra life, we increment it anyway? 
         -- For now, allow it, logic holds.
         UPDATE public.game_players
         SET lives = LEAST(lives + 1, 3)
         WHERE id = v_game_player_id;
         
    ELSIF p_is_power THEN
        -- Find Power ID by slug
        SELECT id INTO v_power_id FROM public.powers WHERE slug = p_item_id LIMIT 1;
        
        IF v_power_id IS NULL THEN
            RAISE EXCEPTION 'Power not found: %', p_item_id;
        END IF;

        -- Upsert logic for player_powers
        SELECT quantity INTO v_current_qty 
        FROM public.player_powers 
        WHERE game_player_id = v_game_player_id AND power_id = v_power_id 
        LIMIT 1;
        
        IF v_current_qty IS NOT NULL THEN
             UPDATE public.player_powers 
             SET quantity = quantity + 1 
             WHERE game_player_id = v_game_player_id AND power_id = v_power_id;
        ELSE
             INSERT INTO public.player_powers (game_player_id, power_id, quantity)
             VALUES (v_game_player_id, v_power_id, 1);
        END IF;
    END IF;

    -- 5. Deduct Method (Split by Role)
    IF v_is_spectator THEN
       v_new_balance := v_current_clovers - v_final_cost;
       UPDATE public.profiles
       SET clovers = v_new_balance
       WHERE id = p_user_id;
    ELSE
       v_new_balance := v_current_coins - v_final_cost;
       UPDATE public.game_players
       SET coins = v_new_balance
       WHERE id = v_game_player_id;
    END IF;

    -- 6. Record Transaction
    INSERT INTO public.transactions (id, game_player_id, transaction_type, coins_change, description)
    VALUES (gen_random_uuid(), v_game_player_id, 'purchase', -v_final_cost, 'Purchase ' || p_item_id || (CASE WHEN v_is_spectator THEN ' (Spec)' ELSE '' END));

    RETURN jsonb_build_object('success', true, 'new_balance', v_new_balance, 'cost_deducted', v_final_cost);
END;
$$;

ALTER FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean, "p_game_player_id" "uuid") OWNER TO "postgres";
