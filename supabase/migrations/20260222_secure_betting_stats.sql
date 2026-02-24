-- =============================================================
-- Migration: Secure betting stats RPC
-- Purpose: After dropping "Public can view all bets" RLS policy,
--          provide a SECURITY DEFINER function that safely returns
--          aggregate betting stats (total pot, total bets) for an
--          event WITHOUT exposing individual bet records.
-- =============================================================

CREATE OR REPLACE FUNCTION public.get_event_betting_stats(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_pot BIGINT;
  v_total_bets BIGINT;
BEGIN
  SELECT 
    COALESCE(SUM(amount), 0),
    COUNT(*)
  INTO v_total_pot, v_total_bets
  FROM bets
  WHERE event_id = p_event_id;

  RETURN json_build_object(
    'total_pot', v_total_pot,
    'total_bets', v_total_bets
  );
END;
$$;

-- Only authenticated users can query betting stats
GRANT EXECUTE ON FUNCTION get_event_betting_stats(UUID) TO authenticated;
