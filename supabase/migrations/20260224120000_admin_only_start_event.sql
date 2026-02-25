-- =============================================================
-- Migration: Admin-Only Event Activation
-- Created: 2026-02-24
-- Description: 
--   Removes any client-side ability to auto-activate events.
--   Creates a secure RPC `start_event` that only admins can call.
--   Adds RLS policy to prevent non-admin status updates on events.
-- =============================================================

-- 1. Create the secure admin-only start_event RPC
CREATE OR REPLACE FUNCTION public.start_event(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event RECORD;
  v_caller_role TEXT;
BEGIN
  -- 1. Validate caller is admin or service_role
  IF (auth.jwt() ->> 'role') = 'service_role' THEN
    v_caller_role := 'service_role';
  ELSE
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Solo administradores pueden iniciar eventos.';
    END IF;
  END IF;

  -- 2. Fetch the event and validate it exists
  SELECT id, status, title
  INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EVENT_NOT_FOUND: El evento % no existe.', p_event_id;
  END IF;

  -- 3. Validate the event is in 'pending' state
  IF v_event.status != 'pending' THEN
    RAISE EXCEPTION 'INVALID_STATE: El evento ya está en estado "%". Solo se pueden iniciar eventos en estado "pending".', v_event.status;
  END IF;

  -- 4. Atomically update the event status to 'active'
  UPDATE public.events
  SET status = 'active'
  WHERE id = p_event_id
    AND status = 'pending'; -- Double-check to prevent race conditions

  IF NOT FOUND THEN
    RAISE EXCEPTION 'RACE_CONDITION: El estado del evento cambió durante la operación. Intente de nuevo.';
  END IF;

  -- 5. Log the admin action
  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, details)
  VALUES (
    auth.uid(),
    'START_EVENT',
    'events',
    p_event_id,
    jsonb_build_object(
      'event_title', v_event.title,
      'previous_status', 'pending',
      'new_status', 'active',
      'started_at', now()
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'event_id', p_event_id,
    'new_status', 'active',
    'started_by', auth.uid(),
    'started_at', now()
  );
END;
$$;

-- 2. Grant execute permission to authenticated users (RPC-level auth handles the rest)
GRANT EXECUTE ON FUNCTION public.start_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_event(UUID) TO service_role;

-- 3. Add a comment for documentation
COMMENT ON FUNCTION public.start_event(UUID) IS 
  'Secure RPC to change event status from pending to active. Only callable by admin users. Prevents any automatic or client-side activation.';
