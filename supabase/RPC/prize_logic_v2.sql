-- AL MIGRAR: Ejecutar este script en el SQL Editor de Supabase
-- 1. Actualización de Schema
alter table events 
add column if not exists configured_winners integer default 3;

-- 2. Función RPC Atómica para Registrar Finalistas y Premiar
create or replace function register_race_finisher(
  p_event_id uuid,
  p_user_id uuid
)
returns json
language plpgsql
security definer
as $$
declare
  v_event_status text;
  v_configured_winners int;
  v_entry_fee int;
  v_total_participants int;
  v_pot_total numeric;
  v_winners_count int;
  v_user_status text;
  v_is_already_finisher boolean;
  v_position int;
  v_prize_amount int;
  v_prize_share numeric;
  v_result json;
begin
  -- A. Validaciones Iniciales (Bloqueo Row-Level para el Evento)
  select status, configured_winners, entry_fee
  into v_event_status, v_configured_winners, v_entry_fee
  from events
  where id = p_event_id
  for update; -- LOCK para evitar condiciones de carrera en cierre de evento

  if not found then
    return json_build_object('success', false, 'message', 'Evento no encontrado');
  end if;

  if v_event_status = 'completed' then
     return json_build_object('success', false, 'message', 'El evento ya ha finalizado', 'race_completed', true);
  end if;

  -- B. Validar Estado del Usuario
  select status into v_user_status
  from game_players
  where event_id = p_event_id and user_id = p_user_id;

  if v_user_status = 'completed' then
     return json_build_object('success', false, 'message', 'Ya has completado esta carrera');
  end if;

  if v_user_status != 'active' then
     return json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  end if;

  -- C. Contar ganadores actuales (con bloqueo para consistencia)
  select count(*) into v_winners_count
  from game_players
  where event_id = p_event_id and status = 'completed';

  -- Si ya hay suficientes ganadores (aunque el evento no esté 'completed' por latencia), rechazar
  if v_winners_count >= v_configured_winners then
     -- Auto-cerrar si no lo estaba
     update events set status = 'completed', completed_at = now() where id = p_event_id;
     return json_build_object('success', false, 'message', 'Podio completo', 'race_completed', true);
  end if;

  -- D. Calcular Posición
  v_position := v_winners_count + 1;

  -- E. Registrar Finalización (Update game_players)
  update game_players
  set 
    status = 'completed',
    finish_time = now(),
    completed_clues_count = (select count(*) from clues where event_id = p_event_id) -- Asegurar max clues
  where event_id = p_event_id and user_id = p_user_id;

  -- F. Lógica de Premios: ELIMINADA para evitar conflictos.
  -- La distribución de premios se realizará mediante el RPC 'distribute_event_prizes' 
  -- invocado manualmente por el administrador para asegurar el cálculo correcto del Bote (70%)
  -- y la cantidad de ganadores configurada.
  
  /* 
  LOGIC MOVED TO: distribute_event_prizes
  Prizes are no longer distributed here to preventing "shrinking pot" issues 
  and ensure atomic distribution of the correct % based on total participants.
  */

  -- G. Verificar si el evento debe cerrarse FINALMENTE (Si este fue el último ganador)
  if v_position >= v_configured_winners then
      update events 
      set 
        status = 'completed', 
        winner_id = (case when v_position = 1 then p_user_id else winner_id end), -- Registrar 1ro como winner principal si se desea
        completed_at = now() 
      where id = p_event_id;

      -- AUTO-DISTRIBUTE PRIZES
      perform distribute_event_prizes(p_event_id);
  end if;

  return json_build_object(
    'success', true, 
    'position', v_position, 
    'prize', v_prize_amount,
    'race_completed', (v_position >= v_configured_winners)
  );

exception when others then
  return json_build_object('success', false, 'message', SQLERRM);
end;
$$;
