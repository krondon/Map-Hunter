-- Migration: Enable Realtime for Bets
-- Description: Adds the public.bets table to the supabase_realtime publication.

-- 1. Add table to publication
-- This is required for the client to receive Postgres changes.
alter publication supabase_realtime add table public.bets;

-- note: If the publication doesn't exist (unlikely in Supabase), create it:
-- create publication supabase_realtime for all tables;
