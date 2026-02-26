-- ==========================================
-- 1. ESQUEMA PRIVADO PARA SECRETOS
-- ==========================================
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.keys (
    name TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE private.keys ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 2. CONFIGURACIÓN DE LLAVES (DEV)
-- ==========================================
-- REEMPLAZA CON TUS VALORES DE DEV
INSERT INTO private.keys (name, value)
VALUES 
    ('PROJECT_URL', 'https://tu-proyecto-dev.supabase.co'),
    ('SERVICE_ROLE_KEY', 'tu-service-role-key-de-dev-aqui')
ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value;

-- ==========================================
-- 3. FUNCIONES "WRAPPER"
-- ==========================================

CREATE OR REPLACE FUNCTION public.cron_invoke_update_rate()
RETURNS void AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  SELECT value INTO v_url FROM private.keys WHERE name = 'PROJECT_URL';
  SELECT value INTO v_key FROM private.keys WHERE name = 'SERVICE_ROLE_KEY';

  IF v_url IS NOT NULL AND v_key IS NOT NULL THEN
      PERFORM net.http_post(
        url := v_url || '/functions/v1/update-rate',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_key
        ),
        body := '{}'::jsonb
      );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cron_invoke_automate_events()
RETURNS void AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  SELECT value INTO v_url FROM private.keys WHERE name = 'PROJECT_URL';
  SELECT value INTO v_key FROM private.keys WHERE name = 'SERVICE_ROLE_KEY';

  IF v_url IS NOT NULL AND v_key IS NOT NULL THEN
      PERFORM net.http_post(
        url := v_url || '/functions/v1/automate-online-events',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_key
        ),
        body := jsonb_build_object('trigger', 'cron', 'time', now())
      );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- 4. LIMPIEZA Y PROGRAMACIÓN DE CRONJOBS
-- ==========================================
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Limpieza segura usando las funciones oficiales de pg_cron
DO $$
DECLARE
    job_record RECORD;
BEGIN
    -- Buscamos los jobs por nombre y los desprogramamos uno a uno
    FOR job_record IN 
        SELECT jobname FROM cron.job 
        WHERE jobname IN (
            'expire_old_orders', 
            'bcv-daily-rate-update', 
            'update-bcv-rate-job', 
            'cleanup-defenses', 
            'automate-online-events'
        )
    LOOP
        PERFORM cron.unschedule(job_record.jobname);
    END LOOP;
END $$;

-- Programación de tareas
SELECT cron.schedule('expire_old_orders', '*/15 * * * *', 
  $$ UPDATE public.clover_orders SET status = 'expired' WHERE status = 'pending' AND expires_at < NOW(); $$
);

SELECT cron.schedule('bcv-daily-rate-update', '0 4 * * *', 'SELECT public.cron_invoke_update_rate();');
SELECT cron.schedule('update-bcv-rate-job', '0 4 * * *', 'SELECT public.trigger_bcv_update();');
SELECT cron.schedule('cleanup-defenses', '* * * * *', 'SELECT public.cleanup_expired_defenses();');
SELECT cron.schedule('automate-online-events', '0 0 * * *', 'SELECT public.cron_invoke_automate_events();');