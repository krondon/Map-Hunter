-- Migration: Move coins to game_players (Session-Based Economy)
-- Date: 2026-02-09
-- Purpose: Make currency specific to each event session instead of global profile.

-- 1. Add coins column to game_players with DEFAULT 100 (Initial Event Balance)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'game_players' AND column_name = 'coins') THEN
        ALTER TABLE public.game_players ADD COLUMN coins BIGINT DEFAULT 100;
    ELSE
        -- If column exists, ensure default is 100 and update existing 0s if needed (optional context decision)
        ALTER TABLE public.game_players ALTER COLUMN coins SET DEFAULT 100;
    END IF;
END $$;

-- 2. Update buy_item RPC to use game_players.coins
CREATE OR REPLACE FUNCTION public.buy_item(
    p_user_id UUID,
    p_event_id UUID,
    p_item_id TEXT, -- Power slug (e.g. 'bg_black', 'freeze')
    p_cost INT,
    p_is_power BOOLEAN DEFAULT TRUE,
    p_game_player_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_game_player_id UUID;
    v_current_coins BIGINT;
    v_new_coins BIGINT;
    v_power_id UUID;
    v_current_qty INT;
BEGIN
    -- 1. Resolve Game Player ID
    IF p_game_player_id IS NOT NULL THEN
        v_game_player_id := p_game_player_id;
    ELSE
        SELECT id INTO v_game_player_id
        FROM public.game_players
        WHERE user_id = p_user_id AND event_id = p_event_id
        LIMIT 1;
    END IF;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'Player not found in this event';
    END IF;

    -- 2. Check Funds (game_players.coins)
    SELECT coins INTO v_current_coins
    FROM public.game_players
    WHERE id = v_game_player_id;

    -- Initialize to 100 if null (Respect Session Baseline)
    IF v_current_coins IS NULL THEN 
        v_current_coins := 100; 
        -- Auto-fix: Initialize column if it was null
        UPDATE public.game_players SET coins = 100 WHERE id = v_game_player_id;
    END IF;

    IF v_current_coins < p_cost THEN
        RAISE EXCEPTION 'Insufficient funds in event wallet. Required: %, Available: %', p_cost, v_current_coins;
    END IF;

    -- 3. Inventory Logic
    IF p_item_id = 'extra_life' THEN
         -- Extra LifeLogic
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
        -- Check if entry exists
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

    -- 4. Deduct Coins
    v_new_coins := v_current_coins - p_cost;
    
    UPDATE public.game_players
    SET coins = v_new_coins
    WHERE id = v_game_player_id;

    -- 5. Record Transaction
    INSERT INTO public.transactions (id, game_player_id, transaction_type, coins_change, description)
    VALUES (gen_random_uuid(), v_game_player_id, 'purchase', -p_cost, 'Purchase ' || p_item_id);

    RETURN jsonb_build_object('success', true, 'new_coins', v_new_coins);
END;
$$;

-- 3. Update buy_extra_life RPC to use game_players.coins
CREATE OR REPLACE FUNCTION public.buy_extra_life(
    p_user_id UUID,
    p_event_id UUID,
    p_cost INT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_game_player_id UUID;
    v_current_coins BIGINT;
    v_current_lives INT;
    v_new_lives INT;
BEGIN
    SELECT id, coins, lives INTO v_game_player_id, v_current_coins, v_current_lives
    FROM public.game_players
    WHERE user_id = p_user_id AND event_id = p_event_id
    LIMIT 1;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'Player not found in this event';
    END IF;

    IF v_current_coins IS NULL THEN v_current_coins := 0; END IF;

    IF v_current_coins < p_cost THEN
        RAISE EXCEPTION 'Insufficient funds (Event Wallet)';
    END IF;

    IF v_current_lives >= 3 THEN
        RAISE EXCEPTION 'Max lives reached';
    END IF;

    v_new_lives := v_current_lives + 1;

    UPDATE public.game_players
    SET coins = v_current_coins - p_cost,
        lives = v_new_lives
    WHERE id = v_game_player_id;
    
    -- Record Transaction
    INSERT INTO public.transactions (id, game_player_id, transaction_type, coins_change, description)
    VALUES (gen_random_uuid(), v_game_player_id, 'purchase', -p_cost, 'Purchase Extra Life');

    RETURN v_new_lives;
END;
$$;

