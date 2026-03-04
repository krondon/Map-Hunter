-- Actualiza version_configuration en app_config:
-- - Reemplaza android_store_url (Play Store) por apk_download_url (descarga directa desde web)
-- - Mantiene maintenance_mode y min_supported_version
UPDATE public.app_config
SET
  value = jsonb_build_object(
    'latest_version',       '1.0.0',
    'min_supported_version','1.0.0',
    'maintenance_mode',     false,
    'apk_download_url',     'https://prueba.maphunter.online/download/MH20260227-0001.apk'
  ),
  updated_at = now()
WHERE key = 'version_configuration';
