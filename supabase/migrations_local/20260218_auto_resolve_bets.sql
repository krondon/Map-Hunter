-- Migration: Fix Betting Logic - Auto Resolve Bets on Winner
-- Description: Updates check_and_set_winner to call resolve_event_bets automatically.

-- 1. Ensure resolve_event_bets exists (from previous migration)
-- (Assumed)

-- 2. Modify check_and_set_winner
CREATE OR REPLACE FUNCTION public.check_and_set_winner(
    p_event_id UUID,
    p_user_id UUID,
    p_total_clues INTEGER,
    p_completed_clues INTEGER
)
RETURNS TABLE("is_winner" boolean, "placement" integer, "winner_name" "text")
LANGUAGE plpgsql
AS $$
DECLARE
  v_current_winner_id UUID;
  v_is_winner BOOLEAN := FALSE;
  v_placement INTEGER;
  v_winner_name TEXT;
  v_bet_payout JSONB;
BEGIN
  -- Lock the event row to prevent race conditions
  SELECT winner_id INTO v_current_winner_id
  FROM events
  WHERE id = p_event_id
  FOR UPDATE;

  -- Check if all clues are completed
  IF p_completed_clues >= p_total_clues THEN
    -- Check if there's no winner yet
    IF v_current_winner_id IS NULL THEN
      -- This user is the winner!
      UPDATE events
      SET 
        winner_id = p_user_id,
        completed_at = NOW(),
        is_completed = TRUE
      WHERE id = p_event_id;
      
      v_is_winner := TRUE;
      v_placement := 1;
      
      -- Update participant record in game_players
      UPDATE game_players
      SET 
        final_placement = 1,
        completed_clues_count = p_completed_clues,
        finish_time = NOW()
      WHERE event_id = p_event_id AND user_id = p_user_id;
      
      -- TRIGGER BET RESOLUTION (NEW LOGIC)
      -- If bets exist for this event, resolve them immediately
      -- We ignore the result JSON but could log it if needed
      PERFORM public.resolve_event_bets(p_event_id, p_user_id);
      
    ELSE
      -- Someone already won, calculate placement
      v_is_winner := FALSE;
      
      -- Calculate placement based on completion order
      SELECT COALESCE(MAX(final_placement), 0) + 1 INTO v_placement
      FROM game_players
      WHERE event_id = p_event_id AND final_placement IS NOT NULL;
      
      -- Update participant record with placement
      UPDATE game_players
      SET 
        final_placement = v_placement,
        completed_clues_count = p_completed_clues,
        finish_time = NOW()
      WHERE event_id = p_event_id AND user_id = p_user_id;
    END IF;
  ELSE
    -- Not all clues completed yet, no placement
    v_is_winner := FALSE;
    v_placement := NULL;
  END IF;
  
  -- Get winner's name
  SELECT name INTO v_winner_name
  FROM profiles
  WHERE id = COALESCE(v_current_winner_id, (SELECT winner_id FROM events WHERE id = p_event_id));
  
  RETURN QUERY SELECT v_is_winner, v_placement, v_winner_name;
END;
$$;
