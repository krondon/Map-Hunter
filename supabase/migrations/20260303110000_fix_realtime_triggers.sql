-- =============================================================================
-- FIX: Triggers de Realtime con manejo de errores mejorado
-- Fecha: 2026-03-03
-- Problema: Los triggers AFTER INSERT en active_powers y combat_events
--           solo capturam `undefined_table`. Si realtime.messages existe
--           pero con un esquema diferente (ej: columna 'private' ausente),
--           el INSERT del trigger falla con 'undefined_column', lo que
--           hace rollback del INSERT original (use_power_mechanic, admin, etc).
-- Solución: Cambiar a EXCEPTION WHEN OTHERS para capturar CUALQUIER error
--           del broadcast sin bloquear el flujo principal.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.notify_combat_event_broadcast()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_channel TEXT;
    v_payload JSONB;
BEGIN
    v_channel := 'game:' || NEW.target_id::TEXT;

    v_payload := jsonb_build_object(
        'type', 'broadcast',
        'event', 'combat_event',
        'payload', jsonb_build_object(
            'id', NEW.id,
            'event_id', NEW.event_id,
            'attacker_id', NEW.attacker_id,
            'target_id', NEW.target_id,
            'power_slug', NEW.power_slug,
            'result_type', NEW.result_type,
            'created_at', NEW.created_at
        )
    );

    -- Intentar insertar en realtime.messages para Broadcast de baja latencia.
    -- EXCEPTION WHEN OTHERS captura CUALQUIER error (tabla inexistente,
    -- columna inexistente, permisos, etc.) para no bloquear el INSERT original.
    BEGIN
        INSERT INTO realtime.messages (payload, event, topic, private)
        VALUES (
            v_payload,
            'combat_event',
            v_channel,
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Fallback graceful: Postgres Changes (WAL) tomará el relevo
        -- aunque con mayor latencia (~200-400ms).
        NULL;
    END;

    RETURN NEW;
END;
$$;

-- Recrear trigger
DROP TRIGGER IF EXISTS "trg_combat_event_broadcast" ON "public"."combat_events";
CREATE TRIGGER "trg_combat_event_broadcast"
    AFTER INSERT ON "public"."combat_events"
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_combat_event_broadcast();


CREATE OR REPLACE FUNCTION public.notify_active_power_broadcast()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_channel_target TEXT;
    v_channel_caster TEXT;
    v_payload JSONB;
BEGIN
    v_channel_target := 'game:' || NEW.target_id::TEXT;
    v_channel_caster := 'game:' || NEW.caster_id::TEXT;

    v_payload := jsonb_build_object(
        'id', NEW.id,
        'event_id', NEW.event_id,
        'caster_id', NEW.caster_id,
        'target_id', NEW.target_id,
        'power_slug', NEW.power_slug,
        'expires_at', NEW.expires_at,
        'created_at', NEW.created_at
    );

    -- EXCEPTION WHEN OTHERS: captura cualquier error para no bloquear
    -- el INSERT original en active_powers (use_power_mechanic, admin, etc).
    BEGIN
        INSERT INTO realtime.messages (payload, event, topic, private)
        VALUES (
            jsonb_build_object('type', 'broadcast', 'event', 'power_applied', 'payload', v_payload),
            'power_applied',
            v_channel_target,
            false
        );

        INSERT INTO realtime.messages (payload, event, topic, private)
        VALUES (
            jsonb_build_object('type', 'broadcast', 'event', 'power_applied', 'payload', v_payload),
            'power_applied',
            v_channel_caster,
            false
        );
    EXCEPTION WHEN OTHERS THEN
        -- Fallback silencioso: Postgres Changes toma el relevo
        NULL;
    END;

    RETURN NEW;
END;
$$;

-- Recrear trigger
DROP TRIGGER IF EXISTS "trg_active_power_broadcast" ON "public"."active_powers";
CREATE TRIGGER "trg_active_power_broadcast"
    AFTER INSERT ON "public"."active_powers"
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_active_power_broadcast();

-- Re-aplicar grants
GRANT EXECUTE ON FUNCTION public.notify_combat_event_broadcast() TO "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION public.notify_active_power_broadcast() TO "anon", "authenticated", "service_role";
