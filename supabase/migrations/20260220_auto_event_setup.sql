-- =============================================================
-- Migration: Consolidate Online Event Automation Config
-- Created: 2026-02-20
-- =============================================================

-- 1. Asegurar que 'key' sea la Primary Key
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_config_pkey') THEN
        BEGIN
            ALTER TABLE public.app_config ADD CONSTRAINT app_config_pkey PRIMARY KEY (key);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;
END $$;

-- 2. Consolidar registros actuales en una sola fila 'online_automation_config'
DO $$
DECLARE
    v_config JSONB;
BEGIN
    -- Intentamos construir el objeto desde las filas viejas si existen
    SELECT jsonb_object_agg(key, value) INTO v_config
    FROM public.app_config
    WHERE key LIKE 'auto_event_%';

    -- Si no hay nada previo, usamos valores por defecto
    IF v_config IS NULL OR v_config = '{}'::jsonb THEN
        v_config := '{
            "enabled": false,
            "interval_minutes": 30,
            "min_players": 10,
            "max_players": 30,
            "min_games": 4,
            "max_games": 10,
            "min_fee": 0,
            "max_fee": 100,
            "fee_step": 5
        }'::jsonb;
    END IF;

    -- Insertar o actualizar la fila única
    INSERT INTO public.app_config (key, value, updated_at)
    VALUES ('online_automation_config', v_config, now())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

    -- Limpiar las filas viejas (opcional, pero recomendado para orden)
    DELETE FROM public.app_config WHERE key LIKE 'auto_event_%';
END $$;

-- 3. Función de lectura (Supabase-First)
CREATE OR REPLACE FUNCTION get_auto_event_settings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT value INTO v_result
  FROM public.app_config
  WHERE key = 'online_automation_config';
  
  RETURN coalesce(v_result, '{}'::jsonb);
END;
$$;

-- 4. Función de actualización robusta
CREATE OR REPLACE FUNCTION update_auto_event_settings(p_settings JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validar admin
  IF NOT (
    (auth.jwt() ->> 'role' = 'service_role') OR 
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  ) THEN
    RAISE EXCEPTION 'Solo administradores pueden cambiar la configuración';
  END IF;

  INSERT INTO public.app_config (key, value, updated_at, updated_by)
  VALUES ('online_automation_config', p_settings, now(), auth.uid())
  ON CONFLICT (key) DO UPDATE 
  SET value = EXCLUDED.value, updated_at = now(), updated_by = EXCLUDED.updated_by;
END;
$$;
