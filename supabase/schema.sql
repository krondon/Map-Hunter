


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."add_clovers"("target_user_id" "uuid", "amount" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  update profiles
  set clovers = coalesce(clovers, 0) + amount
  where id = target_user_id;
end;
$$;


ALTER FUNCTION "public"."add_clovers"("target_user_id" "uuid", "amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."attempt_start_minigame"("p_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_is_playing boolean;
    v_ban_ends_at timestamptz;
    v_penalty_level int;
    v_new_ban_time timestamptz;
    v_penalty_minutes int;
BEGIN
    -- Obtener estado actual
    SELECT is_playing, ban_ends_at, penalty_level
    INTO v_is_playing, v_ban_ends_at, v_penalty_level
    FROM profiles
    WHERE id = p_user_id;

    -- CASO 1: ¿Está baneado actualmente?
    IF v_ban_ends_at IS NOT NULL AND v_ban_ends_at > now() THEN
        RETURN json_build_object('status', 'banned', 'ban_ends_at', v_ban_ends_at);
    END IF;

    -- CASO 2: ¿Se salió "ilegalmente" la última vez? (La bandera sigue arriba)
    IF v_is_playing THEN
        -- Calcular castigo exponencial: 1 min * 2^nivel
        v_penalty_minutes := 1 * (2 ^ v_penalty_level); 
        v_new_ban_time := now() + (v_penalty_minutes || ' minutes')::interval;
        
        -- Aplicar castigo y subir nivel
        UPDATE profiles 
        SET is_playing = false, -- Reseteamos para que cumpla el castigo
            penalty_level = v_penalty_level + 1,
            ban_ends_at = v_new_ban_time
        WHERE id = p_user_id;

        RETURN json_build_object('status', 'penalized_now', 'ban_ends_at', v_new_ban_time);
    END IF;

    -- CASO 3: Todo limpio, dejar pasar y subir la bandera
    UPDATE profiles 
    SET is_playing = true,
        ban_ends_at = null -- Limpiar cualquier ban viejo
    WHERE id = p_user_id;

    RETURN json_build_object('status', 'allowed');
END;
$$;


ALTER FUNCTION "public"."attempt_start_minigame"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."broadcast_power"("p_caster_id" "uuid", "p_power_slug" "text", "p_rival_targets" "jsonb", "p_event_id" "uuid", "p_duration_seconds" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_expires_at TIMESTAMP WITH TIME ZONE;
  v_target_record JSONB;
  v_target_id UUID;
BEGIN
  -- 1. Calculate Expiration
  v_expires_at := now() + (p_duration_seconds || ' seconds')::interval;
  -- 2. Loop through targets and insert
  -- Assuming p_rival_targets is a JSON array: [{"target_id": "uuid1"}, {"target_id": "uuid2"}]
  FOR v_target_record IN SELECT * FROM jsonb_array_elements(p_rival_targets)
  LOOP
    v_target_id := (v_target_record->>'target_id')::UUID;
    
    -- Prevent self-targeting just in case
    IF v_target_id <> p_caster_id THEN
      INSERT INTO public.active_powers (
        caster_id,
        target_id,
        power_slug,
        event_id,
        expires_at,
        created_at
      ) VALUES (
        p_caster_id,
        v_target_id,
        p_power_slug,
        p_event_id,
        v_expires_at,
        now()
      );
    END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."broadcast_power"("p_caster_id" "uuid", "p_power_slug" "text", "p_rival_targets" "jsonb", "p_event_id" "uuid", "p_duration_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buy_extra_life"("p_user_id" "uuid", "p_event_id" "uuid", "p_cost" integer) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."buy_extra_life"("p_user_id" "uuid", "p_event_id" "uuid", "p_cost" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_game_player_id uuid;
    v_power_id uuid;
    v_current_qty integer;
BEGIN
    -- 1. Obtener el ID del jugador en el evento
    SELECT id INTO v_game_player_id 
    FROM public.game_players 
    WHERE user_id = p_user_id AND event_id = p_event_id;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'No estás inscrito en este evento.';
    END IF;

    -- 2. Lógica de poderes
    IF p_is_power THEN
        SELECT id INTO v_power_id FROM public.powers 
        WHERE (id::text = p_item_id OR slug = p_item_id) LIMIT 1;

        IF v_power_id IS NULL THEN
            RAISE EXCEPTION 'Poder no encontrado.';
        END IF;

        SELECT quantity INTO v_current_qty FROM public.player_powers 
        WHERE game_player_id = v_game_player_id AND power_id = v_power_id;

        IF COALESCE(v_current_qty, 0) >= 3 THEN
            RAISE EXCEPTION 'Máximo alcanzado (3 unidades).';
        END IF;

        -- Al ser SECURITY DEFINER, el RLS de la tabla ya no bloqueará este INSERT
        INSERT INTO public.player_powers (game_player_id, power_id, quantity)
        VALUES (v_game_player_id, v_power_id, 1)
        ON CONFLICT (game_player_id, power_id) 
        DO UPDATE SET quantity = player_powers.quantity + 1;
    END IF;

    -- 3. Reducción de saldo atómica
    UPDATE public.profiles 
    SET total_coins = total_coins - p_cost 
    WHERE id = p_user_id;

END;
$$;


ALTER FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean DEFAULT true, "p_game_player_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean, "p_game_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_and_set_winner"("p_event_id" "uuid", "p_user_id" "uuid", "p_total_clues" integer, "p_completed_clues" integer) RETURNS TABLE("is_winner" boolean, "placement" integer, "winner_name" "text")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_current_winner_id UUID;
  v_is_winner BOOLEAN := FALSE;
  v_placement INTEGER;
  v_winner_name TEXT;
BEGIN
  -- Lock the event row to prevent race conditions
  SELECT winner_id INTO v_current_winner_id
  FROM events
  WHERE id = p_event_id
  FOR UPDATE;

  -- Check if all clues are completed
  IF p_completed_clues >= p_total_clues THEN
    -- Check if there's no winner yet
    IF v_current_winner_id IS NULL THEN
      -- This user is the winner!
      UPDATE events
      SET 
        winner_id = p_user_id,
        completed_at = NOW(),
        is_completed = TRUE
      WHERE id = p_event_id;
      
      v_is_winner := TRUE;
      v_placement := 1;
      
      -- Update participant record in game_players
      UPDATE game_players
      SET 
        final_placement = 1,
        completed_clues_count = p_completed_clues,
        finish_time = NOW()
      WHERE event_id = p_event_id AND user_id = p_user_id;
      
    ELSE
      -- Someone already won, calculate placement
      v_is_winner := FALSE;
      
      -- Calculate placement based on completion order
      SELECT COALESCE(MAX(final_placement), 0) + 1 INTO v_placement
      FROM game_players
      WHERE event_id = p_event_id AND final_placement IS NOT NULL;
      
      -- Update participant record with placement
      UPDATE game_players
      SET 
        final_placement = v_placement,
        completed_clues_count = p_completed_clues,
        finish_time = NOW()
      WHERE event_id = p_event_id AND user_id = p_user_id;
    END IF;
  ELSE
    -- Not all clues completed yet, no placement
    v_is_winner := FALSE;
    v_placement := NULL;
  END IF;
  
  -- Get winner's name
  SELECT name INTO v_winner_name
  FROM profiles
  WHERE id = COALESCE(v_current_winner_id, (SELECT winner_id FROM events WHERE id = p_event_id));
  
  RETURN QUERY SELECT v_is_winner, v_placement, v_winner_name;
END;
$$;


ALTER FUNCTION "public"."check_and_set_winner"("p_event_id" "uuid", "p_user_id" "uuid", "p_total_clues" integer, "p_completed_clues" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."check_and_set_winner"("p_event_id" "uuid", "p_user_id" "uuid", "p_total_clues" integer, "p_completed_clues" integer) IS 'Atomically checks and sets the event winner, returns winner status and placement';



CREATE OR REPLACE FUNCTION "public"."cleanup_expired_powers"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.game_players
  SET is_frozen = false, frozen_until = null
  WHERE is_frozen = true AND frozen_until < now();

  DELETE FROM public.active_powers
  WHERE expires_at < now();
END;
$$;


ALTER FUNCTION "public"."cleanup_expired_powers"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."distribute_event_prizes"("p_event_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_event_record RECORD;
  v_participant_count INT;
  v_distributable_pot NUMERIC;
  v_total_collected NUMERIC;
  v_winners RECORD;
  v_prize_amount NUMERIC;
  v_share NUMERIC;
  v_rank INT;
  v_distribution_results JSONB[] := ARRAY[]::JSONB[];
  v_shares NUMERIC[];
BEGIN
  -- 1. Lock Event & Get Details
  SELECT * INTO v_event_record FROM events WHERE id = p_event_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  IF v_event_record.status = 'completed' AND v_event_record.completed_at IS NOT NULL THEN
     -- Check if prizes already distributed (Idempotency)
     IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
        RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true);
     END IF;
  END IF;

  -- 2. Define Distribution Shares based on configured_winners
  -- percentages of the 70% pot.
  IF v_event_record.configured_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_event_record.configured_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE -- Default 3 or more (though likely capped at 3 by UI)
    v_shares := ARRAY[0.50, 0.30, 0.20]; 
  END IF;

  -- 3. Count ALL Participants (Paying users)
  -- Valid statuses for payment count: active, completed, banned, suspended, eliminated.
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes válidos');
  END IF;

  -- 4. Calculate Pot
  -- Ensure entry_fee is numeric/int
  v_total_collected := v_participant_count * (COALESCE(v_event_record.entry_fee, 0));
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      -- Mark completed anyway? Or just return.
      UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id;
      RETURN json_build_object('success', true, 'message', 'Evento finalizado sin premios (Bote 0)', 'pot', 0);
  END IF;

  -- 5. Select Winners (Top N)
  v_rank := 0;
  
  FOR v_winners IN 
    SELECT * 
    FROM game_players 
    WHERE event_id = p_event_id 
    AND status IN ('active', 'completed') -- Only active/completed can win? purely logic choice.
    -- Ranking Logic: Completed Clues DESC, Finish Time ASC (Nulls Last for active)
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_event_record.configured_winners
  LOOP
    v_rank := v_rank + 1;
    
    -- Get share for this rank
    IF v_rank <= array_length(v_shares, 1) THEN
        v_share := v_shares[v_rank];
        v_prize_amount := floor(v_distributable_pot * v_share); -- Floor to avoid decimals issues

        IF v_prize_amount > 0 THEN
            -- A. Update User Wallet
            UPDATE profiles 
            SET clovers = COALESCE(clovers, 0) + v_prize_amount
            WHERE id = v_winners.user_id;

            -- B. Record Distribution Log
            INSERT INTO prize_distributions 
            (event_id, user_id, position, amount, pot_total, participants_count, entry_fee, rpc_success)
            VALUES 
            (p_event_id, v_winners.user_id, v_rank, v_prize_amount, v_distributable_pot, v_participant_count, v_event_record.entry_fee, true);
            
            -- C. Add to results
            v_distribution_results := array_append(v_distribution_results, jsonb_build_object(
                'user_id', v_winners.user_id,
                'rank', v_rank,
                'amount', v_prize_amount
            ));
        END IF;
    END IF;
  END LOOP;

  -- 6. Finalize Event
  UPDATE events 
  SET status = 'completed', 
      completed_at = NOW(),
      winner_id = (SELECT user_id FROM game_players WHERE event_id = p_event_id ORDER BY completed_clues_count DESC, finish_time ASC LIMIT 1)
  WHERE id = p_event_id;

  RETURN json_build_object(
    'success', true, 
    'pot_total', v_total_collected,
    'distributable_pot', v_distributable_pot,
    'winners_count', v_rank,
    'results', v_distribution_results
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."distribute_event_prizes"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."execute_combat_power"("p_event_id" "uuid", "p_caster_id" "uuid", "p_target_id" "uuid", "p_power_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."execute_combat_power"("p_event_id" "uuid", "p_caster_id" "uuid", "p_target_id" "uuid", "p_power_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_minigame_legally"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE profiles
    SET is_playing = false
    WHERE id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."finish_minigame_legally"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_race_and_distribute"("target_event_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  current_user_id uuid;
  event_record record;
  player_record record;
  participants_count integer;
  entry_fee integer;
  total_pot decimal;
  tier_name text;
  
  -- Shares
  p1_share decimal := 0;
  p2_share decimal := 0;
  p3_share decimal := 0;
  
  -- Leaderboard
  leaderboard_cursor refcursor;
  p_rank integer := 0;
  p_row record;
  prize_amount integer;
  
  results_json jsonb := '[]'::jsonb;
begin
  -- 1. Get Current User
  current_user_id := auth.uid();
  
  -- 2. Validate Event & Caller Status
  select * into event_record from events where id = target_event_id;
  
  if event_record.status = 'completed' then
    return json_build_object('success', true, 'message', 'Event already completed');
  end if;
  
  select * into player_record from game_players 
  where event_id = target_event_id and user_id = current_user_id;
  
  if player_record is null then
     return json_build_object('success', false, 'message', 'Player not found in event');
  end if;
  
  -- OPTIONAL: Strict check - only allow if caller has finished?
  -- For now, we assume the client calls this only when finished. 
  -- But for security, we should check if they solved all clues?
  -- Replicating "finish" logic might be complex if "total clues" isn't stored strictly.
  -- We'll rely on the fact that ONLY a finished player hits the endpoint in the app flow.
  -- And even if they call it early, they might just close the event for everyone else? 
  -- RISK: A hacker could call this to end the race early.
  -- MITIGATION: We trust the app flow for now, or add a check for 'completed_clues_count'.
  
  -- 3. Calculate Pot
  entry_fee := coalesce(event_record.entry_fee, 0);
  
  -- Count valid participants (same filter as AdminService)
  select count(*) into participants_count
  from game_players
  where event_id = target_event_id
  and status in ('active', 'completed', 'banned', 'suspended', 'eliminated');
  
  total_pot := (participants_count * entry_fee) * 0.70;
  
  if total_pot <= 0 then
     -- Close event even if no pot
     update events set status = 'completed', completed_at = now() where id = target_event_id;
     return json_build_object('success', true, 'message', 'Event completed (No Pot)');
  end if;
  
  -- 4. Determine Tiers
  if participants_count < 5 then
    tier_name := 'Tier 1 (<5)';
    p1_share := 1.00;
  elsif participants_count < 10 then
    tier_name := 'Tier 2 (5-9)';
    p1_share := 0.70;
    p2_share := 0.30;
  else
    tier_name := 'Tier 3 (10+)';
    p1_share := 0.50;
    p2_share := 0.30;
    p3_share := 0.20;
  end if;
  
  -- 5. Fetch Leaderboard (TOP 3)
  -- Order by completed_clues DESC, last_completion_time ASC
  -- Note: If multiple people finished, this respects the order.
  -- If only the caller finished, they are #1. Others are #2, #3 based on clues.
  open leaderboard_cursor for 
    select user_id, completed_clues_count
    from game_players
    where event_id = target_event_id
    and status != 'spectator'
    order by completed_clues_count desc, last_completion_time asc
    limit 3;
    
  loop
    fetch leaderboard_cursor into p_row;
    exit when not found;
    
    p_rank := p_rank + 1;
    prize_amount := 0;
    
    if p_rank = 1 and p1_share > 0 then
       prize_amount := round(total_pot * p1_share);
    elsif p_rank = 2 and p2_share > 0 then
       prize_amount := round(total_pot * p2_share);
    elsif p_rank = 3 and p3_share > 0 then
       prize_amount := round(total_pot * p3_share);
    end if;
    
    if prize_amount > 0 then
       -- Update Wallet
       update profiles set clovers = coalesce(clovers, 0) + prize_amount where id = p_row.user_id;
       
       -- Record Prize in Game History (Logic we added to AdminService)
       update game_players set clovers = prize_amount 
       where event_id = target_event_id and user_id = p_row.user_id;
       
       results_json := results_json || jsonb_build_object('rank', p_rank, 'user', p_row.user_id, 'amount', prize_amount);
    end if;
  end loop;
  
  close leaderboard_cursor;
  
  -- 6. Close Event
  update events set status = 'completed', completed_at = now(), winner_id = current_user_id
  where id = target_event_id;
  
  return json_build_object(
    'success', true, 
    'message', 'Event completed and prizes distributed',
    'pot', total_pot,
    'results', results_json
  );
end;
$$;


ALTER FUNCTION "public"."finish_race_and_distribute"("target_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_clues_for_event"("target_event_id" "uuid", "quantity" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.clues (event_id, sequence_index, title, description)
  select 
    target_event_id, 
    s.i, 
    'Pista ' || s.i, 
    'Descripción pendiente para la pista ' || s.i
  from generate_series(1, quantity) as s(i);
end;
$$;


ALTER FUNCTION "public"."generate_clues_for_event"("target_event_id" "uuid", "quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_entry_code"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$;


ALTER FUNCTION "public"."generate_entry_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_leaderboard"("target_event_id" "uuid") RETURNS TABLE("id" "uuid", "name" "text", "avatar_url" "text", "level" integer, "profession" "text", "total_xp" integer, "completed_clues_count" integer, "last_completion_time" timestamp with time zone, "user_id" "uuid", "game_player_id" "uuid", "coins" bigint, "lives" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.name, 'Jugador')::TEXT,
    COALESCE(p.avatar_url, '')::TEXT,
    p.level,
    p.profession::TEXT,
    p.total_xp,
    gp.completed_clues_count,
    gp.last_active, 
    p.id as user_id,
    gp.id as game_player_id,
    gp.coins,
    gp.lives
  FROM game_players gp
  JOIN profiles p ON gp.user_id = p.id
  WHERE gp.event_id = target_event_id
  ORDER BY gp.completed_clues_count DESC, gp.last_active ASC NULLS LAST;
END;
$$;


ALTER FUNCTION "public"."get_event_leaderboard"("target_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_participants_count"("target_event_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  total_count integer;
begin
  select count(*) into total_count
  from game_players
  where event_id = target_event_id
  and status in ('active', 'completed', 'banned', 'suspended', 'eliminated');
  
  return total_count;
end;
$$;


ALTER FUNCTION "public"."get_event_participants_count"("target_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_exchange_rate"() RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  rate numeric;
BEGIN
  SELECT (value::text)::numeric INTO rate
  FROM public.app_config
  WHERE key = 'bcv_exchange_rate';
  
  -- Default to 1 if not found (safety fallback)
  RETURN COALESCE(rate, 1.0);
END;
$$;


ALTER FUNCTION "public"."get_exchange_rate"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_game_leaderboard"("target_game_id" "uuid") RETURNS TABLE("id" "uuid", "name" "text", "avatar_url" "text", "level" integer, "profession" "text", "total_coins" bigint, "clues_completed" integer, "status" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.name, 'Jugador') as name,
    COALESCE(p.avatar_url, '') as avatar_url,
    p.level,
    p.profession,
    p.coins as total_coins,
    gp.completed_clues_count as clues_completed,
    p.status -- Obtenemos el status ('active', 'invisible', etc.)
  FROM game_players gp
  JOIN profiles p ON gp.user_id = p.id
  WHERE gp.event_id = target_game_id -- Asegúrate de que el nombre de la columna sea correcto (event_id o game_id)
  ORDER BY gp.completed_clues_count DESC, p.coins DESC;
END;
$$;


ALTER FUNCTION "public"."get_game_leaderboard"("target_game_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_game_player_id"("p_user_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id 
  FROM public.game_players 
  WHERE user_id = p_user_id 
  LIMIT 1;
  
  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."get_game_player_id"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_gateway_fee_percentage"() RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  fee numeric;
BEGIN
  SELECT (value::text)::numeric INTO fee
  FROM public.app_config
  WHERE key = 'gateway_fee_percentage';
  
  -- Default to 0 if not found (no fee displayed)
  RETURN COALESCE(fee, 0.0);
END;
$$;


ALTER FUNCTION "public"."get_gateway_fee_percentage"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_event_id"() RETURNS "uuid"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT event_id
  FROM public.game_players
  WHERE user_id = auth.uid()
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_my_event_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_event_id_secure"() RETURNS "uuid"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT event_id
  FROM public.game_players
  WHERE user_id = auth.uid()
  LIMIT 1;
$$;


ALTER FUNCTION "public"."get_my_event_id_secure"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_event_ids"() RETURNS SETOF "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT event_id FROM game_players WHERE user_id = auth.uid()
$$;


ALTER FUNCTION "public"."get_my_event_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_inventory"("p_user_id" "uuid") RETURNS TABLE("power_id" "uuid", "quantity" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  return query
  select pp.power_id, pp.quantity
  from public.player_powers pp
  join public.game_players gp on gp.id = pp.game_player_id
  where gp.user_id = p_user_id
  and pp.quantity > 0;
end;
$$;


ALTER FUNCTION "public"."get_my_inventory"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_inventory_by_event"("p_user_id" "uuid", "p_event_id" "uuid") RETURNS TABLE("power_id" "uuid", "slug" "text", "name" "text", "quantity" integer, "description" "text", "icon" "text", "type" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_game_player_id uuid;
BEGIN
  -- 1. Get Game Player ID
  SELECT id INTO v_game_player_id
  FROM public.game_players
  WHERE user_id = p_user_id AND event_id = p_event_id;

  IF v_game_player_id IS NULL THEN
    RETURN;
  END IF;

  -- 2. Return inventory with JOIN to powers table
  RETURN QUERY
  SELECT 
    pp.power_id,
    p.slug,
    p.name,
    pp.quantity,
    p.description,
    p.icon,
    p.power_type
  FROM public.player_powers pp
  JOIN public.powers p ON pp.power_id = p.id
  WHERE pp.game_player_id = v_game_player_id
  AND pp.quantity > 0;
END;
$$;


ALTER FUNCTION "public"."get_my_inventory_by_event"("p_user_id" "uuid", "p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_event_deletion"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  function_url text := 'https://hyjelngckvqoanckqwep.supabase.co/functions/v1/delete-event-image';
  service_role_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh5amVsbmdja3Zxb2FuY2txd2VwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTIxMjUyMSwiZXhwIjoyMDgwNzg4NTIxfQ.RXoN5zT-kUW1kXjgJ4CLpS3V7_-9nh4ZrMVXzS5V5rk'; 
begin
  perform net.http_post(
      url := function_url,
      body := jsonb_build_object(
          'type', 'DELETE',
          'old_record', old
      ),
      headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || service_role_key
      )
  );
  return old;
end;
$$;


ALTER FUNCTION "public"."handle_event_deletion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email, status)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'name',
    new.email,
    'pending' -- Forzar estado pendiente al crear
  );
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_status_on_power_expiry"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Si el poder que se borra o expira es invisibilidad
  IF OLD.power_slug = 'invisibility' THEN
    UPDATE public.profiles 
    SET status = 'active'
    WHERE id = (SELECT user_id FROM public.game_players WHERE id = OLD.target_id);
  END IF;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."handle_status_on_power_expiry"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_user_verification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Verificamos si el email acaba de ser confirmado
  -- (Antes era NULL y ahora tiene un valor)
  IF (OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL) THEN
    UPDATE public.profiles
    SET status = 'active'
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_user_verification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."initialize_game_for_user"("target_user_id" "uuid", "target_event_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  first_clue_id bigint;
BEGIN
  -- 1. Insertar o resetear jugador
  INSERT INTO public.game_players (user_id, event_id, lives, joined_at)
  VALUES (target_user_id, target_event_id, 3, now())
  ON CONFLICT (user_id, event_id) DO UPDATE SET lives = 3;

  -- 2. ACTIVAR EL PERFIL (Crucial para el flujo de la App)
  UPDATE public.profiles 
  SET status = 'active', is_playing = true 
  WHERE id = target_user_id;

  -- 3. Inicializar pistas (Lógica existente...)
  SELECT id INTO first_clue_id FROM public.clues WHERE event_id = target_event_id ORDER BY sequence_index ASC LIMIT 1;
  
  IF first_clue_id IS NOT NULL THEN
    INSERT INTO public.user_clue_progress (user_id, clue_id, is_locked, is_completed)
    SELECT target_user_id, id, true, false FROM public.clues WHERE event_id = target_event_id
    ON CONFLICT (user_id, clue_id) DO NOTHING;
    
    UPDATE public.user_clue_progress SET is_locked = false
    WHERE user_id = target_user_id AND clue_id = first_clue_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."initialize_game_for_user"("target_user_id" "uuid", "target_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_event_completed"("p_event_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_is_completed BOOLEAN;
BEGIN
  SELECT is_completed INTO v_is_completed
  FROM events
  WHERE id = p_event_id;
  
  RETURN COALESCE(v_is_completed, FALSE);
END;
$$;


ALTER FUNCTION "public"."is_event_completed"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_game"("p_game_id" "uuid", "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO game_players (game_id, user_id, coins, current_challenge_index)
  VALUES (p_game_id, p_user_id, 100, 0)
  ON CONFLICT (game_id, user_id) DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."join_game"("p_game_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."lose_life"("p_user_id" "uuid", "p_event_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."lose_life"("p_user_id" "uuid", "p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_paid_clover_order"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    treboles_comprados numeric;
BEGIN
    -- 1. Verificamos el cambio de estado a 'success' (según tu requerimiento)
    IF (NEW.status = 'success' AND OLD.status IS DISTINCT FROM 'success') THEN
        
        -- 2. Extraemos la cantidad del extra_data (campo 'clovers_amount' de tu payload)
        treboles_comprados := (NEW.extra_data->>'clovers_amount')::numeric;

        -- 3. Validación de seguridad
        IF treboles_comprados IS NULL THEN
            RAISE EXCEPTION 'Error: clovers_amount no encontrado en extra_data';
        END IF;

        -- 4. Actualizamos el saldo en el perfil del usuario
        UPDATE public.profiles
        SET clovers = COALESCE(clovers, 0) + treboles_comprados
        WHERE id = NEW.user_id;

        -- 5. Registramos el movimiento en el Ledger para auditoría
        INSERT INTO public.wallet_ledger (user_id, order_id, amount, description)
        VALUES (
            NEW.user_id, 
            NEW.id, 
            treboles_comprados, 
            'Compra de tréboles - Ref: ' || NEW.pago_pago_order_id
        );
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."process_paid_clover_order"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_race_finisher"("p_event_id" "uuid", "p_user_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_event_status text;
  v_configured_winners int;
  v_entry_fee int;
  v_total_participants int;
  v_pot_total numeric;
  v_winners_count int;
  v_user_status text;
  v_is_already_finisher boolean;
  v_position int;
  v_prize_amount int;
  v_prize_share numeric;
  v_result json;
BEGIN
  -- A. Validaciones Iniciales (Bloqueo Row-Level para el Evento)
  SELECT status, configured_winners, entry_fee
  INTO v_event_status, v_configured_winners, v_entry_fee
  FROM events
  WHERE id = p_event_id
  FOR UPDATE; -- LOCK para evitar condiciones de carrera en cierre de evento

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  IF v_event_status = 'completed' THEN
     RETURN json_build_object('success', false, 'message', 'El evento ya ha finalizado', 'race_completed', true);
  END IF;

  -- B. Validar Estado del Usuario
  SELECT status INTO v_user_status
  FROM game_players
  WHERE event_id = p_event_id AND user_id = p_user_id;

  IF v_user_status = 'completed' THEN
     RETURN json_build_object('success', false, 'message', 'Ya has completado esta carrera');
  END IF;

  IF v_user_status != 'active' THEN
     RETURN json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  END IF;

  -- NEW STEP: Get Total Participants (Active + Completed) to determine if everyone finished
  -- We include active and completed.
  SELECT COUNT(*) INTO v_total_participants
  FROM game_players
  WHERE event_id = p_event_id 
  AND status IN ('active', 'completed');

  -- C. Contar ganadores actuales COMPLETED (con bloqueo para consistencia)
  SELECT COUNT(*) INTO v_winners_count
  FROM game_players
  WHERE event_id = p_event_id AND status = 'completed';

  -- Si ya hay suficientes ganadores (aunque el evento no esté 'completed' por latencia), rechazar
  IF v_winners_count >= v_configured_winners THEN
     -- Auto-cerrar si no lo estaba
     UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id;
     RETURN json_build_object('success', false, 'message', 'Podio completo', 'race_completed', true);
  END IF;

  -- D. Calcular Posición
  v_position := v_winners_count + 1;

  -- E. Registrar Finalización (Update game_players)
  UPDATE game_players
  SET 
    status = 'completed',
    finish_time = NOW(),
    completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id) -- Asegurar max clues
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- G. Verificar si el evento debe cerrarse FINALMENTE 
  -- FIX: Close if we reached configured winners OR if we are the last active participant
  -- Note: v_total_participants includes the user we just updated (was active, now completed is still in set)
  -- v_winners_count was count BEFORE update.
  -- v_position is current rank.
  -- If v_position == v_total_participants, then everyone has finished!
  
  IF (v_position >= v_configured_winners) OR (v_position >= v_total_participants) THEN
      UPDATE events 
      SET 
        status = 'completed', 
        winner_id = (CASE WHEN v_position = 1 THEN p_user_id ELSE winner_id END), -- Registrar 1ro como winner principal si se desea
        completed_at = NOW() 
      WHERE id = p_event_id;

      -- AUTO-DISTRIBUTE PRIZES
      PERFORM distribute_event_prizes(p_event_id);

      -- Retrieve the assigned prize for this user
      SELECT amount INTO v_prize_amount 
      FROM prize_distributions 
      WHERE event_id = p_event_id AND user_id = p_user_id;
      
      -- Return extra flag
       RETURN json_build_object(
        'success', true, 
        'position', v_position, 
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
      );
  END IF;

  RETURN json_build_object(
    'success', true, 
    'position', v_position, 
    'prize', 0,
    'race_completed', false
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."register_race_finisher"("p_event_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_competition_final_v3"("p_event_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_player_ids UUID[];
BEGIN
    -- 1. Capturar todos los IDs de game_players vinculados al evento
    SELECT array_agg(id) INTO v_player_ids 
    FROM public.game_players 
    WHERE event_id = p_event_id;

    -- 2. Borrar dependencias que usan game_player_id
    IF v_player_ids IS NOT NULL THEN
        DELETE FROM public.active_powers WHERE caster_id = ANY(v_player_ids) OR target_id = ANY(v_player_ids);
        DELETE FROM public.player_inventory WHERE game_player_id = ANY(v_player_ids);
        DELETE FROM public.player_powers WHERE game_player_id = ANY(v_player_ids);
        DELETE FROM public.transactions WHERE game_player_id = ANY(v_player_ids);
        DELETE FROM public.player_completed_challenges WHERE game_player_id = ANY(v_player_ids);
    END IF;

    -- 3. Borrar progreso de pistas (basado en user_id y clue_id)
    DELETE FROM public.user_clue_progress 
    WHERE clue_id IN (SELECT id FROM public.clues WHERE event_id = p_event_id);

    -- 4. Borrar registros de participación y solicitudes
    DELETE FROM public.game_players WHERE event_id = p_event_id;
    DELETE FROM public.game_requests WHERE event_id = p_event_id;

    -- 5. Resetear estado de los perfiles para que no queden bloqueados
    UPDATE public.profiles 
    SET is_playing = false, status = 'active' 
    WHERE id IN (
        SELECT user_id FROM public.game_players WHERE event_id = p_event_id
    );

    -- 6. Resetear el evento a su estado inicial
    UPDATE public.events 
    SET 
        winner_id = NULL, 
        completed_at = NULL, 
        is_completed = false, 
        status = 'pending' -- Lo ponemos en pending para forzar reinicio manual
    WHERE id = p_event_id;
END;
$$;


ALTER FUNCTION "public"."reset_competition_final_v3"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_competition_final_v4"("p_event_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- 1. Borrar progreso individual de pistas (user_clue_progress)
    -- Crucial: Esto limpia lo que el usuario 'ya hizo' en las pistas del evento
    DELETE FROM public.user_clue_progress 
    WHERE clue_id IN (SELECT id FROM public.clues WHERE event_id = p_event_id);

    -- 2. Borrar poderes activos y efectos en curso
    DELETE FROM public.active_powers WHERE event_id = p_event_id;

    -- 3. Borrar dependencias del jugador (inventario, poderes, retos, transacciones)
    -- Usamos una subconsulta para identificar a los jugadores de este evento específico
    DELETE FROM public.player_inventory WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_powers WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_completed_challenges WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.transactions WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);

    -- 4. Borrar la participación y las solicitudes de acceso
    DELETE FROM public.game_players WHERE event_id = p_event_id;
    DELETE FROM public.game_requests WHERE event_id = p_event_id;

    -- 5. Resetear perfiles globales
    -- IMPORTANTE: Cambiamos is_playing a false para que la app no los bloquee en el juego
    UPDATE public.profiles 
    SET is_playing = false, status = 'active' 
    WHERE id IN (
        SELECT user_id FROM public.game_players WHERE event_id = p_event_id
    );

    -- 6. Resetear el estado del evento principal
    UPDATE public.events 
    SET 
        winner_id = NULL, 
        completed_at = NULL, 
        is_completed = false, 
        status = 'pending' 
    WHERE id = p_event_id;
END;
$$;


ALTER FUNCTION "public"."reset_competition_final_v4"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_competition_nuclear"("p_event_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- 1. Eliminar poderes activos en el evento
    DELETE FROM public.active_powers WHERE event_id = p_event_id;

    -- 2. Limpiar el progreso de pistas de todos los usuarios vinculados a este evento
    DELETE FROM public.user_clue_progress 
    WHERE clue_id IN (SELECT id FROM public.clues WHERE event_id = p_event_id);

    -- 3. Limpiar inventarios, poderes y transacciones de los jugadores del evento
    DELETE FROM public.player_inventory WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_powers WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.transactions WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_completed_challenges WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);

    -- 4. Eliminar la participación principal y solicitudes
    DELETE FROM public.game_players WHERE event_id = p_event_id;
    DELETE FROM public.game_requests WHERE event_id = p_event_id;

    -- 5. Resetear el estado del evento
    UPDATE public.events 
    SET 
        winner_id = NULL, 
        completed_at = NULL, 
        is_completed = false, 
        status = 'active' 
    WHERE id = p_event_id;

    -- 6. Opcional: Resetear el flag is_playing en los perfiles de los usuarios afectados
    -- Esto ayuda si la app bloquea al usuario en "modo juego"
    UPDATE public.profiles 
    SET is_playing = false 
    WHERE id IN (SELECT user_id FROM public.game_players WHERE event_id = p_event_id);
END;
$$;


ALTER FUNCTION "public"."reset_competition_nuclear"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_lives"("p_user_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_game_player_id uuid;
BEGIN
  SELECT id INTO v_game_player_id
  FROM public.game_players
  WHERE user_id = p_user_id
  ORDER BY joined_at DESC
  LIMIT 1;

  IF v_game_player_id IS NULL THEN RETURN 0; END IF;

  UPDATE public.game_players
  SET lives = 3
  WHERE id = v_game_player_id;

  RETURN 3;
END;
$$;


ALTER FUNCTION "public"."reset_lives"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_lives"("p_user_id" "uuid", "p_event_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.game_players
  SET lives = 3
  WHERE user_id = p_user_id AND event_id = p_event_id;

  RETURN 3;
END;
$$;


ALTER FUNCTION "public"."reset_lives"("p_user_id" "uuid", "p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_c_order_plan_to_ledger"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- When an order is paid/success
    IF NEW.status IN ('success', 'paid') AND (OLD.status NOT IN ('success', 'paid') OR OLD.status IS NULL) THEN
        -- Update the corresponding ledger entry
        -- We wait a tiny bit or just allow that the ledger entry might be created by another trigger momentarily
        -- Ideally, we update the row that matches.
        UPDATE public.wallet_ledger
        SET metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{plan_id}',
            to_jsonb(NEW.plan_id)
        )
        WHERE (metadata->>'order_id' = NEW.pago_pago_order_id OR metadata->>'order_id' = NEW.id::text)
          AND (metadata->>'plan_id') IS NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_c_order_plan_to_ledger"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_ban"("user_id" "uuid", "new_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- 1. Verificamos quién está llamando a la función
  SELECT role INTO caller_role FROM profiles WHERE id = auth.uid();

  -- 2. Si no es admin, bloqueamos la ejecución
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RAISE EXCEPTION 'Forbidden: Admin role required';
  END IF;

  -- 3. Si es admin, procedemos
  UPDATE profiles SET status = new_status WHERE id = user_id;
END;
$$;


ALTER FUNCTION "public"."toggle_ban"("user_id" "uuid", "new_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_event_member_ban"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- ☢️ NUCLEAR OPTION: Desactivar TODOS los triggers temporalmente
  ALTER TABLE public.game_players DISABLE TRIGGER ALL;

  UPDATE public.game_players
  SET status = p_new_status
  WHERE user_id = p_user_id AND event_id = p_event_id;

  -- Reactivar triggers
  ALTER TABLE public.game_players ENABLE TRIGGER ALL;

  IF FOUND THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Seguridad: Reactivar triggers si algo falla
  ALTER TABLE public.game_players ENABLE TRIGGER ALL;
  RAISE;
END;
$$;


ALTER FUNCTION "public"."toggle_event_member_ban"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_event_member_ban_v2"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- ☢️ NUCLEAR OPTION V2.1: Desactivar solo TRIGGERS DE USUARIO
  -- 'USER' apaga solo los triggers creados por nosotros (el culpable).
  ALTER TABLE public.game_players DISABLE TRIGGER USER;

  UPDATE public.game_players
  SET status = p_new_status
  WHERE user_id = p_user_id AND event_id = p_event_id;

  -- Reactivar triggers
  ALTER TABLE public.game_players ENABLE TRIGGER USER;

  IF FOUND THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Seguridad: Reactivar triggers si algo falla
  ALTER TABLE public.game_players ENABLE TRIGGER USER;
  RAISE;
END;
$$;


ALTER FUNCTION "public"."toggle_event_member_ban_v2"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_game_progress"("p_game_id" "uuid", "p_user_id" "uuid", "p_coins_reward" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.game_players
  SET 
    current_challenge_index = current_challenge_index + 1,
    coins = coins + p_coins_reward,
    updated_at = now() -- Asumiendo que tienes updated_at, si no, borra esta línea
  WHERE game_id = p_game_id AND user_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."update_game_progress"("p_game_id" "uuid", "p_user_id" "uuid", "p_coins_reward" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."use_life_steal_atomic"("p_caster_gp_id" "uuid", "p_target_gp_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_power_id uuid;
  v_event_id uuid;
  v_target_lives int;
BEGIN
  -- 1. Obtener el ID del poder y el ID del evento
  SELECT id INTO v_power_id FROM public.powers WHERE slug = 'life_steal' LIMIT 1;
  SELECT event_id INTO v_event_id FROM public.game_players WHERE id = p_caster_gp_id;

  -- 2. Verificar que el atacante tenga el poder disponible
  IF NOT EXISTS (
    SELECT 1 FROM public.player_powers 
    WHERE game_player_id = p_caster_gp_id 
    AND power_id = v_power_id 
    AND quantity > 0
  ) THEN
    RETURN FALSE;
  END IF;

  -- 3. Obtener vidas actuales del objetivo
  SELECT lives INTO v_target_lives FROM public.game_players WHERE id = p_target_gp_id;

  -- 4. Validar que el objetivo tenga vida para robar
  IF v_target_lives <= 0 THEN
    RETURN FALSE;
  END IF;

  -- 5. OPERACIÓN ATÓMICA
  -- A. Restar vida al objetivo (mínimo 0)
  UPDATE public.game_players 
  SET lives = lives - 1 
  WHERE id = p_target_gp_id;

  -- B. Sumar vida al atacante (máximo 3)
  UPDATE public.game_players 
  SET lives = LEAST(lives + 1, 3) 
  WHERE id = p_caster_gp_id;

  -- C. Consumir la carga del poder
  UPDATE public.player_powers 
  SET quantity = quantity - 1 
  WHERE game_player_id = p_caster_gp_id AND power_id = v_power_id;

  -- D. Registrar en active_powers para que al rival le salga el banner (SabotageOverlay)
  -- Esto funciona incluso si el rival entra minutos después, verá el efecto si no ha expirado
  INSERT INTO public.active_powers (
    event_id, 
    caster_id, 
    target_id, 
    power_id, 
    expires_at
  ) VALUES (
    v_event_id,
    p_caster_gp_id,
    p_target_gp_id,
    v_power_id,
    now() + interval '10 seconds'
  );

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;


ALTER FUNCTION "public"."use_life_steal_atomic"("p_caster_gp_id" "uuid", "p_target_gp_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."use_power_mechanic"("p_caster_id" "uuid", "p_target_id" "uuid", "p_power_slug" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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


ALTER FUNCTION "public"."use_power_mechanic"("p_caster_id" "uuid", "p_target_id" "uuid", "p_power_slug" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "date" timestamp with time zone NOT NULL,
    "image_url" "text",
    "clue" "text" NOT NULL,
    "max_participants" integer DEFAULT 0,
    "created_by_admin_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "pin" "text",
    "latitude" double precision,
    "longitude" double precision,
    "location_name" "text",
    "winner_id" "uuid",
    "completed_at" timestamp with time zone,
    "is_completed" boolean DEFAULT false,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "type" "text" DEFAULT 'on_site'::"text" NOT NULL,
    "entry_type" "text" DEFAULT 'free'::"text",
    "entry_fee" bigint DEFAULT 0,
    "configured_winners" integer DEFAULT 3,
    CONSTRAINT "events_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'active'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


COMMENT ON COLUMN "public"."events"."winner_id" IS 'User ID of the first player to complete all clues';



COMMENT ON COLUMN "public"."events"."completed_at" IS 'Timestamp when the first player completed all clues';



COMMENT ON COLUMN "public"."events"."is_completed" IS 'Flag indicating if the competition has been won';



COMMENT ON COLUMN "public"."events"."status" IS 'Competition status: pending (not started), active (in progress), completed (finished)';



CREATE OR REPLACE VIEW "public"."active_events_view" AS
 SELECT "id",
    "title",
    "description",
    "date",
    "image_url",
    "clue",
    "max_participants",
    "created_by_admin_id",
    "created_at",
    "pin",
    "latitude",
    "longitude",
    "location_name",
    "winner_id",
    "completed_at",
    "is_completed",
    "status",
    "type",
    "entry_type",
    "entry_fee",
        CASE
            WHEN (("status" = 'pending'::"text") AND ("date" <= "now"())) THEN 'active'::"text"
            ELSE "status"
        END AS "current_status"
   FROM "public"."events";


ALTER VIEW "public"."active_events_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."active_powers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "caster_id" "uuid" NOT NULL,
    "target_id" "uuid",
    "power_id" "uuid" NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "power_slug" "text"
);


ALTER TABLE "public"."active_powers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."active_powers"."power_slug" IS 'Guarda el slug del poder (ej. black_screen) para reacción rápida en la UI';



CREATE TABLE IF NOT EXISTS "public"."app_config" (
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "updated_by" "uuid"
);


ALTER TABLE "public"."app_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "description" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clover_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pago_pago_order_id" "text",
    "user_id" "uuid" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "currency" "text" DEFAULT 'VES'::"text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "transaction_id" "text",
    "bank_reference" "text",
    "payment_url" "text",
    "extra_data" "jsonb" DEFAULT '{}'::"jsonb",
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "plan_id" "uuid"
);


ALTER TABLE "public"."clover_orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clues" (
    "id" bigint NOT NULL,
    "event_id" "uuid" NOT NULL,
    "sequence_index" integer NOT NULL,
    "title" "text" DEFAULT 'Nueva Pista'::"text",
    "description" "text" DEFAULT 'Descripción pendiente'::"text",
    "hint" "text",
    "type" "text" DEFAULT 'qrScan'::"text",
    "puzzle_type" "text",
    "minigame_url" "text",
    "riddle_question" "text",
    "riddle_answer" "text",
    "xp_reward" integer DEFAULT 50,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "latitude" double precision,
    "longitude" double precision,
    "coin_reward" integer DEFAULT 10,
    CONSTRAINT "clues_type_check" CHECK (("type" = ANY (ARRAY['qrScan'::"text", 'geolocation'::"text", 'minigame'::"text", 'npcInteraction'::"text"])))
);


ALTER TABLE "public"."clues" OWNER TO "postgres";


COMMENT ON COLUMN "public"."clues"."xp_reward" IS 'Amount of XP awarded for completing this clue';



COMMENT ON COLUMN "public"."clues"."coin_reward" IS 'Amount of clovers/coins awarded for completing this clue';



ALTER TABLE "public"."clues" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."clues_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."combat_events" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "attacker_id" "uuid" NOT NULL,
    "target_id" "uuid" NOT NULL,
    "power_id" "uuid" NOT NULL,
    "power_slug" "text",
    "result_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."combat_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."game_players" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "lives" integer DEFAULT 3 NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "final_placement" integer,
    "completed_clues_count" integer DEFAULT 0,
    "finish_time" timestamp with time zone,
    "last_active" timestamp with time zone DEFAULT "now"(),
    "status" "text" DEFAULT 'active'::"text",
    "coins" bigint DEFAULT 100,
    CONSTRAINT "chk_max_lives_limit" CHECK ((("lives" >= 0) AND ("lives" <= 3))),
    CONSTRAINT "max_lives_limit" CHECK (("lives" <= 3))
);

ALTER TABLE ONLY "public"."game_players" REPLICA IDENTITY FULL;


ALTER TABLE "public"."game_players" OWNER TO "postgres";


COMMENT ON COLUMN "public"."game_players"."final_placement" IS 'Final placement in the competition (1st, 2nd, 3rd, etc.)';



COMMENT ON COLUMN "public"."game_players"."finish_time" IS 'When the player finished all their clues';



COMMENT ON COLUMN "public"."game_players"."last_active" IS 'Timestamp of the last player action to trigger Realtime updates';



CREATE TABLE IF NOT EXISTS "public"."game_requests" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "event_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."game_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."games" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "admin_id" "uuid" NOT NULL,
    "entry_code" character varying(6) NOT NULL,
    "status" "text" DEFAULT 'waiting'::"text" NOT NULL,
    "title" "text" DEFAULT 'Nueva Carrera'::"text",
    "description" "text",
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "games_status_check" CHECK (("status" = ANY (ARRAY['waiting'::"text", 'active'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."games" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mall_stores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "image_url" "text",
    "qr_code_data" "text" NOT NULL,
    "products" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."mall_stores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."minigame_capitals" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "flag" "text" NOT NULL,
    "capital" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."minigame_capitals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."minigame_emoji_movies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "emojis" "text" NOT NULL,
    "valid_answers" "text"[] NOT NULL,
    "difficulty" "text" DEFAULT 'medium'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."minigame_emoji_movies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."minigame_true_false" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "statement" "text" NOT NULL,
    "is_true" boolean NOT NULL,
    "correction" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."minigame_true_false" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_gateways" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "config" "jsonb",
    "image_url" "text",
    "min_amount" numeric DEFAULT 1.0,
    "type" "text",
    CONSTRAINT "payment_gateways_type_check" CHECK (("type" = ANY (ARRAY['INBOUND'::"text", 'OUTBOUND'::"text", 'BOTH'::"text"])))
);


ALTER TABLE "public"."payment_gateways" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."player_powers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "game_player_id" "uuid" NOT NULL,
    "power_id" "uuid" NOT NULL,
    "last_used_at" timestamp with time zone,
    "acquired_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "quantity" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "player_powers_max_quantity_check" CHECK (("quantity" <= 3)),
    CONSTRAINT "player_powers_quantity_check" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."player_powers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."powers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "power_type" "text" NOT NULL,
    "cost" integer DEFAULT 50 NOT NULL,
    "duration" integer DEFAULT 20,
    "cooldown" integer DEFAULT 60 NOT NULL,
    "icon" "text" DEFAULT '⚡'::"text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "slug" "text"
);


ALTER TABLE "public"."powers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prize_distributions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "position" integer NOT NULL,
    "amount" integer NOT NULL,
    "pot_total" numeric NOT NULL,
    "participants_count" integer NOT NULL,
    "entry_fee" integer NOT NULL,
    "distributed_at" timestamp with time zone DEFAULT "now"(),
    "rpc_success" boolean DEFAULT false,
    "error_message" "text",
    CONSTRAINT "prize_distributions_amount_check" CHECK (("amount" >= 0)),
    CONSTRAINT "prize_distributions_position_check" CHECK ((("position" >= 1) AND ("position" <= 3))),
    CONSTRAINT "prize_distributions_pot_total_check" CHECK (("pot_total" >= (0)::numeric))
);


ALTER TABLE "public"."prize_distributions" OWNER TO "postgres";


COMMENT ON TABLE "public"."prize_distributions" IS 'Audit trail of all prize distributions from completed events';



COMMENT ON COLUMN "public"."prize_distributions"."rpc_success" IS 'Whether the add_clovers RPC succeeded';



COMMENT ON COLUMN "public"."prize_distributions"."error_message" IS 'Error message if RPC failed';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "email" "text",
    "avatar_url" "text",
    "level" integer DEFAULT 1,
    "total_xp" integer DEFAULT 0,
    "profession" "text" DEFAULT 'Novice'::"text",
    "status" "text" DEFAULT 'pending'::"text",
    "stat_speed" integer DEFAULT 0,
    "stat_strength" integer DEFAULT 0,
    "stat_intelligence" integer DEFAULT 0,
    "updated_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "role" "text" DEFAULT 'user'::"text",
    "inventory" "text"[] DEFAULT '{}'::"text"[],
    "is_playing" boolean DEFAULT false,
    "penalty_level" integer DEFAULT 0,
    "ban_ends_at" timestamp with time zone,
    "experience" bigint DEFAULT 0,
    "avatar_id" "text",
    "clovers" numeric DEFAULT 0,
    "dni" "text",
    "phone" "text",
    CONSTRAINT "profiles_dni_format_check" CHECK (("dni" ~* '^[VEJPG][0-9]+$'::"text"))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."dni" IS 'DNI stored as text (e.g. V123456)';



CREATE TABLE IF NOT EXISTS "public"."transaction_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "amount" integer NOT NULL,
    "price" numeric NOT NULL,
    "type" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "icon_url" "text",
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "transaction_plans_amount_check" CHECK (("amount" > 0)),
    CONSTRAINT "transaction_plans_price_check" CHECK (("price" > (0)::numeric)),
    CONSTRAINT "transaction_plans_type_check" CHECK (("type" = ANY (ARRAY['buy'::"text", 'withdraw'::"text"])))
);


ALTER TABLE "public"."transaction_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "game_player_id" "uuid" NOT NULL,
    "shop_item_id" "uuid",
    "transaction_type" "text" NOT NULL,
    "coins_change" integer NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['purchase'::"text", 'reward'::"text", 'power_use'::"text"])))
);


ALTER TABLE "public"."transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "amount" numeric NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb"
);


ALTER TABLE "public"."wallet_ledger" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."user_activity_feed" AS
 SELECT ("wl"."id")::"text" AS "id",
    "wl"."user_id",
    ("wl"."amount")::integer AS "clover_quantity",
    COALESCE("tp"."price", "co_fk"."amount", "co_meta"."amount", (("wl"."metadata" ->> 'amount_usd'::"text"))::numeric, (("wl"."metadata" ->> 'price_usd'::"text"))::numeric, (0)::numeric) AS "fiat_amount",
        CASE
            WHEN ("wl"."amount" >= (0)::numeric) THEN 'deposit'::"text"
            ELSE 'withdrawal'::"text"
        END AS "type",
    'completed'::"text" AS "status",
    "wl"."created_at",
    COALESCE("wl"."description",
        CASE
            WHEN ("wl"."amount" >= (0)::numeric) THEN 'Recarga'::"text"
            ELSE 'Retiro'::"text"
        END) AS "description",
    NULL::"text" AS "payment_url"
   FROM ((("public"."wallet_ledger" "wl"
     LEFT JOIN "public"."transaction_plans" "tp" ON (((("wl"."metadata" ->> 'plan_id'::"text") IS NOT NULL) AND ((("wl"."metadata" ->> 'plan_id'::"text"))::"uuid" = "tp"."id"))))
     LEFT JOIN "public"."clover_orders" "co_fk" ON (("wl"."order_id" = "co_fk"."id")))
     LEFT JOIN "public"."clover_orders" "co_meta" ON (((("wl"."metadata" ->> 'order_id'::"text") IS NOT NULL) AND ((("wl"."metadata" ->> 'order_id'::"text") = "co_meta"."pago_pago_order_id") OR (("wl"."metadata" ->> 'order_id'::"text") = ("co_meta"."id")::"text")))))
UNION ALL
 SELECT ("co"."id")::"text" AS "id",
    "co"."user_id",
    COALESCE("tp"."amount", (("co"."extra_data" ->> 'clovers_amount'::"text"))::integer, (("co"."extra_data" ->> 'clovers_quantity'::"text"))::integer, 0) AS "clover_quantity",
    COALESCE("tp"."price", (("co"."extra_data" ->> 'price_usd'::"text"))::numeric, (("co"."extra_data" ->> 'amount_usd'::"text"))::numeric, "co"."amount") AS "fiat_amount",
    'deposit'::"text" AS "type",
    "co"."status",
    "co"."created_at",
    'Compra de Tréboles'::"text" AS "description",
    "co"."payment_url"
   FROM ("public"."clover_orders" "co"
     LEFT JOIN "public"."transaction_plans" "tp" ON (("co"."plan_id" = "tp"."id")))
  WHERE ("co"."status" <> ALL (ARRAY['success'::"text", 'paid'::"text"]));


ALTER VIEW "public"."user_activity_feed" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_clue_progress" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "clue_id" bigint NOT NULL,
    "is_completed" boolean DEFAULT false,
    "is_locked" boolean DEFAULT true,
    "completed_at" timestamp with time zone
);


ALTER TABLE "public"."user_clue_progress" OWNER TO "postgres";


ALTER TABLE "public"."user_clue_progress" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_clue_progress_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."user_inventory" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "item_name" "text" NOT NULL,
    "acquired_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."user_inventory" OWNER TO "postgres";


ALTER TABLE "public"."user_inventory" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."user_inventory_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."user_payment_methods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "bank_code" "text",
    "account_number" "text",
    "phone_number" "text",
    "dni" "text",
    "is_default" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_payment_methods_dni_check" CHECK (("dni" ~* '^[VEJPG][0-9]+$'::"text"))
);


ALTER TABLE "public"."user_payment_methods" OWNER TO "postgres";


ALTER TABLE ONLY "public"."active_powers"
    ADD CONSTRAINT "active_powers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_config"
    ADD CONSTRAINT "app_config_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."clover_orders"
    ADD CONSTRAINT "clover_orders_pago_pago_order_id_key" UNIQUE ("pago_pago_order_id");



ALTER TABLE ONLY "public"."clover_orders"
    ADD CONSTRAINT "clover_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clues"
    ADD CONSTRAINT "clues_event_id_sequence_index_key" UNIQUE ("event_id", "sequence_index");



ALTER TABLE ONLY "public"."clues"
    ADD CONSTRAINT "clues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."combat_events"
    ADD CONSTRAINT "combat_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."game_players"
    ADD CONSTRAINT "game_players_game_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."game_players"
    ADD CONSTRAINT "game_players_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."game_requests"
    ADD CONSTRAINT "game_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."game_requests"
    ADD CONSTRAINT "game_requests_user_id_event_id_key" UNIQUE ("user_id", "event_id");



ALTER TABLE ONLY "public"."games"
    ADD CONSTRAINT "games_entry_code_key" UNIQUE ("entry_code");



ALTER TABLE ONLY "public"."games"
    ADD CONSTRAINT "games_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mall_stores"
    ADD CONSTRAINT "mall_stores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."minigame_capitals"
    ADD CONSTRAINT "minigame_capitals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."minigame_emoji_movies"
    ADD CONSTRAINT "minigame_emoji_movies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."minigame_true_false"
    ADD CONSTRAINT "minigame_true_false_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_gateways"
    ADD CONSTRAINT "payment_gateways_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_gateways"
    ADD CONSTRAINT "payment_gateways_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."player_powers"
    ADD CONSTRAINT "player_powers_game_player_id_power_id_key" UNIQUE ("game_player_id", "power_id");



ALTER TABLE ONLY "public"."player_powers"
    ADD CONSTRAINT "player_powers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."powers"
    ADD CONSTRAINT "powers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."powers"
    ADD CONSTRAINT "powers_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."prize_distributions"
    ADD CONSTRAINT "prize_distributions_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."prize_distributions"
    ADD CONSTRAINT "prize_distributions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_dni_key" UNIQUE ("dni");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_phone_key" UNIQUE ("phone");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transaction_plans"
    ADD CONSTRAINT "transaction_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_clue_progress"
    ADD CONSTRAINT "user_clue_progress_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_clue_progress"
    ADD CONSTRAINT "user_clue_progress_user_id_clue_id_key" UNIQUE ("user_id", "clue_id");



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_payment_methods"
    ADD CONSTRAINT "user_payment_methods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wallet_ledger"
    ADD CONSTRAINT "wallet_ledger_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_active_powers_event_id" ON "public"."active_powers" USING "btree" ("event_id");



CREATE INDEX "idx_active_powers_expires_at" ON "public"."active_powers" USING "btree" ("expires_at");



CREATE INDEX "idx_active_powers_game_id" ON "public"."active_powers" USING "btree" ("event_id");



CREATE INDEX "idx_active_powers_target_id" ON "public"."active_powers" USING "btree" ("target_id");



CREATE INDEX "idx_active_powers_target_slug" ON "public"."active_powers" USING "btree" ("target_id", "power_slug");



CREATE INDEX "idx_clover_orders_pago_pago_id" ON "public"."clover_orders" USING "btree" ("pago_pago_order_id");



CREATE INDEX "idx_clues_event_id" ON "public"."clues" USING "btree" ("event_id");



CREATE INDEX "idx_events_is_completed" ON "public"."events" USING "btree" ("is_completed");



CREATE INDEX "idx_events_status" ON "public"."events" USING "btree" ("status");



CREATE INDEX "idx_events_winner" ON "public"."events" USING "btree" ("winner_id");



CREATE INDEX "idx_game_players_event_id" ON "public"."game_players" USING "btree" ("event_id");



CREATE INDEX "idx_game_players_event_user" ON "public"."game_players" USING "btree" ("event_id", "user_id");



CREATE INDEX "idx_game_players_finish" ON "public"."game_players" USING "btree" ("event_id", "finish_time");



CREATE INDEX "idx_game_players_game_id" ON "public"."game_players" USING "btree" ("event_id");



CREATE INDEX "idx_game_players_placement" ON "public"."game_players" USING "btree" ("event_id", "final_placement");



CREATE INDEX "idx_game_players_user_id" ON "public"."game_players" USING "btree" ("user_id");



CREATE INDEX "idx_games_admin_id" ON "public"."games" USING "btree" ("admin_id");



CREATE INDEX "idx_games_entry_code" ON "public"."games" USING "btree" ("entry_code");



CREATE INDEX "idx_games_status" ON "public"."games" USING "btree" ("status");



CREATE UNIQUE INDEX "idx_player_power_unique" ON "public"."player_powers" USING "btree" ("game_player_id", "power_id");



CREATE INDEX "idx_powers_slug" ON "public"."powers" USING "btree" ("slug");



CREATE INDEX "idx_prize_distributions_distributed_at" ON "public"."prize_distributions" USING "btree" ("distributed_at" DESC);



CREATE INDEX "idx_prize_distributions_event" ON "public"."prize_distributions" USING "btree" ("event_id");



CREATE INDEX "idx_prize_distributions_user" ON "public"."prize_distributions" USING "btree" ("user_id");



CREATE INDEX "idx_transaction_plans_type_active" ON "public"."transaction_plans" USING "btree" ("type", "is_active");



CREATE INDEX "idx_transactions_game_player" ON "public"."transactions" USING "btree" ("game_player_id");



CREATE OR REPLACE TRIGGER "on_event_delete" AFTER DELETE ON "public"."events" FOR EACH ROW EXECUTE FUNCTION "public"."handle_event_deletion"();



CREATE OR REPLACE TRIGGER "tr_on_clover_order_paid" AFTER UPDATE ON "public"."clover_orders" FOR EACH ROW EXECUTE FUNCTION "public"."process_paid_clover_order"();



CREATE OR REPLACE TRIGGER "tr_reset_status_after_invisibility" AFTER DELETE ON "public"."active_powers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_status_on_power_expiry"();



CREATE OR REPLACE TRIGGER "trg_sync_plan_id_to_ledger" AFTER UPDATE ON "public"."clover_orders" FOR EACH ROW EXECUTE FUNCTION "public"."sync_c_order_plan_to_ledger"();



CREATE OR REPLACE TRIGGER "update_clover_orders_updated_at" BEFORE UPDATE ON "public"."clover_orders" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_games_updated_at" BEFORE UPDATE ON "public"."games" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."active_powers"
    ADD CONSTRAINT "active_powers_caster_id_fkey" FOREIGN KEY ("caster_id") REFERENCES "public"."game_players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."active_powers"
    ADD CONSTRAINT "active_powers_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."active_powers"
    ADD CONSTRAINT "active_powers_power_id_fkey" FOREIGN KEY ("power_id") REFERENCES "public"."powers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."active_powers"
    ADD CONSTRAINT "active_powers_slug_fkey" FOREIGN KEY ("power_slug") REFERENCES "public"."powers"("slug");



ALTER TABLE ONLY "public"."active_powers"
    ADD CONSTRAINT "active_powers_target_id_fkey" FOREIGN KEY ("target_id") REFERENCES "public"."game_players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."app_config"
    ADD CONSTRAINT "app_config_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."clover_orders"
    ADD CONSTRAINT "clover_orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clues"
    ADD CONSTRAINT "clues_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."combat_events"
    ADD CONSTRAINT "combat_events_attacker_id_fkey" FOREIGN KEY ("attacker_id") REFERENCES "public"."game_players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."combat_events"
    ADD CONSTRAINT "combat_events_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."combat_events"
    ADD CONSTRAINT "combat_events_target_id_fkey" FOREIGN KEY ("target_id") REFERENCES "public"."game_players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_winner_id_fkey" FOREIGN KEY ("winner_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."game_players"
    ADD CONSTRAINT "game_players_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."game_players"
    ADD CONSTRAINT "game_players_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."game_requests"
    ADD CONSTRAINT "game_requests_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."game_requests"
    ADD CONSTRAINT "game_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."games"
    ADD CONSTRAINT "games_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mall_stores"
    ADD CONSTRAINT "mall_stores_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_powers"
    ADD CONSTRAINT "player_powers_game_player_id_fkey" FOREIGN KEY ("game_player_id") REFERENCES "public"."game_players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_powers"
    ADD CONSTRAINT "player_powers_power_id_fkey" FOREIGN KEY ("power_id") REFERENCES "public"."powers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prize_distributions"
    ADD CONSTRAINT "prize_distributions_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prize_distributions"
    ADD CONSTRAINT "prize_distributions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_game_player_id_fkey" FOREIGN KEY ("game_player_id") REFERENCES "public"."game_players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_clue_progress"
    ADD CONSTRAINT "user_clue_progress_clue_id_fkey" FOREIGN KEY ("clue_id") REFERENCES "public"."clues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_clue_progress"
    ADD CONSTRAINT "user_clue_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_inventory"
    ADD CONSTRAINT "user_inventory_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_payment_methods"
    ADD CONSTRAINT "user_payment_methods_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallet_ledger"
    ADD CONSTRAINT "wallet_ledger_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."clover_orders"("id");



ALTER TABLE ONLY "public"."wallet_ledger"
    ADD CONSTRAINT "wallet_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Admin can delete own games" ON "public"."games" FOR DELETE USING (("admin_id" = "auth"."uid"()));



CREATE POLICY "Admin can delete players" ON "public"."game_players" FOR DELETE USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."games"
  WHERE (("games"."id" = "game_players"."event_id") AND ("games"."admin_id" = "auth"."uid"()))))));



CREATE POLICY "Admin can update own games" ON "public"."games" FOR UPDATE USING (("admin_id" = "auth"."uid"()));



CREATE POLICY "Admin full access" ON "public"."transaction_plans" USING (((("auth"."jwt"() ->> 'role'::"text") = 'service_role'::"text") OR (( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'admin'::"text")));



CREATE POLICY "Admins can create games" ON "public"."games" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Admins can manage powers" ON "public"."powers" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Allow Public Read" ON "public"."minigame_emoji_movies" FOR SELECT USING (true);



CREATE POLICY "Allow authenticated users to insert game_players" ON "public"."game_players" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Allow public read for minigame_capitals" ON "public"."minigame_capitals" FOR SELECT USING (true);



CREATE POLICY "Allow public read for minigame_true_false" ON "public"."minigame_true_false" FOR SELECT USING (true);



CREATE POLICY "Clues are visible to everyone" ON "public"."clues" FOR SELECT USING (true);



CREATE POLICY "Enable delete for admins" ON "public"."mall_stores" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Enable insert for admins" ON "public"."mall_stores" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Enable insert for own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Enable read access for all users" ON "public"."mall_stores" FOR SELECT USING (true);



CREATE POLICY "Enable read access for authenticated users" ON "public"."active_powers" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for authenticated users" ON "public"."game_players" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for event participants" ON "public"."game_players" FOR SELECT TO "authenticated" USING ((("event_id" IN ( SELECT "public"."get_my_event_ids"() AS "get_my_event_ids")) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text"))))));



CREATE POLICY "Enable read access for own powers" ON "public"."player_powers" FOR SELECT TO "authenticated" USING (("game_player_id" IN ( SELECT "game_players"."id"
   FROM "public"."game_players"
  WHERE ("game_players"."user_id" = "auth"."uid"()))));



CREATE POLICY "Enable read access for profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for public" ON "public"."game_requests" FOR SELECT USING (true);



CREATE POLICY "Enable update for admins" ON "public"."mall_stores" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Enable update for own powers" ON "public"."player_powers" FOR UPDATE TO "authenticated" USING (("game_player_id" IN ( SELECT "game_players"."id"
   FROM "public"."game_players"
  WHERE ("game_players"."user_id" = "auth"."uid"())))) WITH CHECK (("game_player_id" IN ( SELECT "game_players"."id"
   FROM "public"."game_players"
  WHERE ("game_players"."user_id" = "auth"."uid"()))));



CREATE POLICY "Enable update for own profile" ON "public"."game_players" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Enable update for own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "Eventos visibles para todos" ON "public"."events" FOR SELECT USING (true);



CREATE POLICY "Everyone can read app_settings" ON "public"."app_settings" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "Games are viewable by everyone" ON "public"."games" FOR SELECT USING (true);



CREATE POLICY "Perfiles públicos son visibles por todos" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Players can activate powers" ON "public"."active_powers" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."game_players"
  WHERE (("game_players"."id" = "active_powers"."caster_id") AND ("game_players"."user_id" = "auth"."uid"())))));



CREATE POLICY "Players can add powers" ON "public"."player_powers" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."game_players"
  WHERE (("game_players"."id" = "player_powers"."game_player_id") AND ("game_players"."user_id" = "auth"."uid"())))));



CREATE POLICY "Players can create own transactions" ON "public"."transactions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."game_players"
  WHERE (("game_players"."id" = "transactions"."game_player_id") AND ("game_players"."user_id" = "auth"."uid"())))));



CREATE POLICY "Players can update own powers" ON "public"."player_powers" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."game_players"
  WHERE (("game_players"."id" = "player_powers"."game_player_id") AND ("game_players"."user_id" = "auth"."uid"())))));



CREATE POLICY "Players can view active powers in game" ON "public"."active_powers" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."game_players"
  WHERE (("game_players"."event_id" = "active_powers"."event_id") AND ("game_players"."user_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM "public"."games"
  WHERE (("games"."id" = "active_powers"."event_id") AND ("games"."admin_id" = "auth"."uid"()))))));



