-- =============================================================
-- Migration: Security hardening for clues and admin_audit_logs
-- Date: 2026-02-22
-- =============================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. admin_audit_logs: Remove open INSERT policy (log poisoning)
--    All INSERTs happen in SECURITY DEFINER functions (toggle_ban,
--    delete_user, approve_and_pay_event_entry) which bypass RLS.
-- ═══════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "System can insert audit logs" ON admin_audit_logs;

-- ═══════════════════════════════════════════════════════════════
-- 2. clues: Restrict direct SELECT to admin-only.
--    Regular players get clues via the game-play Edge Function
--    (SECURITY DEFINER / service_role), NOT via direct PostgREST.
--    Admin panel needs full access for clue editing.
-- ═══════════════════════════════════════════════════════════════

-- Remove the two permissive public SELECT policies
DROP POLICY IF EXISTS "Clues are visible to everyone" ON clues;
DROP POLICY IF EXISTS "Read access for clues" ON clues;

-- The remaining policy "Solo admins gestionan pistas" already covers
-- admin full access (ALL operation with admin check).
-- No need to create new policies — admin has full CRUD via that policy,
-- and players get clues through the edge function.
