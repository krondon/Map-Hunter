-- Migration: Add recharge_enabled config key to app_config
-- Controls whether users can access the recharge/top-up flow.
-- When false, the RECARGAR button shows a maintenance message.

INSERT INTO app_config (key, value, updated_at)
VALUES ('recharge_enabled', 'true'::jsonb, NOW())
ON CONFLICT (key) DO NOTHING;
