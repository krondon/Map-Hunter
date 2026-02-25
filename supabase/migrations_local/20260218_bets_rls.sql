-- Migration: Enable RLS and Policies for Bets
-- Description: Enables RLS on public.bets and adds policies for reading pot and user bets.

-- 1. Enable RLS
ALTER TABLE public.bets ENABLE ROW LEVEL SECURITY;

-- 2. Policy: Anyone can read bets (needed for Pot calculation)
-- Ideally, we only want to expose the 'amount' and 'event_id' to everyone, 
-- but RLS is row-based. For the pot, we need to sum all amounts for an event.
-- We can allow reading all rows where event_id is visible? 
-- Or just allow public read access to bets.
CREATE POLICY "Public can view all bets"
ON public.bets
FOR SELECT
TO authenticated, anon
USING (true);

-- 3. Policy: Authenticated users can create their own bets (via RPC usually, but good to have)
-- Actually, bets are created via RPC 'place_bets_batch' which is SECURITY DEFINER, so this might not be strictly needed for creation if RPC handles it.
-- But if we used direct insert, we would need:
-- CREATE POLICY "Users can create their own bets"
-- ON public.bets
-- FOR INSERT
-- TO authenticated
-- WITH CHECK (auth.uid() = user_id);

-- 4. Policy: Users can see their own bets (already covered by public read, but specificity helps if we restrict public later)
-- For now, "Public can view all bets" covers both "Pot" (all bets) and "My Bets" (subset).

-- Note: The 'place_bets_batch' RPC should insert successfully regardless of RLS if it's SECURITY DEFINER.
-- However, the 'fetchUserBets' and 'getEventBettingPot' calls in Flutter use the JS client which respects RLS.
-- So 'Public can view all bets' is essential for 'getEventBettingPot'.
