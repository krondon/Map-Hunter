-- Migration: Add ON DELETE CASCADE to combat_events foreign keys
-- Created at: 2026-02-01 20:15:50 (approximate)

-- 1. Drop existing foreign key constraints
ALTER TABLE public.combat_events
  DROP CONSTRAINT IF EXISTS combat_events_attacker_id_fkey,
  DROP CONSTRAINT IF EXISTS combat_events_target_id_fkey,
  DROP CONSTRAINT IF EXISTS combat_events_event_id_fkey;

-- 2. Recreate constraints with ON DELETE CASCADE

-- Attacker: When a player is deleted, their attacks are removed
ALTER TABLE public.combat_events
  ADD CONSTRAINT combat_events_attacker_id_fkey
  FOREIGN KEY (attacker_id)
  REFERENCES public.game_players(id)
  ON DELETE CASCADE;

-- Target: When a player is deleted, attacks against them are removed
ALTER TABLE public.combat_events
  ADD CONSTRAINT combat_events_target_id_fkey
  FOREIGN KEY (target_id)
  REFERENCES public.game_players(id)
  ON DELETE CASCADE;

-- Event: When an event is deleted, all associated combat logs are removed
ALTER TABLE public.combat_events
  ADD CONSTRAINT combat_events_event_id_fkey
  FOREIGN KEY (event_id)
  REFERENCES public.events(id)
  ON DELETE CASCADE;
