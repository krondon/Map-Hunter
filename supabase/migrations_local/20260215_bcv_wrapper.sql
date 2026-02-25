CREATE OR REPLACE FUNCTION public.trigger_bcv_update()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Se ejecuta con permisos de superusuario para leer el Vault
AS $$
DECLARE
  v_url text;
  v_key text;
  v_req_id bigint;
BEGIN
  -- 1. Recuperar URL y Key desde el Vault
  SELECT decrypted_secret INTO v_url 
  FROM vault.decrypted_secrets 
  WHERE name = 'bcv_func_url';

  SELECT decrypted_secret INTO v_key 
  FROM vault.decrypted_secrets 
  WHERE name = 'bcv_service_key';

  -- Validación simple
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE EXCEPTION 'Credenciales para BCV no encontradas en Vault';
  END IF;

  -- 2. Hacer la petición usando pg_net
  -- Nota: net.http_post devuelve un ID, lo capturamos en v_req_id aunque no lo usemos
  SELECT net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := '{}'::jsonb
  ) INTO v_req_id;
  
END;
$$;