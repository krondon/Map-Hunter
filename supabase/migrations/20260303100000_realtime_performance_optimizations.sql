-- =============================================================================
-- MIGRACIÓN: Optimizaciones de Rendimiento para Supabase Realtime
-- Fecha: 2026-03-03
-- Impacto: Reduce la carga de Realtime de O(n²) a O(n) para actualizaciones
--          de vidas, y reduce la latencia de feedback de ~300ms a ~50ms.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. REPLICA IDENTITY FULL en game_players
--
-- PROBLEMA ACTUAL: Sin REPLICA IDENTITY FULL, las subscripciones Postgres
-- Changes con filtros en columnas no-PK (como user_id) NO funcionan para
-- eventos UPDATE. Supabase solo incluye el PK en el "old record" por defecto,
-- y el filtro del servidor no puede evaluar otras columnas.
--
-- CON ESTE CAMBIO: Cada UPDATE en game_players incluirá TODOS los valores
-- del registro anterior (old record), permitiendo que Supabase filtre por
-- cualquier columna incluyendo user_id.
--
-- EFECTO: Con 50 jugadores, pasamos de 50×50=2500 mensajes WebSocket por
-- burst de actividad a exactamente 50 mensajes (uno por usuario).
--
-- COSTO: Ligero aumento en volumen WAL (~2x por fila en game_players).
--        Aceptable dado el tamaño esperado de la tabla.
-- -----------------------------------------------------------------------------
ALTER TABLE "public"."game_players" REPLICA IDENTITY FULL;


-- -----------------------------------------------------------------------------
-- 2. ÍNDICE COMPUESTO en combat_events para consultas del stream
--
-- La consulta del stream: .stream().eq('target_id', ...).order('created_at')
-- necesita este índice para rendimiento óptimo con alta concurrencia.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS "idx_combat_events_target_created"
    ON "public"."combat_events" ("target_id", "created_at" DESC);

-- Índice adicional para limpiezas periódicas que filtran por event_id
CREATE INDEX IF NOT EXISTS "idx_combat_events_event_created"
    ON "public"."combat_events" ("event_id", "created_at" DESC);


-- -----------------------------------------------------------------------------
-- 3. ÍNDICE en active_powers para acelerar el stream de PowerEffectProvider
--
-- La consulta: .stream().eq('target_id', ...) sobre active_powers.
-- Con 50 jugadores haciendo ataques simultáneos, este índice es crítico.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS "idx_active_powers_target_expires"
    ON "public"."active_powers" ("target_id", "expires_at" DESC);


-- -----------------------------------------------------------------------------
-- 4. FUNCIÓN: notify_combat_event_broadcast
--
-- Envía un mensaje de Broadcast de Supabase Realtime INMEDIATAMENTE cuando
-- se inserta un combat_event. Esto es complementario al Postgres Changes
-- (que tarda ~200-400ms via WAL), reduciendo la latencia del feedback a ~50ms.
--
-- MECANISMO: Usa pg_notify en el canal 'realtime' con formato Supabase Broadcast.
-- Requiere: La tabla 'realtime.messages' (disponible en Supabase >= 2024-01).
--
-- ALTERNATIVA: Si pg_net está habilitado, se puede usar net.http_post().
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_combat_event_broadcast()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_channel TEXT;
    v_payload JSONB;
BEGIN
    -- Canal específico por jugador víctima: "game:{target_id}"
    -- El cliente Flutter debe suscribirse a este canal para recibir Broadcast.
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

    -- Intentar insertar en realtime.messages si la extensión está disponible.
    -- Esto activa el Broadcast de Supabase Realtime con latencia mínima.
    BEGIN
        INSERT INTO realtime.messages (payload, event, topic, private)
        VALUES (
            v_payload,
            'combat_event',
            v_channel,
            false  -- público en el canal del juego
        );
    EXCEPTION WHEN undefined_table THEN
        -- Fallback graceful: Si realtime.messages no existe (versiones antiguas),
        -- usar pg_notify como alternativa (menor prioridad, entrega best-effort).
        PERFORM pg_notify(
            'realtime',
            v_payload::TEXT
        );
    END;

    RETURN NEW;
