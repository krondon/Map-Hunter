-- =============================================================
-- RPC: secure_clover_payment
-- Purpose: General-purpose atomic clover deduction for any
--          internal transaction (spectator powers, bets, etc.)
-- =============================================================

CREATE OR REPLACE FUNCTION secure_clover_payment(
  p_user_id UUID,
  p_amount INTEGER,
  p_reason TEXT DEFAULT 'clover_payment'
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_current INTEGER;
  v_new INTEGER;
BEGIN

IF auth.uid() IS NOT NULL AND p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Security Violation: Cannot debit another user.';
  END IF;
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_AMOUNT');
  END IF;

  -- Lock row to prevent race conditions (SELECT ... FOR UPDATE)
  SELECT COALESCE(clovers, 0)::INTEGER INTO v_current
  FROM profiles WHERE id = p_user_id FOR UPDATE;

  IF v_current IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF v_current < p_amount THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INSUFFICIENT_CLOVERS',
      'current', v_current,
      'required', p_amount
    );
  END IF;

  v_new := v_current - p_amount;
  UPDATE profiles SET clovers = v_new WHERE id = p_user_id;

  -- Audit trail: p_reason distinguishes the transaction context
  INSERT INTO wallet_ledger (user_id, amount, description, metadata)
  VALUES (p_user_id, -p_amount, p_reason, jsonb_build_object('type', 'clover_payment'));

  RETURN json_build_object('success', true, 'new_balance', v_new);
END;
$$;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION secure_clover_payment(UUID, INTEGER, TEXT) TO authenticated;
