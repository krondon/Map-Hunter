-- =============================================================
-- Migration: 20260222_runner_bet_commission
-- Purpose: Implement Net Profit Commission model for the winning
--          runner (player) from the betting pool.
--
-- Business Rules:
--   - Commission is taken from NET PROFIT only (not total pool)
--   - NetProfit = TotalPool - (WinnersCount × TicketPrice)
--   - Commission = FLOOR(NetProfit × pct / 100)
--   - Dust (integer remainder) goes to runner
--   - Unanimous case: NetProfit=0 → Commission=0, refund bettors
--   - House Win (0 winners): entire pool goes to runner
--   - All arithmetic is INTEGER (no floats)
--   - Sum-Zero: BettorPayouts + RunnerTotal = TotalPool (always)
-- =============================================================

-- 1. Schema: Add configurable commission percentage per event
ALTER TABLE public.events
ADD COLUMN IF NOT EXISTS runner_bet_commission_pct INTEGER DEFAULT 10
CHECK (runner_bet_commission_pct >= 0 AND runner_bet_commission_pct <= 50);

-- 2. Replace resolve_event_bets with commission logic
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

    -- Get the runner's user_id (the winning player)
    SELECT user_id INTO v_runner_user_id
    FROM public.game_players
    WHERE event_id = p_event_id AND id = p_winner_racer_id;

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
    -- ──────────────────────────────────────────────
    SELECT COUNT(*) INTO v_winners_count
    FROM public.bets
    WHERE event_id = p_event_id AND racer_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 4. HOUSE WIN: Nobody bet on the winner
    -- ──────────────────────────────────────────────
    IF v_winners_count = 0 THEN
        -- Entire pool goes to the runner
        v_runner_total := v_total_pool;

        IF v_runner_user_id IS NOT NULL THEN
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
                    'total_pool', v_total_pool
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'scenario', 'house_win',
            'total_pool', v_total_pool,
            'runner_commission', v_runner_total,
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
        -- Dust absorbs any edge case where net_profit < 0 (shouldn't happen
        -- with uniform pricing, but defensive)
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

-- ──────────────────────────────────────────────────────────────
-- VERIFICATION QUERIES (Run in Supabase SQL Editor after migration)
-- ──────────────────────────────────────────────────────────────
-- 
-- Scenario 1: Normal (10 bets, 3 winners, ticket=100, pct=10)
--   TotalPool=1000, NetProfit=700, Commission=70
--   Distributable=930, Payout=310, Dust=0, RunnerTotal=70
--   Check: 310*3 + 70 = 1000 ✅
--
-- Scenario 2: Remainder/Dust (10 bets, 7 winners, ticket=100, pct=10)
--   TotalPool=1000, NetProfit=300, Commission=30
--   Distributable=970, Payout=138, Dust=4, RunnerTotal=34
--   Check: 138*7 + 34 = 966+34 = 1000 ✅
--
-- Scenario 3: Unanimous (10 bets, 10 winners, ticket=100)
--   TotalPool=1000, NetProfit=0, Commission=0
--   Payout=100 (refund), RunnerTotal=0
--   Check: 100*10 + 0 = 1000 ✅
--
-- Scenario 4: House Win (10 bets, 0 winners, ticket=100)
--   TotalPool=1000, RunnerTotal=1000
--   Check: 0 + 1000 = 1000 ✅
--
-- Scenario 5: Single Winner (5 bets, 1 winner, ticket=100, pct=10)
--   TotalPool=500, NetProfit=400, Commission=40
--   Distributable=460, Payout=460, Dust=0, RunnerTotal=40
--   Check: 460 + 40 = 500 ✅
