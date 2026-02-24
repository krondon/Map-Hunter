-- ============================================================
-- Migration: Fix duplicate rows in app_config + restore UNIQUE on key
-- Date:      2026-02-20
--
-- ROOT CAUSE:
--   The app_config table was modified outside of migrations (via Supabase
--   dashboard). The table originally had `key` as its PRIMARY KEY, which
--   allowed upsert() to resolve conflicts automatically.
--   After the dashboard change, the table now has:
--     - `id uuid` as PRIMARY KEY (auto-generated, never sent in payloads)
--     - `key text` with NO unique constraint
--   This means every upsert() call does an INSERT (no conflict to detect),
--   creating duplicate rows per key. .single() then throws 406, which
--   blocks all withdrawals and shows the maintenance banner permanently.
--
-- Fix:
--   1. Delete duplicate rows, keeping only the most-recently updated per key.
--   2. Add UNIQUE constraint on `key` so upsert(onConflict:'key') works
--      correctly with the surrogate `id` PK.
-- ============================================================

-- ── Step 1: Delete duplicates, keep the row with the latest updated_at per key.
DELETE FROM public.app_config
WHERE id NOT IN (
  SELECT DISTINCT ON (key) id
  FROM public.app_config
  ORDER BY key, updated_at DESC NULLS LAST
);

-- ── Step 2: Add UNIQUE constraint on key (idempotent).
ALTER TABLE public.app_config
    DROP CONSTRAINT IF EXISTS app_config_key_key;

ALTER TABLE public.app_config
    ADD CONSTRAINT app_config_key_key UNIQUE (key);
