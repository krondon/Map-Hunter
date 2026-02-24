-- Migration: Atomic Clue Count Increment
-- Created: 2026-02-22
-- Purpose: Fix race condition where completed_clues_count is incremented 
--          via non-atomic read-modify-write in the Edge Function.
--          Also updates last_active timestamp for correct leaderboard tiebreaking.

CREATE OR REPLACE FUNCTION increment_clue_count(p_user_id UUID, p_event_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE game_players
  SET 
    completed_clues_count = completed_clues_count + 1,
    last_active = NOW()
  WHERE user_id = p_user_id AND event_id = p_event_id;
END;
$$;
