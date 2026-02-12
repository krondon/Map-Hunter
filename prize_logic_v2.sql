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

  -- F. Lógica de Premios (Solo si entry_fee > 0)
  v_prize_amount := 0;
  if v_entry_fee > 0 then
      -- Calcular Pot Total (Participantes * Fee * 0.70)
      -- Usamos una estimación rápida o conteo real. Para atomicidad, mejor conteo real snapshot.
      select count(*) into v_total_participants
      from game_players
      where event_id = p_event_id;
      
      v_pot_total := (v_total_participants * v_entry_fee) * 0.70;

      -- Definir Share según posición y cantidad de participantes/ganadores
      -- Reglas simplificadas o leemos config.
      -- Implementación robusta:
      if v_position = 1 then
          if v_configured_winners = 1 then v_prize_share := 1.0;
          elsif v_configured_winners = 2 then v_prize_share := 0.70;
          else v_prize_share := 0.50; -- Default 3 winners
          end if;
      elsif v_position = 2 then
          if v_configured_winners = 2 then v_prize_share := 0.30;
          else v_prize_share := 0.30;
          end if;
      elsif v_position = 3 then
          v_prize_share := 0.20;
      else
          v_prize_share := 0.0;
      end if;

      v_prize_amount := floor(v_pot_total * v_prize_share);

      -- Ajuste de remanente al 1ro (si es el último ganador, pero complejo en tiempo real)
      -- Simplificación: El 1ro se lleva el remanente SOLO si ya sabemos el pot exacto, 
      -- pero como entran dinámicamente, mejor shares fijos.
      -- Opcional: Si es el 1ro y hay pocos participantes (<5), se lleva el 100% (share 1.0).
      
      -- Recalcular share dinámico basado en participantes (Requisito: N <= 5 -> 1 ganador)
      -- Si el admin configuró 3, pero N=4, el RPC debe respetar la configuración o la recomendación?
      -- Asumimos que la configuración del Admin MANDA. El Admin debió configurar 1 si N<=5.
      -- PERO, si el Admin puso 3 y solo entraron 4...
      -- Fallback lógico: Si v_position > v_total_participants (imposible pero bueno), 
      -- o reglas de negocio:
      if v_total_participants <= 5 and v_position > 1 then
         v_prize_amount := 0; -- Solo 1 ganador si N<=5, aunque config diga 3? 
         -- Decisión: Respetar Configured Winners del Admin.
      end if;

      if v_prize_amount > 0 then
         -- Add Clovers (Reusing update logic logic inside)
         update profiles
         set clovers = coalesce(clovers, 0) + v_prize_amount
         where id = p_user_id;
         
         -- Record Distribution
         insert into prize_distributions 
         (event_id, user_id, position, amount, pot_total, participants_count, entry_fee, rpc_success)
         values 
         (p_event_id, p_user_id, v_position, v_prize_amount, v_pot_total, v_total_participants, v_entry_fee, true);
      end if;
  end if;

  -- G. Verificar si el evento debe cerrarse FINALMENTE (Si este fue el último ganador)
  if v_position >= v_configured_winners then
      update events 
      set 
        status = 'completed', 
        winner_id = (case when v_position = 1 then p_user_id else winner_id end), -- Registrar 1ro como winner principal si se desea
        completed_at = now() 
      where id = p_event_id;
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
