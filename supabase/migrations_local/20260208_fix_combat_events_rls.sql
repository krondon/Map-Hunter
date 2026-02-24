-- Migration: Enable RLS on combat_events and add policy
-- Date: 2026-02-08
-- Purpose: Allow players to see combat events where they are attacker OR target.

-- 1. Enable RLS
ALTER TABLE public.combat_events ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies if any (to avoid conflicts/duplication in dev)
DROP POLICY IF EXISTS "Players can view their own combat events" ON public.combat_events;

-- 3. Create Policy
-- A user can see a combat event if:
-- A) They are the attacker (attacker_id maps to a game_player they own)
-- B) They are the target (target_id maps to a game_player they own)

CREATE POLICY "Players can view their own combat events"
ON public.combat_events
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.user_id = auth.uid()
        AND (gp.id = combat_events.attacker_id OR gp.id = combat_events.target_id)
    )
);
