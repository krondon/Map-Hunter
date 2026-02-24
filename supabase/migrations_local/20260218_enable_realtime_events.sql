-- Enable Realtime for Events table
-- This allows spectators to see status changes (pending -> active -> completed) instantly.

-- Add to publication
-- Check if table is already in publication to avoid errors (Postgres doesn't support IF NOT EXISTS for this specific command easily in all versions, 
-- but 'ALTER PUBLICATION ... ADD TABLE' is generally safe if not present, or idempotent-ish). 
-- actually, standard way is just to run it. If it fails because it's already there, it's fine, but let's try to be clean.
-- For Supabase/Postgres, we can just run it.

ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
