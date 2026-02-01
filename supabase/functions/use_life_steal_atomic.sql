
DECLARE
  v_power_id uuid;
  v_event_id uuid;
  v_target_lives int;
BEGIN
  -- 1. Obtener el ID del poder y el ID del evento
  SELECT id INTO v_power_id FROM public.powers WHERE slug = 'life_steal' LIMIT 1;
  SELECT event_id INTO v_event_id FROM public.game_players WHERE id = p_caster_gp_id;

  -- 2. Verificar que el atacante tenga el poder disponible
  IF NOT EXISTS (
    SELECT 1 FROM public.player_powers 
    WHERE game_player_id = p_caster_gp_id 
    AND power_id = v_power_id 
    AND quantity > 0
  ) THEN
    RETURN FALSE;
  END IF;

  -- 3. Obtener vidas actuales del objetivo
  SELECT lives INTO v_target_lives FROM public.game_players WHERE id = p_target_gp_id;

  -- 4. Validar que el objetivo tenga vida para robar
  IF v_target_lives <= 0 THEN
    RETURN FALSE;
  END IF;

  -- 5. OPERACIÓN ATÓMICA
  -- A. Restar vida al objetivo (mínimo 0)
  UPDATE public.game_players 
  SET lives = lives - 1 
  WHERE id = p_target_gp_id;

  -- B. Sumar vida al atacante (máximo 3)
  UPDATE public.game_players 
  SET lives = LEAST(lives + 1, 3) 
  WHERE id = p_caster_gp_id;

  -- C. Consumir la carga del poder
  UPDATE public.player_powers 
  SET quantity = quantity - 1 
  WHERE game_player_id = p_caster_gp_id AND power_id = v_power_id;

  -- D. Registrar en active_powers para que al rival le salga el banner (SabotageOverlay)
  -- Esto funciona incluso si el rival entra minutos después, verá el efecto si no ha expirado
  INSERT INTO public.active_powers (
    event_id, 
    caster_id, 
    target_id, 
    power_id, 
    expires_at
  ) VALUES (
    v_event_id,
    p_caster_gp_id,
    p_target_gp_id,
    v_power_id,
    now() + interval '10 seconds'
  );

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
