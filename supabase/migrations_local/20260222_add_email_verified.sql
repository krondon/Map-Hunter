-- Add email_verified column to profiles table
-- Existing users default to true (they were verified during registration)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT true;

-- Update RLS: users can read their own email_verified status
-- (This is already covered by existing RLS policies on profiles)