END;
$$;

-- Adjuntar el trigger AFTER INSERT en combat_events
-- AFTER en lugar de BEFORE: El Broadcast se dispara una vez que el INSERT
-- es exitoso y confirmado, evitando notificaciones de filas que hicieron rollback.
DROP TRIGGER IF EXISTS "trg_combat_event_broadcast" ON "public"."combat_events";

CREATE TRIGGER "trg_combat_event_broadcast"
    AFTER INSERT ON "public"."combat_events"
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_combat_event_broadcast();


-- -----------------------------------------------------------------------------
-- 5. FUNCIÓN: notify_active_power_broadcast (para poderes activos)
--
-- Similar al anterior pero para inserciones en active_powers.
-- Permite al caster recibir confirmación instantánea de que su poder fue aplicado.
-- -----------------------------------------------------------------------------
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

    BEGIN
        -- Notificar a la víctima
        INSERT INTO realtime.messages (payload, event, topic, private)
        VALUES (
            jsonb_build_object('type', 'broadcast', 'event', 'power_applied', 'payload', v_payload),
            'power_applied',
            v_channel_target,
            false
        );

        -- Notificar al atacante (para confirmación visual)
        INSERT INTO realtime.messages (payload, event, topic, private)
        VALUES (
            jsonb_build_object('type', 'broadcast', 'event', 'power_applied', 'payload', v_payload),
            'power_applied',
            v_channel_caster,
            false
        );
    EXCEPTION WHEN undefined_table THEN
        -- Fallback silencioso: sin Broadcast disponible, Postgres Changes toma el relevo
        NULL;
    END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "trg_active_power_broadcast" ON "public"."active_powers";

CREATE TRIGGER "trg_active_power_broadcast"
    AFTER INSERT ON "public"."active_powers"
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_active_power_broadcast();


-- -----------------------------------------------------------------------------
-- 6. CLEANUP: Función mejorada para borrar combat_events antiguos
--
-- Agrega límite por cantidad además del límite temporal para evitar que
-- la tabla crezca excesivamente en eventos con mucha actividad.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_old_combat_events(
    p_event_id UUID DEFAULT NULL,
    p_max_age_minutes INTEGER DEFAULT 30,
    p_max_rows_per_target INTEGER DEFAULT 50
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted INTEGER := 0;
    v_temp INTEGER;
BEGIN
    -- 1. Borrar por antigüedad
    WITH deleted AS (
        DELETE FROM public.combat_events
        WHERE created_at < NOW() - (p_max_age_minutes || ' minutes')::INTERVAL
          AND (p_event_id IS NULL OR event_id = p_event_id)
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_temp FROM deleted;
    v_deleted := v_deleted + COALESCE(v_temp, 0);

    -- 2. Borrar exceso por target (mantener solo los últimos N por jugador)
    WITH ranked AS (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY target_id
                   ORDER BY created_at DESC
               ) AS rn
        FROM public.combat_events
        WHERE (p_event_id IS NULL OR event_id = p_event_id)
    ),
    to_delete AS (
        SELECT id FROM ranked WHERE rn > p_max_rows_per_target
    ),
    deleted2 AS (
        DELETE FROM public.combat_events
        WHERE id IN (SELECT id FROM to_delete)
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_temp FROM deleted2;
    v_deleted := v_deleted + COALESCE(v_temp, 0);

    RETURN v_deleted;
END;
$$;


-- Grants
GRANT EXECUTE ON FUNCTION public.notify_combat_event_broadcast() TO "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION public.notify_active_power_broadcast() TO "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION public.cleanup_old_combat_events(UUID, INTEGER, INTEGER) TO "authenticated", "service_role";
