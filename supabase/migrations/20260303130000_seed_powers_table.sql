-- =============================================================================
-- MIGRACIÓN: Seed de la tabla `powers`
-- Fecha: 2026-03-03
-- Problema: La tabla `powers` quedó vacía después de que se eliminaron las
--           migraciones individuales (commit 9cfba "DELETE migrations") y se
--           reemplazaron por el schema_main.sql, el cual solo contiene DDL
--           (estructura) pero NO datos (INSERT/COPY).
--           Esto causa "Power not found: <slug>" en los RPCs buy_item,
--           use_power_mechanic, admin_force_apply_power, etc.
-- Solución: Insertar todos los poderes con ON CONFLICT DO UPDATE para que
--           sea idempotente (no falla si ya existen).
-- =============================================================================

INSERT INTO public.powers (id, slug, name, description, power_type, cost, duration, cooldown, icon, is_active)
VALUES
  -- ── ATAQUES ──────────────────────────────────────────────────────────────
  (
    extensions.uuid_generate_v4(),
    'freeze',
    'Congelar',
    'Congela al rival por 30 segundos impidiendo cualquier acción.',
    'freeze',
    120,
    30,
    60,
    '❄️',
    true
  ),
  (
    extensions.uuid_generate_v4(),
    'black_screen',
    'Pantalla Negra',
    'Oscurece completamente la pantalla del rival por 25 segundos.',
    'blind',
    75,
    25,
    60,
    '🕶️',
    true
  ),
  (
    extensions.uuid_generate_v4(),
    'blur_screen',
    'Pantalla Borrosa',
    'Aplica un efecto borroso en la pantalla de TODOS los rivales simultáneamente.',
    'blur',
    75,
    20,
    120,
    '🌫️',
    true
  ),
  (
    extensions.uuid_generate_v4(),
    'life_steal',
    'Robo de Vida',
    'Roba una vida a un rival y te la transfiere a ti.',
    'life_steal',
    120,
    1,
    120,
    '🧛',
    true
  ),
  -- ── DEFENSAS ─────────────────────────────────────────────────────────────
  (
    extensions.uuid_generate_v4(),
    'shield',
    'Escudo',
    'Bloquea el próximo sabotaje que recibas (dura 120 segundos o hasta ser activado).',
    'shield',
    40,
    120,
    60,
    '🛡️',
    true
  ),
  (
    extensions.uuid_generate_v4(),
    'return',
    'Devolución',
    'Devuelve el próximo ataque al atacante en lugar de recibirlo.',
    'return',
    90,
    120,
    60,
    '↩️',
    true
  ),
  (
    extensions.uuid_generate_v4(),
    'invisibility',
    'Invisibilidad',
    'Te vuelve invisible en el ranking por 45 segundos.',
    'stealth',
    40,
    45,
    60,
    '👻',
    true
  )
ON CONFLICT (slug) DO UPDATE SET
  name        = EXCLUDED.name,
  description = EXCLUDED.description,
  power_type  = EXCLUDED.power_type,
  cost        = EXCLUDED.cost,
  duration    = EXCLUDED.duration,
  cooldown    = EXCLUDED.cooldown,
  icon        = EXCLUDED.icon,
  is_active   = EXCLUDED.is_active;
