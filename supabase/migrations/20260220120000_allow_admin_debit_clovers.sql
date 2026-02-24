-- =============================================================
-- Migration: Allow admins to debit clovers for other users
-- Purpose: Keep anti-IDOR protection for regular users while
--          allowing admin approval flows to charge target users.
-- =============================================================

CREATE OR REPLACE FUNCTION public.secure_clover_payment(
  p_user_id UUID,
  p_amount INTEGER,
  p_reason TEXT DEFAULT 'clover_payment'
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current INTEGER;
  v_new INTEGER;
  v_caller_id UUID;
  v_caller_role TEXT;
BEGIN
  v_caller_id := auth.uid();

  -- Security gate:
  -- - NULL auth.uid() (internal/service context): allowed
  -- - Same user: allowed
  -- - Different user: only allowed for admin
  IF v_caller_id IS NOT NULL AND p_user_id != v_caller_id THEN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS DISTINCT FROM 'admin' THEN
      RAISE EXCEPTION 'Security Violation: Cannot debit another user.';
    END IF;
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_AMOUNT');
  END IF;

  SELECT COALESCE(clovers, 0)::INTEGER INTO v_current
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

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

  UPDATE public.profiles
  SET clovers = v_new
  WHERE id = p_user_id;

  INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
  VALUES (
    p_user_id,
    -p_amount,
    p_reason,
    jsonb_build_object('type', 'clover_payment')
  );

  RETURN json_build_object('success', true, 'new_balance', v_new);
END;
$$;

GRANT EXECUTE ON FUNCTION public.secure_clover_payment(UUID, INTEGER, TEXT) TO authenticated;
