-- =============================================================
-- Migration: Fix Online Join Visibility
-- Purpose: Ensure 'Online' event joins (Paid & Free) create 
--          game_requests records so they appear in Admin Dashboard.
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. UPDATE RPC: join_online_paid_event
--    Add INSERT to game_requests with status='approved'
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION join_online_paid_event(
  p_user_id UUID,
  p_event_id UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_entry_fee INTEGER;
  v_payment_result JSON;
  v_existing_player UUID;
BEGIN
  -- ── Step 1: Idempotency — check if already a player ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = p_user_id AND event_id = p_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    -- Ensure request exists and is approved even if player exists
    UPDATE game_requests SET status = 'approved' WHERE user_id = p_user_id AND event_id = p_event_id;
    IF NOT FOUND THEN
      INSERT INTO game_requests (user_id, event_id, status) VALUES (p_user_id, p_event_id, 'approved');
    END IF;
    
    RETURN json_build_object('success', true, 'paid', false, 'note', 'ALREADY_PLAYER');
  END IF;

  -- ── Step 2: Get entry fee ──
  SELECT COALESCE(entry_fee, 0) INTO v_entry_fee
  FROM events WHERE id = p_event_id;

  IF v_entry_fee = 0 THEN
    RETURN json_build_object('success', false, 'error', 'EVENT_IS_FREE');
  END IF;

  -- ── Step 3: Atomic payment ──
  v_payment_result := secure_clover_payment(
    p_user_id,
    v_entry_fee,
    'online_event_entry:' || p_event_id::TEXT
  );

  IF (v_payment_result->>'success')::BOOLEAN != true THEN
    RETURN json_build_object(
      'success', false,
      'error', 'PAYMENT_FAILED',
      'payment_error', v_payment_result->>'error',
      'details', v_payment_result
    );
  END IF;

  -- ── Step 4: Create game_player (upgrade spectator if exists) ──
  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = p_user_id AND event_id = p_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (p_user_id, p_event_id, 'active', 3, NOW());
  END IF;

  -- ── Step 5: Create/Update game_request (The FIX) ──
  -- We set status='approved' so it shows up in the dashboard
  UPDATE game_requests SET status = 'approved' WHERE user_id = p_user_id AND event_id = p_event_id;
  IF NOT FOUND THEN
    INSERT INTO game_requests (user_id, event_id, status) VALUES (p_user_id, p_event_id, 'approved');
  END IF;

  -- ── Step 6: Increment event pot ──
  UPDATE events SET pot = COALESCE(pot, 0) + v_entry_fee WHERE id = p_event_id;

  RETURN json_build_object(
    'success', true,
    'paid', true,
    'amount', v_entry_fee,
    'new_balance', (v_payment_result->>'new_balance')::INTEGER
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 2. NEW RPC: join_online_free_event
--    For FREE Online events. Replaces logic that was split 
--    between client and loose RPCs.
--    Creates game_player AND game_request (approved).
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION join_online_free_event(
  p_user_id UUID,
  p_event_id UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_existing_player UUID;
BEGIN
  -- ── Step 1: Idempotency ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = p_user_id AND event_id = p_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    -- Ensure request exists
    UPDATE game_requests SET status = 'approved' WHERE user_id = p_user_id AND event_id = p_event_id;
    IF NOT FOUND THEN
      INSERT INTO game_requests (user_id, event_id, status) VALUES (p_user_id, p_event_id, 'approved');
    END IF;
    
    RETURN json_build_object('success', true, 'note', 'ALREADY_PLAYER');
  END IF;

  -- ── Step 2: Create game_player (upgrade spectator if exists) ──
  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = p_user_id AND event_id = p_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (p_user_id, p_event_id, 'active', 3, NOW());
  END IF;

  -- ── Step 3: Create game_request (The FIX) ──
  UPDATE game_requests SET status = 'approved' WHERE user_id = p_user_id AND event_id = p_event_id;
  IF NOT FOUND THEN
    INSERT INTO game_requests (user_id, event_id, status) VALUES (p_user_id, p_event_id, 'approved');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION join_online_paid_event(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION join_online_free_event(UUID, UUID) TO authenticated;
