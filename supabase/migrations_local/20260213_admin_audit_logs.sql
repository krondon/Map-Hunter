-- ==============================================================================
-- Migration: Admin Audit Logs System
-- Purpose: Track critical admin actions (events, financial modifications, config)
-- Date: 2026-02-13
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Create Audit Logs Table
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES profiles(id) ON DELETE SET NULL, -- Nullable for system actions
    action_type TEXT NOT NULL, -- e.g., 'INSERT', 'UPDATE', 'DELETE', 'PLAYER_ACCEPTED'
    target_table TEXT NOT NULL, -- e.g., 'events', 'profiles', 'app_config'
    target_id UUID, -- affected record ID
    details JSONB DEFAULT '{}'::jsonb, -- Stores OLD/NEW values or metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 2. RLS Policies
-- ─────────────────────────────────────────────────────────────
-- Policy: Only Admins can VIEW logs
DROP POLICY IF EXISTS "Admins can view audit logs" ON admin_audit_logs;
CREATE POLICY "Admins can view audit logs"
ON admin_audit_logs
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- Policy: System/Admins can INSERT (via Triggers or RPCs)
DROP POLICY IF EXISTS "System can insert audit logs" ON admin_audit_logs;
CREATE POLICY "System can insert audit logs"
ON admin_audit_logs
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: NO ONE can UPDATE or DELETE (Immutable Logs)
-- (No policies created for UPDATE/DELETE implies deny all)

-- ─────────────────────────────────────────────────────────────
-- 3. Indexes for Performance
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin_id ON admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON admin_audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON admin_audit_logs(target_table, target_id);


-- ─────────────────────────────────────────────────────────────
-- 4. Generic Trigger Function for Automatic Logging
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION log_admin_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_id UUID;
    v_details JSONB;
    v_target_id UUID;
    v_target_table TEXT := TG_TABLE_NAME;
    v_action_type TEXT := TG_OP; -- INSERT, UPDATE, DELETE
BEGIN
    -- Attempt to get current user ID (might be null for system tasks)
    v_admin_id := auth.uid();

    -- Construct Details JSON
    IF (TG_OP = 'INSERT') THEN
        v_details := jsonb_build_object('new', row_to_json(NEW));
        v_target_id := NEW.id;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Only log if actual changes happened (optional optimization)
        -- IF NEW IS NOT DISTINCT FROM OLD THEN RETURN NEW; END IF;
        
        v_details := jsonb_build_object(
            'old', row_to_json(OLD), 
            'new', row_to_json(NEW)
        );
        -- Simple diff isn't native without extensions, so we store snapshots
        v_target_id := NEW.id;
    ELSIF (TG_OP = 'DELETE') THEN
        v_details := jsonb_build_object('old', row_to_json(OLD));
        v_target_id := OLD.id;
    END IF;

    -- Insert Log
    INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
    VALUES (v_admin_id, v_action_type, v_target_table, v_target_id, v_details);

    -- Return result for the trigger to proceed
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


-- ─────────────────────────────────────────────────────────────
-- 5. Attach Triggers to Critical Tables
-- ─────────────────────────────────────────────────────────────

-- A. EVENTS Table (Create, Update, Delete)
DROP TRIGGER IF EXISTS log_events_changes ON events;
CREATE TRIGGER log_events_changes
AFTER INSERT OR UPDATE OR DELETE ON events
FOR EACH ROW
EXECUTE FUNCTION log_admin_change();


-- B. APP_CONFIG Table (Changes to global settings)
-- (Only if app_config exists, assuming it does based on analysis)
DROP TRIGGER IF EXISTS log_app_config_changes ON app_config;
CREATE TRIGGER log_app_config_changes
AFTER INSERT OR UPDATE OR DELETE ON app_config
FOR EACH ROW
EXECUTE FUNCTION log_admin_change();


-- C. PROFILES Table (Sensitive changes only: Role, Clovers, Coins)
-- We use a specialized trigger function to filter noise (e.g. daily login updates)
CREATE OR REPLACE FUNCTION log_sensitive_profile_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only log if sensitive fields changed
    IF (NEW.role IS DISTINCT FROM OLD.role) OR
       (NEW.clovers IS DISTINCT FROM OLD.clovers) THEN
       
        INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
        VALUES (
            auth.uid(), 
            'UPDATE_SENSITIVE', 
            'profiles', 
            NEW.id, 
            jsonb_build_object(
                'old_role', OLD.role, 'new_role', NEW.role,
                'old_clovers', OLD.clovers, 'new_clovers', NEW.clovers
            )
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_profile_sensitive_changes ON profiles;
CREATE TRIGGER log_profile_sensitive_changes
AFTER UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION log_sensitive_profile_changes();

-- ─────────────────────────────────────────────────────────────
-- End of Migration
-- ─────────────────────────────────────────────────────────────