CREATE POLICY "Players can view own transactions" ON "public"."transactions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."game_players"
  WHERE (("game_players"."id" = "transactions"."game_player_id") AND ("game_players"."user_id" = "auth"."uid"())))));



CREATE POLICY "Players can view their own combat events" ON "public"."combat_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."game_players" "gp"
  WHERE (("gp"."user_id" = "auth"."uid"()) AND (("gp"."id" = "combat_events"."attacker_id") OR ("gp"."id" = "combat_events"."target_id"))))));



CREATE POLICY "Powers are viewable by everyone" ON "public"."powers" FOR SELECT USING (true);



CREATE POLICY "Profiles are viewable by everyone" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Public read access" ON "public"."transaction_plans" FOR SELECT USING (true);



CREATE POLICY "Read access for clues" ON "public"."clues" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Read access for events" ON "public"."events" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Service role can insert prizes" ON "public"."prize_distributions" FOR INSERT WITH CHECK (true);



CREATE POLICY "Solo administradores pueden gestionar eventos" ON "public"."events" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Solo admins actualizan solicitudes" ON "public"."game_requests" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Solo admins gestionan pistas" ON "public"."clues" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Solo admins pueden actualizar game_players" ON "public"."game_players" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Users can cancel their own orders" ON "public"."clover_orders" FOR UPDATE USING (("auth"."uid"() = "user_id")) WITH CHECK ((("auth"."uid"() = "user_id") AND ("status" = 'cancelled'::"text")));



