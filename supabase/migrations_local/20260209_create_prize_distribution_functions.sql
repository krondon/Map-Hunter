-- Migration: Add Prize Distribution Functions
-- Created: 2026-02-09
-- Purpose: Deploy add_clovers and get_event_participants_count RPCs for prize distribution

-- FUNCTION 1: Get Safe Participant Count (Bypasses RLS for accurate Pot calculation)
create or replace function get_event_participants_count(target_event_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  total_count integer;
begin
  select count(*) into total_count
  from game_players
  where event_id = target_event_id
  and status in ('active', 'completed', 'banned', 'suspended', 'eliminated');
  
  return total_count;
end;
$$;

-- FUNCTION 2: Add Clovers Safely (Bypasses RLS to update wallet)
create or replace function add_clovers(target_user_id uuid, amount integer)
returns void
language plpgsql
security definer
as $$
begin
  update profiles
  set clovers = coalesce(clovers, 0) + amount
  where id = target_user_id;
end;
$$;
