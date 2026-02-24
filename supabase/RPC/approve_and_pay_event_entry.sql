DECLARE
  v_user_id UUID;
  v_event_id UUID;
  v_entry_fee BIGINT;
  v_request_status TEXT;
  v_payment_result JSON;
  v_existing_player UUID;
BEGIN

-- Agregar al inicio del cuerpo (después de BEGIN):
IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
    RETURN json_build_object('success', false, 'error', 
        'ACCESS_DENIED: Only admins can approve event entries.');
END IF;

  -- ── Step 1: Lock and validate ──
  SELECT user_id, event_id, status
  INTO v_user_id, v_event_id, v_request_status
  FROM game_requests WHERE id = p_request_id FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_request_status != 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_PENDING', 'current_status', v_request_status);
  END IF;

  -- ── Step 2: Idempotency ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = v_user_id AND event_id = v_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    UPDATE game_requests SET status = 'approved' WHERE id = p_request_id;
    RETURN json_build_object('success', true, 'paid', false, 'note', 'ALREADY_PLAYER');
  END IF;

  -- ── Step 3: Entry fee ──
  SELECT COALESCE(entry_fee, 0)::BIGINT INTO v_entry_fee
  FROM events WHERE id = v_event_id;

  -- ── Step 4: Free event ──
  IF v_entry_fee = 0 THEN
    UPDATE game_requests SET status = 'approved' WHERE id = p_request_id;

    UPDATE game_players
      SET status = 'active', lives = 3, joined_at = NOW()
      WHERE user_id = v_user_id AND event_id = v_event_id AND status = 'spectator';

    IF NOT FOUND THEN
      INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
      VALUES (v_user_id, v_event_id, 'active', 3, NOW());
    END IF;

    RETURN json_build_object('success', true, 'paid', false, 'amount', 0);
  END IF;

  -- ── Step 5: Paid event ──
  v_payment_result := secure_clover_payment(v_user_id, v_entry_fee, 'event_entry:' || v_event_id::TEXT);

  IF (v_payment_result->>'success')::BOOLEAN != true THEN
    UPDATE game_requests SET status = 'payment_failed' WHERE id = p_request_id;
    RETURN json_build_object('success', false, 'error', 'PAYMENT_FAILED', 'payment_error', v_payment_result->>'error');
  END IF;

  -- ── Step 6: Finalize ──
  UPDATE game_requests SET status = 'paid' WHERE id = p_request_id;

  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = v_user_id AND event_id = v_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (v_user_id, v_event_id, 'active', 3, NOW());
  END IF;

  UPDATE events SET pot = COALESCE(pot, 0) + v_entry_fee WHERE id = v_event_id;

  RETURN json_build_object(
    'success', true,
    'paid', true,
    'amount', v_entry_fee,
    'new_balance', (v_payment_result->>'new_balance')::NUMERIC
  );
END;