CREATE POLICY "Users can create orders" ON "public"."clover_orders" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "user_id") AND ("status" = 'pending'::"text")));



CREATE POLICY "Users can create own requests" ON "public"."game_requests" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can manage their own payment methods" ON "public"."user_payment_methods" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can see their own progress" ON "public"."user_clue_progress" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view own orders" ON "public"."clover_orders" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own prizes" ON "public"."prize_distributions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own requests" ON "public"."game_requests" FOR SELECT USING ((("auth"."uid"() = "user_id") OR (( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'admin'::"text")));



CREATE POLICY "Users view own ledger" ON "public"."wallet_ledger" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Usuarios pueden editar su propio perfil" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Usuarios pueden ver sus propias solicitudes" ON "public"."game_requests" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Usuarios ven su propio inventario" ON "public"."user_inventory" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Usuarios ven sus solicitudes o admins ven todas" ON "public"."game_requests" FOR SELECT USING ((("auth"."uid"() = "user_id") OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text"))))));



CREATE POLICY "Ver mis propios poderes" ON "public"."player_powers" FOR SELECT USING (("game_player_id" IN ( SELECT "game_players"."id"
   FROM "public"."game_players"
  WHERE ("game_players"."user_id" = "auth"."uid"()))));



ALTER TABLE "public"."active_powers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_config" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "app_config_admin_write" ON "public"."app_config" USING (((("auth"."jwt"() ->> 'role'::"text") = 'service_role'::"text") OR (( SELECT "profiles"."role"
   FROM "public"."profiles"
  WHERE ("profiles"."id" = "auth"."uid"())) = 'admin'::"text")));



CREATE POLICY "app_config_select_all" ON "public"."app_config" FOR SELECT USING (true);



ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clover_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clues" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."combat_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_players" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."games" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mall_stores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."minigame_capitals" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."minigame_emoji_movies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."minigame_true_false" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."player_powers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."powers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prize_distributions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transaction_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_clue_progress" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_payment_methods" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallet_ledger" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."active_powers";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."combat_events";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."game_players";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."games";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."profiles";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

















































































































































































GRANT ALL ON FUNCTION "public"."add_clovers"("target_user_id" "uuid", "amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_clovers"("target_user_id" "uuid", "amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_clovers"("target_user_id" "uuid", "amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."attempt_start_minigame"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."attempt_start_minigame"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."attempt_start_minigame"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."broadcast_power"("p_caster_id" "uuid", "p_power_slug" "text", "p_rival_targets" "jsonb", "p_event_id" "uuid", "p_duration_seconds" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."broadcast_power"("p_caster_id" "uuid", "p_power_slug" "text", "p_rival_targets" "jsonb", "p_event_id" "uuid", "p_duration_seconds" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."broadcast_power"("p_caster_id" "uuid", "p_power_slug" "text", "p_rival_targets" "jsonb", "p_event_id" "uuid", "p_duration_seconds" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."buy_extra_life"("p_user_id" "uuid", "p_event_id" "uuid", "p_cost" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."buy_extra_life"("p_user_id" "uuid", "p_event_id" "uuid", "p_cost" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buy_extra_life"("p_user_id" "uuid", "p_event_id" "uuid", "p_cost" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean, "p_game_player_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean, "p_game_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."buy_item"("p_user_id" "uuid", "p_event_id" "uuid", "p_item_id" "text", "p_cost" integer, "p_is_power" boolean, "p_game_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_and_set_winner"("p_event_id" "uuid", "p_user_id" "uuid", "p_total_clues" integer, "p_completed_clues" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."check_and_set_winner"("p_event_id" "uuid", "p_user_id" "uuid", "p_total_clues" integer, "p_completed_clues" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_and_set_winner"("p_event_id" "uuid", "p_user_id" "uuid", "p_total_clues" integer, "p_completed_clues" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cleanup_expired_powers"() TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_expired_powers"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_expired_powers"() TO "service_role";



GRANT ALL ON FUNCTION "public"."distribute_event_prizes"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."distribute_event_prizes"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."distribute_event_prizes"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."execute_combat_power"("p_event_id" "uuid", "p_caster_id" "uuid", "p_target_id" "uuid", "p_power_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."execute_combat_power"("p_event_id" "uuid", "p_caster_id" "uuid", "p_target_id" "uuid", "p_power_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."execute_combat_power"("p_event_id" "uuid", "p_caster_id" "uuid", "p_target_id" "uuid", "p_power_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_minigame_legally"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_minigame_legally"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_minigame_legally"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_race_and_distribute"("target_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_race_and_distribute"("target_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_race_and_distribute"("target_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_clues_for_event"("target_event_id" "uuid", "quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."generate_clues_for_event"("target_event_id" "uuid", "quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_clues_for_event"("target_event_id" "uuid", "quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_entry_code"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_entry_code"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_entry_code"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_leaderboard"("target_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_leaderboard"("target_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_leaderboard"("target_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_participants_count"("target_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_participants_count"("target_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_participants_count"("target_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_exchange_rate"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_exchange_rate"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_exchange_rate"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_game_leaderboard"("target_game_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_game_leaderboard"("target_game_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_game_leaderboard"("target_game_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_game_player_id"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_game_player_id"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_game_player_id"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_gateway_fee_percentage"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_gateway_fee_percentage"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_gateway_fee_percentage"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_event_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_event_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_event_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_event_id_secure"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_event_id_secure"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_event_id_secure"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_event_ids"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_event_ids"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_event_ids"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_inventory"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_inventory"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_inventory"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_inventory_by_event"("p_user_id" "uuid", "p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_inventory_by_event"("p_user_id" "uuid", "p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_inventory_by_event"("p_user_id" "uuid", "p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_event_deletion"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_event_deletion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_event_deletion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_status_on_power_expiry"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_status_on_power_expiry"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_status_on_power_expiry"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_user_verification"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_user_verification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_user_verification"() TO "service_role";



GRANT ALL ON FUNCTION "public"."initialize_game_for_user"("target_user_id" "uuid", "target_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."initialize_game_for_user"("target_user_id" "uuid", "target_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."initialize_game_for_user"("target_user_id" "uuid", "target_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_event_completed"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_event_completed"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_event_completed"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."join_game"("p_game_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."join_game"("p_game_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_game"("p_game_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."lose_life"("p_user_id" "uuid", "p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."lose_life"("p_user_id" "uuid", "p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."lose_life"("p_user_id" "uuid", "p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_paid_clover_order"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_paid_clover_order"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_paid_clover_order"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_race_finisher"("p_event_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_race_finisher"("p_event_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_race_finisher"("p_event_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_competition_final_v3"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_competition_final_v3"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_competition_final_v3"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_competition_final_v4"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_competition_final_v4"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_competition_final_v4"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_competition_nuclear"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_competition_nuclear"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_competition_nuclear"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_lives"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_lives"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_lives"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_lives"("p_user_id" "uuid", "p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_lives"("p_user_id" "uuid", "p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_lives"("p_user_id" "uuid", "p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_c_order_plan_to_ledger"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_c_order_plan_to_ledger"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_c_order_plan_to_ledger"() TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_ban"("user_id" "uuid", "new_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_ban"("user_id" "uuid", "new_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_ban"("user_id" "uuid", "new_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_event_member_ban"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_event_member_ban"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_event_member_ban"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_event_member_ban_v2"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_event_member_ban_v2"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_event_member_ban_v2"("p_user_id" "uuid", "p_event_id" "uuid", "p_new_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_game_progress"("p_game_id" "uuid", "p_user_id" "uuid", "p_coins_reward" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."update_game_progress"("p_game_id" "uuid", "p_user_id" "uuid", "p_coins_reward" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_game_progress"("p_game_id" "uuid", "p_user_id" "uuid", "p_coins_reward" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."use_life_steal_atomic"("p_caster_gp_id" "uuid", "p_target_gp_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."use_life_steal_atomic"("p_caster_gp_id" "uuid", "p_target_gp_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."use_life_steal_atomic"("p_caster_gp_id" "uuid", "p_target_gp_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."use_power_mechanic"("p_caster_id" "uuid", "p_target_id" "uuid", "p_power_slug" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."use_power_mechanic"("p_caster_id" "uuid", "p_target_id" "uuid", "p_power_slug" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."use_power_mechanic"("p_caster_id" "uuid", "p_target_id" "uuid", "p_power_slug" "text") TO "service_role";
























GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON TABLE "public"."active_events_view" TO "anon";
GRANT ALL ON TABLE "public"."active_events_view" TO "authenticated";
GRANT ALL ON TABLE "public"."active_events_view" TO "service_role";



GRANT ALL ON TABLE "public"."active_powers" TO "anon";
GRANT ALL ON TABLE "public"."active_powers" TO "authenticated";
GRANT ALL ON TABLE "public"."active_powers" TO "service_role";



GRANT ALL ON TABLE "public"."app_config" TO "anon";
GRANT ALL ON TABLE "public"."app_config" TO "authenticated";
GRANT ALL ON TABLE "public"."app_config" TO "service_role";



GRANT ALL ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."app_settings" TO "service_role";



GRANT ALL ON TABLE "public"."clover_orders" TO "anon";
GRANT ALL ON TABLE "public"."clover_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."clover_orders" TO "service_role";



GRANT ALL ON TABLE "public"."clues" TO "anon";
GRANT ALL ON TABLE "public"."clues" TO "authenticated";
GRANT ALL ON TABLE "public"."clues" TO "service_role";



GRANT ALL ON SEQUENCE "public"."clues_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."clues_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."clues_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."combat_events" TO "anon";
GRANT ALL ON TABLE "public"."combat_events" TO "authenticated";
GRANT ALL ON TABLE "public"."combat_events" TO "service_role";



GRANT ALL ON TABLE "public"."game_players" TO "anon";
GRANT ALL ON TABLE "public"."game_players" TO "authenticated";
GRANT ALL ON TABLE "public"."game_players" TO "service_role";



GRANT ALL ON TABLE "public"."game_requests" TO "anon";
GRANT ALL ON TABLE "public"."game_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."game_requests" TO "service_role";



GRANT ALL ON TABLE "public"."games" TO "anon";
GRANT ALL ON TABLE "public"."games" TO "authenticated";
GRANT ALL ON TABLE "public"."games" TO "service_role";



GRANT ALL ON TABLE "public"."mall_stores" TO "anon";
GRANT ALL ON TABLE "public"."mall_stores" TO "authenticated";
GRANT ALL ON TABLE "public"."mall_stores" TO "service_role";



GRANT ALL ON TABLE "public"."minigame_capitals" TO "anon";
GRANT ALL ON TABLE "public"."minigame_capitals" TO "authenticated";
GRANT ALL ON TABLE "public"."minigame_capitals" TO "service_role";



GRANT ALL ON TABLE "public"."minigame_emoji_movies" TO "anon";
GRANT ALL ON TABLE "public"."minigame_emoji_movies" TO "authenticated";
GRANT ALL ON TABLE "public"."minigame_emoji_movies" TO "service_role";



GRANT ALL ON TABLE "public"."minigame_true_false" TO "anon";
GRANT ALL ON TABLE "public"."minigame_true_false" TO "authenticated";
GRANT ALL ON TABLE "public"."minigame_true_false" TO "service_role";



GRANT ALL ON TABLE "public"."payment_gateways" TO "anon";
GRANT ALL ON TABLE "public"."payment_gateways" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_gateways" TO "service_role";



GRANT ALL ON TABLE "public"."player_powers" TO "anon";
GRANT ALL ON TABLE "public"."player_powers" TO "authenticated";
GRANT ALL ON TABLE "public"."player_powers" TO "service_role";



GRANT ALL ON TABLE "public"."powers" TO "anon";
GRANT ALL ON TABLE "public"."powers" TO "authenticated";
GRANT ALL ON TABLE "public"."powers" TO "service_role";



GRANT ALL ON TABLE "public"."prize_distributions" TO "anon";
GRANT ALL ON TABLE "public"."prize_distributions" TO "authenticated";
GRANT ALL ON TABLE "public"."prize_distributions" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."transaction_plans" TO "anon";
GRANT ALL ON TABLE "public"."transaction_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."transaction_plans" TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."wallet_ledger" TO "anon";
GRANT ALL ON TABLE "public"."wallet_ledger" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_ledger" TO "service_role";



GRANT ALL ON TABLE "public"."user_activity_feed" TO "anon";
GRANT ALL ON TABLE "public"."user_activity_feed" TO "authenticated";
GRANT ALL ON TABLE "public"."user_activity_feed" TO "service_role";



GRANT ALL ON TABLE "public"."user_clue_progress" TO "anon";
GRANT ALL ON TABLE "public"."user_clue_progress" TO "authenticated";
GRANT ALL ON TABLE "public"."user_clue_progress" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_clue_progress_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_clue_progress_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_clue_progress_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_inventory" TO "anon";
GRANT ALL ON TABLE "public"."user_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."user_inventory" TO "service_role";



GRANT ALL ON SEQUENCE "public"."user_inventory_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."user_inventory_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."user_inventory_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."user_payment_methods" TO "authenticated";
GRANT ALL ON TABLE "public"."user_payment_methods" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































