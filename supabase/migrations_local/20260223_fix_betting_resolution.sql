-- =============================================================
-- Migration: 20260223_fix_betting_resolution
-- Purpose: Fix two critical bugs preventing bet payouts:
--
--   BUG 1: distribute_event_prizes lost the call to resolve_event_bets
--          when it was overwritten by pot-calculation fix migrations.
--
--   BUG 2: resolve_event_bets looked up game_players.id = p_winner_racer_id,
--          but bets.racer_id stores profiles.id (user_id), and callers
--          pass user_id. The lookup must use game_players.user_id instead.
--
-- FIX: 
--   1. resolve_event_bets: change game_players lookup from
--      "WHERE id = p_winner_racer_id" to "WHERE user_id = p_winner_racer_id"
--      since p_winner_racer_id is actually a user_id (= profiles.id).
--   2. distribute_event_prizes: re-add the call to resolve_event_bets
--      after distributing prizes, passing the #1 winner's user_id.
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. FIX resolve_event_bets: correct the runner lookup
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
    -- ──────────────────────────────────────────────
    -- 0. SECURITY: Only admins or service_role
    -- ──────────────────────────────────────────────
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can resolve event bets.';
    END IF;

    -- ──────────────────────────────────────────────
    -- 1. LOAD EVENT DATA
    -- ──────────────────────────────────────────────
    SELECT title, bet_ticket_price, COALESCE(runner_bet_commission_pct, 10)
    INTO v_event_title, v_ticket_price, v_commission_pct
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    -- ══════════════════════════════════════════════
    -- FIX: p_winner_racer_id IS a user_id (profiles.id), NOT game_players.id.
    -- bets.racer_id references profiles.id, and callers (register_race_finisher,
    -- distribute_event_prizes) pass user_id. So we look up by user_id.
    -- ══════════════════════════════════════════════
    -- The runner's user_id IS p_winner_racer_id itself.
    -- We just verify the player exists in the event:
    SELECT user_id INTO v_runner_user_id
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 2. CALCULATE TOTAL POOL
    -- ──────────────────────────────────────────────
    SELECT COALESCE(SUM(amount), 0) INTO v_total_pool
    FROM public.bets
    WHERE event_id = p_event_id;

    IF v_total_pool = 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'No bets placed, no payout.');
    END IF;

    -- ──────────────────────────────────────────────
    -- 3. COUNT WINNING TICKETS
    --    bets.racer_id stores user_id (profiles.id),
    --    and p_winner_racer_id IS a user_id → direct match
    -- ──────────────────────────────────────────────
    SELECT COUNT(*) INTO v_winners_count
    FROM public.bets
    WHERE event_id = p_event_id AND racer_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 4. HOUSE WIN: Nobody bet on the winner
    -- ──────────────────────────────────────────────
    IF v_winners_count = 0 THEN
        -- House Win: Runner gets only the configured commission % of total pool.
        -- The rest is house profit (bettors lose their stake).
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
            'house_profit', v_total_pool - v_runner_total,
            'payout_per_ticket', 0,
            'total_winners', 0
        );
    END IF;

    -- ──────────────────────────────────────────────
    -- 5. CALCULATE NET PROFIT
    -- ──────────────────────────────────────────────
    v_net_profit := v_total_pool - (v_winners_count * v_ticket_price);

    -- ──────────────────────────────────────────────
    -- 6. UNANIMOUS CASE: All bettors chose the winner
    -- ──────────────────────────────────────────────
    IF v_net_profit <= 0 THEN
        -- Refund each winner their ticket price (no one loses, no one gains)
        v_payout := v_ticket_price;
        v_commission := 0;
        v_runner_total := 0;
        v_dust := v_total_pool - (v_payout * v_winners_count);

        -- Credit each winning bettor
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

        -- If there's any dust from an edge case, give it to runner
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
    -- 7. NORMAL CASE: Commission from net profit
    -- ──────────────────────────────────────────────
    v_commission    := FLOOR(v_net_profit * v_commission_pct / 100.0)::INTEGER;
    v_distributable := v_total_pool - v_commission;
    v_payout        := FLOOR(v_distributable::NUMERIC / v_winners_count)::INTEGER;
    v_dust          := v_distributable - (v_payout * v_winners_count);
    v_runner_total  := v_commission + v_dust;

    -- ── 7a. Credit each winning bettor ──
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

    -- ── 7b. Credit runner (commission + dust) ──
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

    -- ── 7c. Return results ──
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


-- ─────────────────────────────────────────────────────────────
-- 2. FIX distribute_event_prizes: re-add bet resolution call
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

  -- Betting integration variables
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

  -- 7. Calculate Pot
  v_total_collected := COALESCE(v_event_record.pot, 0);
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      -- ── FIX: Still resolve bets even if prize pot is 0 ──
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
    AND status IN ('active', 'completed')
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
  -- 9. FIX: RESOLVE BETS (was removed by previous migrations)
  --    Pass the #1 winner's user_id, which matches bets.racer_id
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
