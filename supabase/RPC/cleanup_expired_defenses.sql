-- Function to clean up expired defenses where is_protected is true but no active power exists
CREATE OR REPLACE FUNCTION public.cleanup_expired_defenses()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    fixed_count integer;
BEGIN
    -- Update game_players setting is_protected = false
    -- WHERE is_protected IS TRUE
    -- AND NOT EXISTS in active_powers (for defense types)
    
    WITH updated_rows AS (
        UPDATE public.game_players gp
        SET is_protected = false,
            updated_at = NOW()
        WHERE gp.is_protected = true
        AND NOT EXISTS (
            SELECT 1 
            FROM public.active_powers ap
            WHERE ap.target_id = gp.id
            AND ap.power_slug IN ('invisibility', 'shield', 'return')
            AND ap.expires_at > NOW()
        )
        RETURNING 1
    )
    SELECT count(*) INTO fixed_count FROM updated_rows;

    IF fixed_count > 0 THEN
        RAISE NOTICE 'Cleaned up % expired defense states.', fixed_count;
    END IF;
END;
$$;

-- Schedule the job to run every minute
-- NOTE: Requires pg_cron extension enabled in Supabase
SELECT cron.schedule('cleanup-defenses', '* * * * *', 'SELECT public.cleanup_expired_defenses();');

-- To unschedule:
-- SELECT cron.unschedule('cleanup-defenses');
