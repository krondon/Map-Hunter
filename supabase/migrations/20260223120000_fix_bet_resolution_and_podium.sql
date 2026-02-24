-- =============================================================
-- Migration: 20260223120000_fix_bet_resolution_and_podium
-- Purpose: Fix two critical bugs:
--
--   BUG 1: resolve_event_bets has an admin-only security check
--          (auth.role() / is_admin) that BLOCKS all internal calls.
--          When register_race_finisher → distribute_event_prizes →
--          resolve_event_bets is triggered by a normal player,
--          auth.uid() is the player (not admin), so the check
--          raises an exception and bets are NEVER resolved.
--
--   BUG 2: register_race_finisher calls resolve_event_bets directly
--          at position=1 (step G) AND ALSO via distribute_event_prizes
--          (step H). This is redundant and both calls fail due to BUG 1.
--          Additionally, the direct call at step G happens BEFORE
--          distribute_event_prizes sets all final_placements, creating
--          a potential timing issue where the podium isn't fully populated.
--
-- FIX:
--   1. resolve_event_bets: Remove the admin-only security check.
--      This function is SECURITY DEFINER and should NOT be called
--      directly by clients (no GRANT to authenticated). It is only
--      invoked internally by distribute_event_prizes, which already
--      has its own access controls.
--
--   2. register_race_finisher: Remove the redundant direct call to
--      resolve_event_bets at position=1. Bet resolution is handled
--      centrally by distribute_event_prizes, which is called when
--      the podium is full.
--
--   3. distribute_event_prizes: Ensure game_players.status is updated
--      to 'completed' for all non-spectator players when the event
--      finalizes, so the podium screen sees consistent data.
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. FIX resolve_event_bets: Remove admin-only security check
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_event_bets(
    p_event_id UUID,
    p_winner_racer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_pool        INTEGER;
    v_ticket_price      INTEGER;
    v_winners_count     INTEGER;
    v_net_profit        INTEGER;
    v_commission_pct    INTEGER;
    v_commission        INTEGER;
    v_distributable     INTEGER;
    v_payout            INTEGER;
    v_dust              INTEGER;
    v_runner_total      INTEGER;
    v_runner_user_id    UUID;
    v_event_title       TEXT;
BEGIN
    -- ══════════════════════════════════════════════
    -- SECURITY NOTE: No auth check here.
    -- This function is SECURITY DEFINER and MUST only be called
    -- internally by distribute_event_prizes (also SECURITY DEFINER).
    -- No GRANT to 'authenticated' exists, so direct RPC calls are
    -- blocked by PostgREST. The previous admin-only check using
    -- auth.role() / is_admin(auth.uid()) blocked ALL internal calls
    -- when triggered by a normal player finishing the race.
    -- ══════════════════════════════════════════════

    -- ──────────────────────────────────────────────
    -- 1. IDEMPOTENCY: Check if bets were already resolved
    -- ──────────────────────────────────────────────
    IF EXISTS (
        SELECT 1 FROM public.wallet_ledger
        WHERE metadata->>'type' IN ('bet_payout', 'runner_bet_commission')
          AND metadata->>'event_id' = p_event_id::text
        LIMIT 1
    ) THEN
        RETURN jsonb_build_object('success', true, 'message', 'Bets already resolved for this event.');
    END IF;

    -- ──────────────────────────────────────────────
    -- 2. LOAD EVENT DATA
    -- ──────────────────────────────────────────────
    SELECT title, bet_ticket_price, COALESCE(runner_bet_commission_pct, 10)
    INTO v_event_title, v_ticket_price, v_commission_pct
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    -- p_winner_racer_id IS a user_id (profiles.id).
    -- Verify the player exists in the event:
    SELECT user_id INTO v_runner_user_id
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 3. CALCULATE TOTAL POOL
    -- ──────────────────────────────────────────────
    SELECT COALESCE(SUM(amount), 0) INTO v_total_pool
    FROM public.bets
    WHERE event_id = p_event_id;

    IF v_total_pool = 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'No bets placed, no payout.');
    END IF;

    -- ──────────────────────────────────────────────
    -- 4. COUNT WINNING TICKETS
    --    bets.racer_id stores user_id (profiles.id)
    -- ──────────────────────────────────────────────
    SELECT COUNT(*) INTO v_winners_count
    FROM public.bets
    WHERE event_id = p_event_id AND racer_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 5. HOUSE WIN: Nobody bet on the winner
    -- ──────────────────────────────────────────────
    IF v_winners_count = 0 THEN
        v_runner_total := FLOOR(v_total_pool * v_commission_pct / 100.0)::INTEGER;

        IF v_runner_total > 0 AND v_runner_user_id IS NOT NULL THEN
            UPDATE public.profiles
            SET clovers = COALESCE(clovers, 0) + v_runner_total
            WHERE id = v_runner_user_id;

            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
                v_runner_user_id,
                v_runner_total,
                'Comisión Apuestas (House Win): ' || COALESCE(v_event_title, 'Evento'),
                jsonb_build_object(
                    'type', 'runner_bet_commission',
                    'event_id', p_event_id,
                    'scenario', 'house_win',
                    'total_pool', v_total_pool,
                    'commission_pct', v_commission_pct
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'scenario', 'house_win',
            'total_pool', v_total_pool,
            'commission_pct', v_commission_pct,
            'runner_commission', v_runner_total,
            'house_profit', v_total_pool - COALESCE(v_runner_total, 0),
            'payout_per_ticket', 0,
            'total_winners', 0
        );
    END IF;

    -- ──────────────────────────────────────────────
    -- 6. CALCULATE NET PROFIT
    -- ──────────────────────────────────────────────
    v_net_profit := v_total_pool - (v_winners_count * v_ticket_price);

    -- ──────────────────────────────────────────────
    -- 7. UNANIMOUS CASE: All bettors chose the winner
    -- ──────────────────────────────────────────────
    IF v_net_profit <= 0 THEN
        v_payout := v_ticket_price;
        v_commission := 0;
        v_runner_total := 0;
        v_dust := v_total_pool - (v_payout * v_winners_count);

        -- Credit each winning bettor (refund)
        WITH winners AS (
            SELECT user_id
            FROM public.bets
            WHERE event_id = p_event_id AND racer_id = p_winner_racer_id
        ),
        updated_profiles AS (
            UPDATE public.profiles
            SET clovers = clovers + v_payout
            FROM winners
            WHERE profiles.id = winners.user_id
            RETURNING profiles.id
        )
        INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
        SELECT
            user_id,
            v_payout,
            'Apuesta Devuelta (Unánime): ' || COALESCE(v_event_title, 'Evento'),
            jsonb_build_object(
                'type', 'bet_payout',
                'event_id', p_event_id,
                'scenario', 'unanimous',
                'racer_id', p_winner_racer_id
            )
        FROM winners;

        -- Dust to runner
        IF v_dust > 0 AND v_runner_user_id IS NOT NULL THEN
            v_runner_total := v_dust;
            UPDATE public.profiles
            SET clovers = COALESCE(clovers, 0) + v_dust
            WHERE id = v_runner_user_id;

            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
                v_runner_user_id,
                v_dust,
                'Comisión Apuestas (Residuo): ' || COALESCE(v_event_title, 'Evento'),
                jsonb_build_object(
                    'type', 'runner_bet_commission',
                    'event_id', p_event_id,
                    'scenario', 'unanimous_dust'
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'scenario', 'unanimous',
            'total_pool', v_total_pool,
            'net_profit', 0,
            'runner_commission', v_runner_total,
            'payout_per_ticket', v_payout,
            'total_winners', v_winners_count
        );
    END IF;

    -- ──────────────────────────────────────────────
    -- 8. NORMAL CASE: Commission from net profit
    -- ──────────────────────────────────────────────
    v_commission    := FLOOR(v_net_profit * v_commission_pct / 100.0)::INTEGER;
    v_distributable := v_total_pool - v_commission;
    v_payout        := FLOOR(v_distributable::NUMERIC / v_winners_count)::INTEGER;
    v_dust          := v_distributable - (v_payout * v_winners_count);
    v_runner_total  := v_commission + v_dust;

    -- 8a. Credit each winning bettor
    WITH winners AS (
        SELECT user_id
        FROM public.bets
        WHERE event_id = p_event_id AND racer_id = p_winner_racer_id
    ),
    updated_profiles AS (
        UPDATE public.profiles
        SET clovers = clovers + v_payout
        FROM winners
        WHERE profiles.id = winners.user_id
        RETURNING profiles.id
    )
    INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
    SELECT
        user_id,
        v_payout,
        'Apuesta Ganada: ' || COALESCE(v_event_title, 'Evento'),
        jsonb_build_object(
            'type', 'bet_payout',
            'event_id', p_event_id,
            'scenario', 'normal',
            'racer_id', p_winner_racer_id
        )
    FROM winners;

    -- 8b. Credit runner (commission + dust)
    IF v_runner_total > 0 AND v_runner_user_id IS NOT NULL THEN
        UPDATE public.profiles
        SET clovers = COALESCE(clovers, 0) + v_runner_total
        WHERE id = v_runner_user_id;

        INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
        VALUES (
            v_runner_user_id,
            v_runner_total,
            'Comisión Apuestas: ' || COALESCE(v_event_title, 'Evento'),
            jsonb_build_object(
                'type', 'runner_bet_commission',
                'event_id', p_event_id,
                'scenario', 'normal',
                'net_profit', v_net_profit,
                'commission_pct', v_commission_pct,
                'commission_base', v_commission,
                'dust', v_dust
            )
        );
    END IF;

    -- INVARIANT: (v_payout * v_winners_count) + v_runner_total = v_total_pool
    RETURN jsonb_build_object(
        'success', true,
        'scenario', 'normal',
        'total_pool', v_total_pool,
        'net_profit', v_net_profit,
        'commission_pct', v_commission_pct,
        'runner_commission', v_runner_total,
        'payout_per_ticket', v_payout,
        'total_winners', v_winners_count,
        'dust', v_dust
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- Ensure resolve_event_bets is NOT directly callable by authenticated users.
-- Only SECURITY DEFINER functions (distribute_event_prizes) should call it.
REVOKE EXECUTE ON FUNCTION public.resolve_event_bets(UUID, UUID) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.resolve_event_bets(UUID, UUID) FROM anon;


-- ─────────────────────────────────────────────────────────────
-- 2. FIX register_race_finisher: Remove redundant bet resolution
--    and ensure status is 'completed' for the player.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION register_race_finisher(
  p_event_id uuid,
  p_user_id uuid
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_status text;
  v_configured_winners int;
  v_total_participants int;
  v_winners_count int;
  v_user_status text;
  v_position int;
  v_prize_amount int;
  v_current_placement int;
BEGIN
  -- A. Lock Event
  SELECT status, configured_winners
  INTO v_event_status, v_configured_winners
  FROM events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- B. Validate User Status
  SELECT status, final_placement INTO v_user_status, v_current_placement
  FROM game_players
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- If already completed, return existing data
  IF v_user_status = 'completed' THEN
     SELECT amount INTO v_prize_amount
     FROM prize_distributions
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object(
        'success', true,
        'message', 'Ya has completado esta carrera',
        'position', v_current_placement,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
     );
  END IF;

  -- If event already completed and user is NOT completed, mark them late
  IF v_event_status = 'completed' THEN
     SELECT COUNT(*) INTO v_winners_count
     FROM game_players WHERE event_id = p_event_id AND status = 'completed';
     v_position := v_winners_count + 1;

     UPDATE game_players
     SET status = 'completed',
         finish_time = NOW(),
         final_placement = v_position,
         completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id)
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object('success', true, 'position', v_position, 'prize', 0, 'race_completed', true);
  END IF;

  IF v_user_status != 'active' THEN
     RETURN json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  END IF;

  -- C. Count current winners
  SELECT COUNT(*) INTO v_winners_count
  FROM game_players
  WHERE event_id = p_event_id AND status = 'completed';

  -- If podium already full (race condition edge case), reject
  IF v_winners_count >= v_configured_winners THEN
     UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id AND status != 'completed';
     RETURN json_build_object('success', false, 'message', 'Podio completo', 'race_completed', true);
  END IF;

  -- D. Calculate Position
  v_position := v_winners_count + 1;

  -- E. Register Completion with Position
  UPDATE game_players
  SET
    status = 'completed',
    finish_time = NOW(),
    completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id),
    final_placement = v_position
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- ══════════════════════════════════════════════════════════
  -- FIX: REMOVED direct call to resolve_event_bets at position=1.
  -- Bet resolution is now handled ONLY by distribute_event_prizes
  -- (centralized, after all placements are finalized).
  -- The previous direct call here caused:
  --   1. Redundant resolution (also called by distribute_event_prizes)
  --   2. Auth failure (player's JWT ≠ admin → Access Denied)
  -- ══════════════════════════════════════════════════════════

  -- F. Check if event should close (Podium Full OR Last Participant)
  SELECT COUNT(*) INTO v_total_participants
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed');

  IF (v_position >= v_configured_winners) OR (v_position >= v_total_participants) THEN
      -- Distribute prizes (handles event finalization, placements, prizes, AND bets)
      PERFORM distribute_event_prizes(p_event_id);

      -- Retrieve prize for this user
      SELECT amount INTO v_prize_amount
      FROM prize_distributions
      WHERE event_id = p_event_id AND user_id = p_user_id;

      RETURN json_build_object(
        'success', true,
        'position', v_position,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
      );
  END IF;

  -- Normal return (event not yet closed)
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


-- ─────────────────────────────────────────────────────────────
-- 3. FIX distribute_event_prizes: Update status for ALL players
--    when the event finalizes, so podium screen sees consistent data.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION distribute_event_prizes(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event_record RECORD;
  v_participant_count INT;
  v_completed_count INT;
  v_distributable_pot NUMERIC;
  v_total_collected NUMERIC;
  v_winners RECORD;
  v_prize_amount NUMERIC;
  v_share NUMERIC;
  v_rank INT;
  v_distribution_results JSONB[] := ARRAY[]::JSONB[];
  v_shares NUMERIC[];

  -- Betting integration
  v_winner_user_id UUID;
  v_betting_result JSONB;
BEGIN
  -- 1. Lock Event & Get Details
  SELECT * INTO v_event_record FROM events WHERE id = p_event_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- 2. Idempotency Check
  IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
     RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true, 'already_distributed', true);
  END IF;

  -- 3. Define Distribution Shares
  IF v_event_record.configured_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_event_record.configured_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE
    v_shares := ARRAY[0.50, 0.30, 0.20];
  END IF;

  -- 4. Count ALL Participants (excludes spectators)
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes válidos');
  END IF;

  -- 4.5. Check if race is finished or if caller is admin
  SELECT COUNT(*) INTO v_completed_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status = 'completed';

  IF v_completed_count < v_event_record.configured_winners AND v_completed_count < v_participant_count THEN
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RETURN json_build_object('success', false, 'message', 'La carrera aún no ha terminado o no tienes permisos para forzar la distribución.');
    END IF;
  END IF;

  -- 5. Finalize Event (ALWAYS, even if pot is 0)
  UPDATE events
  SET status = 'completed',
      completed_at = NOW(),
      winner_id = (SELECT user_id FROM game_players WHERE event_id = p_event_id AND status != 'spectator' ORDER BY completed_clues_count DESC, finish_time ASC LIMIT 1)
  WHERE id = p_event_id;

  -- 6. Assign final_placement to ALL non-spectator participants (ALWAYS)
  UPDATE game_players gp
  SET final_placement = ranked.pos
  FROM (
    SELECT id,
      ROW_NUMBER() OVER (
        ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST, last_active ASC NULLS LAST
      ) AS pos
    FROM game_players
    WHERE event_id = p_event_id
      AND status != 'spectator'
  ) AS ranked
  WHERE gp.id = ranked.id;

  -- ══════════════════════════════════════════════════════════
  -- 6.5 FIX: Mark ALL 'active' (non-spectator) players as 'completed'
  --     so the client-side podium screen sees a consistent status.
  --     Players who didn't finish get their final_placement from step 6
  --     (ranked by progress) and status = 'completed'.
  -- ══════════════════════════════════════════════════════════
  UPDATE game_players
  SET status = 'completed'
  WHERE event_id = p_event_id
    AND status = 'active';

  -- 7. Calculate Pot
  v_total_collected := COALESCE(v_event_record.pot, 0);
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      -- Still resolve bets even if prize pot is 0
      SELECT user_id INTO v_winner_user_id
      FROM game_players
      WHERE event_id = p_event_id AND status != 'spectator'
      ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
      LIMIT 1;

      IF v_winner_user_id IS NOT NULL THEN
          v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
      END IF;

      RETURN json_build_object(
        'success', true,
        'message', 'Evento finalizado sin premios (Bote 0)',
        'pot', 0,
        'betting_results', v_betting_result
      );
  END IF;

  -- 8. Select Winners (Top N) and distribute prizes
  v_rank := 0;

  FOR v_winners IN
    SELECT *
    FROM game_players
    WHERE event_id = p_event_id
    AND status IN ('completed') -- All are 'completed' after step 6.5
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_event_record.configured_winners
  LOOP
    v_rank := v_rank + 1;

    -- Identify the #1 winner for betting resolution
    IF v_rank = 1 THEN
       v_winner_user_id := v_winners.user_id;
    END IF;

    IF v_rank <= array_length(v_shares, 1) THEN
        v_share := v_shares[v_rank];
        v_prize_amount := floor(v_distributable_pot * v_share);

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

            -- C. Log to Wallet Ledger
            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
              v_winners.user_id,
              v_prize_amount,
              'Premio Competencia: ' || v_event_record.title || ' (Posición ' || v_rank || ')',
              jsonb_build_object('type', 'event_prize', 'event_id', p_event_id, 'rank', v_rank)
            );

            -- D. Add to results
            v_distribution_results := array_append(v_distribution_results, jsonb_build_object(
                'user_id', v_winners.user_id,
                'rank', v_rank,
                'amount', v_prize_amount
            ));
        END IF;
    END IF;
  END LOOP;

  -- ══════════════════════════════════════════════════════════
  -- 9. RESOLVE BETS: Pass the #1 winner's user_id
  -- ══════════════════════════════════════════════════════════
  IF v_winner_user_id IS NOT NULL THEN
      v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
  ELSE
      v_betting_result := jsonb_build_object('success', false, 'message', 'No winner found to resolve bets');
  END IF;

  RETURN json_build_object(
    'success', true,
    'pot_total', v_total_collected,
    'distributable_pot', v_distributable_pot,
    'winners_count', v_rank,
    'results', v_distribution_results,
    'betting_results', v_betting_result
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;
