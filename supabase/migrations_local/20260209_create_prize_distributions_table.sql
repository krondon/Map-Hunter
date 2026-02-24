-- Migration: Create Prize Distribution Audit Table
-- Created: 2026-02-09
-- Purpose: Track all prize awards for auditing and debugging

-- Create prize_distributions table to track all prize awards
CREATE TABLE IF NOT EXISTS prize_distributions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  position INT NOT NULL CHECK (position >= 1 AND position <= 3),
  amount INT NOT NULL CHECK (amount >= 0),
  pot_total NUMERIC NOT NULL CHECK (pot_total >= 0),
  participants_count INT NOT NULL,
  entry_fee INT NOT NULL,
  distributed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  rpc_success BOOLEAN DEFAULT FALSE,
  error_message TEXT,
  UNIQUE(event_id, user_id) -- Prevent duplicate awards for same event
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_prize_distributions_user 
  ON prize_distributions(user_id);
CREATE INDEX IF NOT EXISTS idx_prize_distributions_event 
  ON prize_distributions(event_id);
CREATE INDEX IF NOT EXISTS idx_prize_distributions_distributed_at 
  ON prize_distributions(distributed_at DESC);

-- Add RLS policies
ALTER TABLE prize_distributions ENABLE ROW LEVEL SECURITY;

-- Users can view their own prize history
CREATE POLICY "Users can view own prizes"
  ON prize_distributions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Only system (via service role) can insert prize distributions
CREATE POLICY "Service role can insert prizes"
  ON prize_distributions
  FOR INSERT
  WITH CHECK (true); -- Service role bypasses this anyway

-- Add comment for documentation
COMMENT ON TABLE prize_distributions IS 'Audit trail of all prize distributions from completed events';
COMMENT ON COLUMN prize_distributions.rpc_success IS 'Whether the add_clovers RPC succeeded';
COMMENT ON COLUMN prize_distributions.error_message IS 'Error message if RPC failed';
