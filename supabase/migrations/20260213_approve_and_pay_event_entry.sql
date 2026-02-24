-- =============================================================
-- Migration: Add event pot column + approve_and_pay_event_entry RPC
-- Purpose: Atomic approval + payment for event access requests.
--          Ensures NO clovers are deducted until admin approval.
-- Depends on: secure_clover_payment RPC
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Add 'pot' column to events table (accumulated entry fees)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE events ADD COLUMN IF NOT EXISTS pot INTEGER DEFAULT 0;

-- ─────────────────────────────────────────────────────────────
-- 2. RPC: approve_and_pay_event_entry
--    Called by admin when approving a paid event request.
--    Executes the ENTIRE flow atomically:
--      a) Validate request is pending
--      b) Call secure_clover_payment (deduct user clovers)
--      c) Add to event pot
--      d) Create game_player record
--      e) Update request status
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION approve_and_pay_event_entry(
  p_request_id UUID,
  p_admin_id UUID DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_event_id UUID;
  v_entry_fee INTEGER;
  v_request_status TEXT;
  v_payment_result JSON;
  v_existing_player UUID;
BEGIN
  -- ── Step 1: Lock and validate the request ──
  SELECT user_id, event_id, status
  INTO v_user_id, v_event_id, v_request_status
  FROM game_requests WHERE id = p_request_id FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_request_status != 'pending' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'REQUEST_NOT_PENDING',
      'current_status', v_request_status
    );
  END IF;

  -- ── Step 2: Check for duplicate game_player (idempotency) ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = v_user_id AND event_id = v_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    UPDATE game_requests SET status = 'approved' WHERE id = p_request_id;
    RETURN json_build_object('success', true, 'paid', false, 'note', 'ALREADY_PLAYER');
  END IF;

  -- ── Step 3: Get event entry fee ──
  SELECT COALESCE(entry_fee, 0) INTO v_entry_fee
  FROM events WHERE id = v_event_id;

  -- ── Step 4: Free event — just approve and create player ──
  IF v_entry_fee = 0 THEN
    UPDATE game_requests SET status = 'approved' WHERE id = p_request_id;

    -- Upgrade spectator if exists, otherwise create new
    UPDATE game_players
      SET status = 'active', lives = 3, joined_at = NOW()
      WHERE user_id = v_user_id AND event_id = v_event_id AND status = 'spectator';

    IF NOT FOUND THEN
      INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
      VALUES (v_user_id, v_event_id, 'active', 3, NOW());
    END IF;

    -- ── Log Admin Action (Audit) ──
    INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
    VALUES (
      auth.uid(), 
      'PLAYER_ACCEPTED', 
      'game_players', 
      p_request_id,
      jsonb_build_object(
        'event_id', v_event_id,
        'user_id', v_user_id,
        'fee', 0,
        'type', 'free_event'
      )
    );

    RETURN json_build_object('success', true, 'paid', false, 'amount', 0);
  END IF;

  -- ── Step 5: Paid event — execute atomic payment ──
  v_payment_result := secure_clover_payment(
    v_user_id,
    v_entry_fee,
    'event_entry:' || v_event_id::TEXT
  );

  IF (v_payment_result->>'success')::BOOLEAN != true THEN
    -- Payment failed (insufficient funds, etc.)
    UPDATE game_requests SET status = 'payment_failed' WHERE id = p_request_id;
    RETURN json_build_object(
      'success', false,
      'error', 'PAYMENT_FAILED',
      'payment_error', v_payment_result->>'error',
      'details', v_payment_result
    );
  END IF;

  -- ── Step 6: Payment succeeded — finalize ──
  -- 6a. Update request status
  UPDATE game_requests SET status = 'paid' WHERE id = p_request_id;

  -- 6b. Create game_player (upgrade spectator if exists)
  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = v_user_id AND event_id = v_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (v_user_id, v_event_id, 'active', 3, NOW());
  END IF;

  -- 6c. Increment event pot
  UPDATE events SET pot = COALESCE(pot, 0) + v_entry_fee WHERE id = v_event_id;

  -- ── Step 7: Log Admin Action (Audit) ──
  INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
  VALUES (
    auth.uid(), 
    'PLAYER_ACCEPTED', 
    'game_players', 
    p_request_id, -- Using request ID as temporary target or we could query the game_player ID
    jsonb_build_object(
      'event_id', v_event_id,
      'user_id', v_user_id,
      'fee', v_entry_fee,
      'pot_contribution', v_entry_fee
    )
  );

  RETURN json_build_object(
    'success', true,
    'paid', true,
    'amount', v_entry_fee,
    'new_balance', (v_payment_result->>'new_balance')::INTEGER
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 3. RPC: join_online_paid_event
--    For ONLINE events that don't require admin approval.
--    Atomic: payment + player creation in one transaction.
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

-- Agregar al inicio del cuerpo de la función:
IF p_user_id != auth.uid() THEN
  RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
END IF;
  -- ── Step 1: Idempotency — check if already a player ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = p_user_id AND event_id = p_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
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

  -- ── Step 5: Increment event pot ──
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
-- 4. Grant permissions
-- ─────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION approve_and_pay_event_entry(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION join_online_paid_event(UUID, UUID) TO authenticated;
