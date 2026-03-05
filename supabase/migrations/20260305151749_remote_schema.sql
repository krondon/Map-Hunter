drop extension if exists "pg_net";

create extension if not exists "pg_net" with schema "public";

drop trigger if exists "trg_active_power_broadcast" on "public"."active_powers";

drop trigger if exists "trg_combat_event_broadcast" on "public"."combat_events";

drop trigger if exists "tr_reset_status_after_invisibility" on "public"."active_powers";

drop trigger if exists "tr_on_clover_order_paid" on "public"."clover_orders";

drop trigger if exists "trg_sync_plan_id_to_ledger" on "public"."clover_orders";

drop trigger if exists "update_clover_orders_updated_at" on "public"."clover_orders";

drop trigger if exists "log_events_changes" on "public"."events";

drop trigger if exists "on_event_delete" on "public"."events";

drop trigger if exists "trg_check_online_event_room_full" on "public"."game_players";

drop trigger if exists "update_payment_transactions_updated_at" on "public"."payment_transactions";

drop trigger if exists "log_profile_sensitive_changes" on "public"."profiles";

drop policy "Players can activate powers" on "public"."active_powers";

drop policy "Admins can view audit logs" on "public"."admin_audit_logs";

drop policy "Admin Write" on "public"."app_config";

drop policy "app_config_admin_write" on "public"."app_config";

drop policy "Admins can view all bets" on "public"."bets";

drop policy "staff_deny_delete_clover_orders" on "public"."clover_orders";

drop policy "staff_deny_insert_clover_orders" on "public"."clover_orders";

drop policy "staff_deny_update_clover_orders" on "public"."clover_orders";

drop policy "Solo admins gestionan pistas" on "public"."clues";

drop policy "Players can view their own combat events" on "public"."combat_events";

drop policy "Admins and staff can create events" on "public"."events";

drop policy "Admins and staff can delete events" on "public"."events";

drop policy "Admins and staff can update events" on "public"."events";

drop policy "Solo administradores pueden gestionar eventos" on "public"."events";

drop policy "exchange_rate_history_admin_select" on "public"."exchange_rate_history";

drop policy "Enable read access for event participants" on "public"."game_players";

drop policy "Solo admins pueden actualizar game_players" on "public"."game_players";

drop policy "Solo admins actualizan solicitudes" on "public"."game_requests";

drop policy "Users can view own requests" on "public"."game_requests";

drop policy "Enable delete for admins" on "public"."mall_stores";

drop policy "Enable insert for admins" on "public"."mall_stores";

drop policy "Enable update for admins" on "public"."mall_stores";

drop policy "Enable read access for own powers" on "public"."player_powers";

drop policy "Enable update for own powers" on "public"."player_powers";

drop policy "Players can add powers" on "public"."player_powers";

drop policy "Admins can manage powers" on "public"."powers";

drop policy "Users read own profile or public info" on "public"."profiles";

drop policy "Admins can manage sponsors" on "public"."sponsors";

drop policy "Admin full access" on "public"."transaction_plans";

drop policy "staff_deny_delete_transaction_plans" on "public"."transaction_plans";

drop policy "staff_deny_insert_transaction_plans" on "public"."transaction_plans";

drop policy "staff_deny_update_transaction_plans" on "public"."transaction_plans";

drop policy "Players can create own transactions" on "public"."transactions";

drop policy "Players can view own transactions" on "public"."transactions";

drop policy "staff_deny_delete_payment_methods" on "public"."user_payment_methods";

drop policy "staff_deny_insert_payment_methods" on "public"."user_payment_methods";

drop policy "staff_deny_update_payment_methods" on "public"."user_payment_methods";

drop policy "staff_deny_delete_wallet_ledger" on "public"."wallet_ledger";

drop policy "staff_deny_insert_wallet_ledger" on "public"."wallet_ledger";

drop policy "staff_deny_update_wallet_ledger" on "public"."wallet_ledger";

alter table "public"."active_powers" drop constraint "active_powers_caster_id_fkey";

alter table "public"."active_powers" drop constraint "active_powers_event_id_fkey";

alter table "public"."active_powers" drop constraint "active_powers_power_id_fkey";

alter table "public"."active_powers" drop constraint "active_powers_slug_fkey";

alter table "public"."active_powers" drop constraint "active_powers_target_id_fkey";

alter table "public"."admin_audit_logs" drop constraint "admin_audit_logs_admin_id_fkey";

alter table "public"."bets" drop constraint "bets_event_id_fkey";

alter table "public"."bets" drop constraint "bets_racer_id_fkey";

alter table "public"."bets" drop constraint "bets_user_id_fkey";

alter table "public"."clover_orders" drop constraint "clover_orders_user_id_fkey";

alter table "public"."clues" drop constraint "clues_event_id_fkey";

alter table "public"."combat_events" drop constraint "combat_events_attacker_id_fkey";

alter table "public"."combat_events" drop constraint "combat_events_event_id_fkey";

alter table "public"."combat_events" drop constraint "combat_events_target_id_fkey";

alter table "public"."events" drop constraint "events_sponsor_id_fkey";

alter table "public"."events" drop constraint "events_winner_id_fkey";

alter table "public"."game_players" drop constraint "game_players_event_id_fkey";

alter table "public"."game_players" drop constraint "game_players_user_id_fkey";

alter table "public"."game_requests" drop constraint "game_requests_event_id_fkey";

alter table "public"."game_requests" drop constraint "game_requests_user_id_fkey";

alter table "public"."mall_stores" drop constraint "mall_stores_event_id_fkey";

alter table "public"."player_powers" drop constraint "player_powers_game_player_id_fkey";

alter table "public"."player_powers" drop constraint "player_powers_power_id_fkey";

alter table "public"."prize_distributions" drop constraint "prize_distributions_event_id_fkey";

alter table "public"."prize_distributions" drop constraint "prize_distributions_user_id_fkey";

alter table "public"."transactions" drop constraint "transactions_game_player_id_fkey";

alter table "public"."user_clue_progress" drop constraint "user_clue_progress_clue_id_fkey";

alter table "public"."user_clue_progress" drop constraint "user_clue_progress_user_id_fkey";

alter table "public"."user_inventory" drop constraint "user_inventory_user_id_fkey";

alter table "public"."user_payment_methods" drop constraint "user_payment_methods_user_id_fkey";

alter table "public"."wallet_ledger" drop constraint "wallet_ledger_order_id_fkey";

alter table "public"."wallet_ledger" drop constraint "wallet_ledger_user_id_fkey";

drop function if exists "public"."admin_force_apply_power"(p_event_id uuid, p_target_userid uuid, p_power_slug text);

drop function if exists "public"."cleanup_old_combat_events"(p_event_id uuid, p_max_age_minutes integer, p_max_rows_per_target integer);

drop function if exists "public"."notify_active_power_broadcast"();

drop function if exists "public"."notify_combat_event_broadcast"();

drop index if exists "public"."idx_active_powers_target_expires";

drop index if exists "public"."idx_combat_events_event_created";

drop index if exists "public"."idx_combat_events_target_created";

alter table "public"."active_powers" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."combat_events" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."events" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."game_players" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."game_requests" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."minigame_capitals" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."minigame_true_false" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."player_powers" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."powers" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."prize_distributions" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."transactions" alter column "id" set default extensions.uuid_generate_v4();

alter table "public"."active_powers" add constraint "active_powers_caster_id_fkey" FOREIGN KEY (caster_id) REFERENCES public.game_players(id) ON DELETE CASCADE not valid;

alter table "public"."active_powers" validate constraint "active_powers_caster_id_fkey";

alter table "public"."active_powers" add constraint "active_powers_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."active_powers" validate constraint "active_powers_event_id_fkey";

alter table "public"."active_powers" add constraint "active_powers_power_id_fkey" FOREIGN KEY (power_id) REFERENCES public.powers(id) ON DELETE CASCADE not valid;

alter table "public"."active_powers" validate constraint "active_powers_power_id_fkey";

alter table "public"."active_powers" add constraint "active_powers_slug_fkey" FOREIGN KEY (power_slug) REFERENCES public.powers(slug) not valid;

alter table "public"."active_powers" validate constraint "active_powers_slug_fkey";

alter table "public"."active_powers" add constraint "active_powers_target_id_fkey" FOREIGN KEY (target_id) REFERENCES public.game_players(id) ON DELETE CASCADE not valid;

alter table "public"."active_powers" validate constraint "active_powers_target_id_fkey";

alter table "public"."admin_audit_logs" add constraint "admin_audit_logs_admin_id_fkey" FOREIGN KEY (admin_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."admin_audit_logs" validate constraint "admin_audit_logs_admin_id_fkey";

alter table "public"."bets" add constraint "bets_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."bets" validate constraint "bets_event_id_fkey";

alter table "public"."bets" add constraint "bets_racer_id_fkey" FOREIGN KEY (racer_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."bets" validate constraint "bets_racer_id_fkey";

alter table "public"."bets" add constraint "bets_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."bets" validate constraint "bets_user_id_fkey";

alter table "public"."clover_orders" add constraint "clover_orders_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."clover_orders" validate constraint "clover_orders_user_id_fkey";

alter table "public"."clues" add constraint "clues_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."clues" validate constraint "clues_event_id_fkey";

alter table "public"."combat_events" add constraint "combat_events_attacker_id_fkey" FOREIGN KEY (attacker_id) REFERENCES public.game_players(id) ON DELETE CASCADE not valid;

alter table "public"."combat_events" validate constraint "combat_events_attacker_id_fkey";

alter table "public"."combat_events" add constraint "combat_events_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."combat_events" validate constraint "combat_events_event_id_fkey";

alter table "public"."combat_events" add constraint "combat_events_target_id_fkey" FOREIGN KEY (target_id) REFERENCES public.game_players(id) ON DELETE CASCADE not valid;

alter table "public"."combat_events" validate constraint "combat_events_target_id_fkey";

alter table "public"."events" add constraint "events_sponsor_id_fkey" FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id) ON DELETE SET NULL not valid;

alter table "public"."events" validate constraint "events_sponsor_id_fkey";

alter table "public"."events" add constraint "events_winner_id_fkey" FOREIGN KEY (winner_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."events" validate constraint "events_winner_id_fkey";

alter table "public"."game_players" add constraint "game_players_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."game_players" validate constraint "game_players_event_id_fkey";

alter table "public"."game_players" add constraint "game_players_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."game_players" validate constraint "game_players_user_id_fkey";

alter table "public"."game_requests" add constraint "game_requests_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."game_requests" validate constraint "game_requests_event_id_fkey";

alter table "public"."game_requests" add constraint "game_requests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."game_requests" validate constraint "game_requests_user_id_fkey";

alter table "public"."mall_stores" add constraint "mall_stores_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."mall_stores" validate constraint "mall_stores_event_id_fkey";

alter table "public"."player_powers" add constraint "player_powers_game_player_id_fkey" FOREIGN KEY (game_player_id) REFERENCES public.game_players(id) ON DELETE CASCADE not valid;

alter table "public"."player_powers" validate constraint "player_powers_game_player_id_fkey";

alter table "public"."player_powers" add constraint "player_powers_power_id_fkey" FOREIGN KEY (power_id) REFERENCES public.powers(id) ON DELETE CASCADE not valid;

alter table "public"."player_powers" validate constraint "player_powers_power_id_fkey";

alter table "public"."prize_distributions" add constraint "prize_distributions_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE not valid;

alter table "public"."prize_distributions" validate constraint "prize_distributions_event_id_fkey";

alter table "public"."prize_distributions" add constraint "prize_distributions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."prize_distributions" validate constraint "prize_distributions_user_id_fkey";

alter table "public"."transactions" add constraint "transactions_game_player_id_fkey" FOREIGN KEY (game_player_id) REFERENCES public.game_players(id) ON DELETE CASCADE not valid;

alter table "public"."transactions" validate constraint "transactions_game_player_id_fkey";

alter table "public"."user_clue_progress" add constraint "user_clue_progress_clue_id_fkey" FOREIGN KEY (clue_id) REFERENCES public.clues(id) ON DELETE CASCADE not valid;

alter table "public"."user_clue_progress" validate constraint "user_clue_progress_clue_id_fkey";

alter table "public"."user_clue_progress" add constraint "user_clue_progress_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."user_clue_progress" validate constraint "user_clue_progress_user_id_fkey";

alter table "public"."user_inventory" add constraint "user_inventory_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."user_inventory" validate constraint "user_inventory_user_id_fkey";

alter table "public"."user_payment_methods" add constraint "user_payment_methods_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."user_payment_methods" validate constraint "user_payment_methods_user_id_fkey";

alter table "public"."wallet_ledger" add constraint "wallet_ledger_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.clover_orders(id) not valid;

alter table "public"."wallet_ledger" validate constraint "wallet_ledger_order_id_fkey";

alter table "public"."wallet_ledger" add constraint "wallet_ledger_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."wallet_ledger" validate constraint "wallet_ledger_user_id_fkey";

set check_function_bodies = off;

create or replace view "public"."active_events_view" as  SELECT id,
    title,
    description,
    date,
    image_url,
    clue,
    max_participants,
    created_by_admin_id,
    created_at,
    pin,
    latitude,
    longitude,
    location_name,
    winner_id,
    completed_at,
    is_completed,
    status,
    type,
    entry_type,
    entry_fee,
        CASE
            WHEN ((status = 'pending'::text) AND (date <= now())) THEN 'active'::text
            ELSE status
        END AS current_status
   FROM public.events;


CREATE OR REPLACE FUNCTION public.add_clovers(target_user_id uuid, amount integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  update profiles
  set clovers = coalesce(clovers, 0) + amount
  where id = target_user_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_credit_clovers(p_user_id uuid, p_amount integer, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Admin only'; END IF;
  UPDATE profiles SET clovers = COALESCE(clovers,0) + p_amount WHERE id = p_user_id;
  INSERT INTO wallet_ledger (user_id, amount, description, metadata)
  VALUES (p_user_id, p_amount, p_reason,
    jsonb_build_object('type','admin_credit','admin_id',auth.uid()::text));
END; $function$
;

CREATE OR REPLACE FUNCTION public.approve_and_pay_event_entry(p_request_id uuid, p_admin_id uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$DECLARE
  v_user_id UUID;
  v_event_id UUID;
  v_entry_fee BIGINT;
  v_request_status TEXT;
  v_payment_result JSON;
  v_existing_player UUID;
BEGIN

-- Agregar al inicio del cuerpo (después de BEGIN):
IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
    RETURN json_build_object('success', false, 'error', 
        'ACCESS_DENIED: Only admins can approve event entries.');
END IF;

  -- ── Step 1: Lock and validate ──
  SELECT user_id, event_id, status
  INTO v_user_id, v_event_id, v_request_status
  FROM game_requests WHERE id = p_request_id FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_FOUND');
  END IF;

  IF v_request_status != 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'REQUEST_NOT_PENDING', 'current_status', v_request_status);
  END IF;

  -- ── Step 2: Idempotency ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = v_user_id AND event_id = v_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    UPDATE game_requests SET status = 'approved' WHERE id = p_request_id;
    RETURN json_build_object('success', true, 'paid', false, 'note', 'ALREADY_PLAYER');
  END IF;

  -- ── Step 3: Entry fee ──
  SELECT COALESCE(entry_fee, 0)::BIGINT INTO v_entry_fee
  FROM events WHERE id = v_event_id;

  -- ── Step 4: Free event ──
  IF v_entry_fee = 0 THEN
    UPDATE game_requests SET status = 'approved' WHERE id = p_request_id;

    UPDATE game_players
      SET status = 'active', lives = 3, joined_at = NOW()
      WHERE user_id = v_user_id AND event_id = v_event_id AND status = 'spectator';

    IF NOT FOUND THEN
      INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
      VALUES (v_user_id, v_event_id, 'active', 3, NOW());
    END IF;

    RETURN json_build_object('success', true, 'paid', false, 'amount', 0);
  END IF;

  -- ── Step 5: Paid event ──
  v_payment_result := secure_clover_payment(v_user_id, v_entry_fee, 'event_entry:' || v_event_id::TEXT);

  IF (v_payment_result->>'success')::BOOLEAN != true THEN
    UPDATE game_requests SET status = 'payment_failed' WHERE id = p_request_id;
    RETURN json_build_object('success', false, 'error', 'PAYMENT_FAILED', 'payment_error', v_payment_result->>'error');
  END IF;

  -- ── Step 6: Finalize ──
  UPDATE game_requests SET status = 'paid' WHERE id = p_request_id;

  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = v_user_id AND event_id = v_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (v_user_id, v_event_id, 'active', 3, NOW());
  END IF;

  UPDATE events SET pot = COALESCE(pot, 0) + v_entry_fee WHERE id = v_event_id;

  RETURN json_build_object(
    'success', true,
    'paid', true,
    'amount', v_entry_fee,
    'new_balance', (v_payment_result->>'new_balance')::NUMERIC
  );
END;$function$
;

CREATE OR REPLACE FUNCTION public.attempt_start_minigame(p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_is_playing boolean;
    v_ban_ends_at timestamptz;
    v_penalty_level int;
    v_new_ban_time timestamptz;
    v_penalty_minutes int;
BEGIN
    -- Obtener estado actual
    SELECT is_playing, ban_ends_at, penalty_level
    INTO v_is_playing, v_ban_ends_at, v_penalty_level
    FROM profiles
    WHERE id = p_user_id;

    -- CASO 1: ¿Está baneado actualmente?
    IF v_ban_ends_at IS NOT NULL AND v_ban_ends_at > now() THEN
        RETURN json_build_object('status', 'banned', 'ban_ends_at', v_ban_ends_at);
    END IF;

    -- CASO 2: ¿Se salió "ilegalmente" la última vez? (La bandera sigue arriba)
    IF v_is_playing THEN
        -- Calcular castigo exponencial: 1 min * 2^nivel
        v_penalty_minutes := 1 * (2 ^ v_penalty_level); 
        v_new_ban_time := now() + (v_penalty_minutes || ' minutes')::interval;
        
        -- Aplicar castigo y subir nivel
        UPDATE profiles 
        SET is_playing = false, -- Reseteamos para que cumpla el castigo
            penalty_level = v_penalty_level + 1,
            ban_ends_at = v_new_ban_time
        WHERE id = p_user_id;

        RETURN json_build_object('status', 'penalized_now', 'ban_ends_at', v_new_ban_time);
    END IF;

    -- CASO 3: Todo limpio, dejar pasar y subir la bandera
    UPDATE profiles 
    SET is_playing = true,
        ban_ends_at = null -- Limpiar cualquier ban viejo
    WHERE id = p_user_id;

    RETURN json_build_object('status', 'allowed');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.broadcast_power(p_caster_id uuid, p_power_slug text, p_rival_targets jsonb, p_event_id uuid, p_duration_seconds integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_expires_at TIMESTAMP WITH TIME ZONE;
  v_target_record JSONB;
  v_target_id UUID;
BEGIN
  -- 1. Calculate Expiration
  v_expires_at := now() + (p_duration_seconds || ' seconds')::interval;
  -- 2. Loop through targets and insert
  -- Assuming p_rival_targets is a JSON array: [{"target_id": "uuid1"}, {"target_id": "uuid2"}]
  FOR v_target_record IN SELECT * FROM jsonb_array_elements(p_rival_targets)
  LOOP
    v_target_id := (v_target_record->>'target_id')::UUID;
    
    -- Prevent self-targeting just in case
    IF v_target_id <> p_caster_id THEN
      INSERT INTO public.active_powers (
        caster_id,
        target_id,
        power_slug,
        event_id,
        expires_at,
        created_at
      ) VALUES (
        p_caster_id,
        v_target_id,
        p_power_slug,
        p_event_id,
        v_expires_at,
        now()
      );
    END IF;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.buy_extra_life(p_user_id uuid, p_event_id uuid, p_cost integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_game_player_id UUID;
    v_current_coins BIGINT;
    v_current_lives INT;
    v_new_lives INT;
BEGIN
    SELECT id, coins, lives INTO v_game_player_id, v_current_coins, v_current_lives
    FROM public.game_players
    WHERE user_id = p_user_id AND event_id = p_event_id
    LIMIT 1;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'Player not found in this event';
    END IF;

    IF v_current_coins IS NULL THEN v_current_coins := 0; END IF;

    IF v_current_coins < p_cost THEN
        RAISE EXCEPTION 'Insufficient funds (Event Wallet)';
    END IF;

    IF v_current_lives >= 3 THEN
        RAISE EXCEPTION 'Max lives reached';
    END IF;

    v_new_lives := v_current_lives + 1;

    UPDATE public.game_players
    SET coins = v_current_coins - p_cost,
        lives = v_new_lives
    WHERE id = v_game_player_id;
    
    -- Record Transaction
    INSERT INTO public.transactions (id, game_player_id, transaction_type, coins_change, description)
    VALUES (gen_random_uuid(), v_game_player_id, 'purchase', -p_cost, 'Purchase Extra Life');

    RETURN v_new_lives;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.buy_item(p_user_id uuid, p_event_id uuid, p_item_id text, p_cost integer, p_is_power boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_game_player_id uuid;
    v_power_id uuid;
    v_current_qty integer;
BEGIN
    -- 1. Obtener el ID del jugador en el evento
    SELECT id INTO v_game_player_id 
    FROM public.game_players 
    WHERE user_id = p_user_id AND event_id = p_event_id;

    IF v_game_player_id IS NULL THEN
        RAISE EXCEPTION 'No estás inscrito en este evento.';
    END IF;

    -- 2. Lógica de poderes
    IF p_is_power THEN
        SELECT id INTO v_power_id FROM public.powers 
        WHERE (id::text = p_item_id OR slug = p_item_id) LIMIT 1;

        IF v_power_id IS NULL THEN
            RAISE EXCEPTION 'Poder no encontrado.';
        END IF;

        SELECT quantity INTO v_current_qty FROM public.player_powers 
        WHERE game_player_id = v_game_player_id AND power_id = v_power_id;

        IF COALESCE(v_current_qty, 0) >= 3 THEN
            RAISE EXCEPTION 'Máximo alcanzado (3 unidades).';
        END IF;

        -- Al ser SECURITY DEFINER, el RLS de la tabla ya no bloqueará este INSERT
        INSERT INTO public.player_powers (game_player_id, power_id, quantity)
        VALUES (v_game_player_id, v_power_id, 1)
        ON CONFLICT (game_player_id, power_id) 
        DO UPDATE SET quantity = player_powers.quantity + 1;
    END IF;

    -- 3. Reducción de saldo atómica
    UPDATE public.profiles 
    SET total_coins = total_coins - p_cost 
    WHERE id = p_user_id;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.cleanup_expired_defenses()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    fixed_count integer;
BEGIN
    -- Update game_players setting is_protected = false
    -- WHERE is_protected IS TRUE
    -- AND NOT EXISTS in active_powers (for defense types)
    
    WITH updated_rows AS (
        UPDATE public.game_players gp
        SET is_protected = false,
            updated_at = NOW()
        WHERE gp.is_protected = true
        AND NOT EXISTS (
            SELECT 1 
            FROM public.active_powers ap
            WHERE ap.target_id = gp.id
            AND ap.power_slug IN ('invisibility', 'shield', 'return')
            AND ap.expires_at > NOW()
        )
        RETURNING 1
    )
    SELECT count(*) INTO fixed_count FROM updated_rows;

    IF fixed_count > 0 THEN
        RAISE NOTICE 'Cleaned up % expired defense states.', fixed_count;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.deactivate_defense(p_game_player_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    -- Security: Validate caller owns the player
    IF NOT EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.id = p_game_player_id AND gp.user_id = auth.uid()
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- Clear protection flag
    UPDATE public.game_players 
    SET is_protected = false, updated_at = now() 
    WHERE id = p_game_player_id AND is_protected = true;

    -- Clean up any expired defense rows in active_powers
    DELETE FROM public.active_powers 
    WHERE target_id = p_game_player_id 
      AND power_slug IN ('shield', 'return', 'invisibility')
      AND expires_at <= now();

    RETURN json_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.debug_betting_status(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_event_exists BOOLEAN;
    v_betting_active BOOLEAN;
    v_ticket_price INTEGER;
    v_bet_count INTEGER;
    v_total_amount INTEGER;
    v_last_bet JSONB;
    v_racer_id_type TEXT;
BEGIN
    -- Check Event
    SELECT EXISTS(SELECT 1 FROM events WHERE id = p_event_id), betting_active, bet_ticket_price
    INTO v_event_exists, v_betting_active, v_ticket_price
    FROM events WHERE id = p_event_id;

    -- Check Bets
    SELECT COUNT(*), COALESCE(SUM(amount), 0)
    INTO v_bet_count, v_total_amount
    FROM bets WHERE event_id = p_event_id;

    -- Get Last Bet
    SELECT jsonb_build_object('id', id, 'racer_id', racer_id, 'amount', amount, 'created_at', created_at)
    INTO v_last_bet
    FROM bets WHERE event_id = p_event_id ORDER BY created_at DESC LIMIT 1;

    -- Check Column Type (Indirectly via pg_typeof or just knowing schema)
    -- We can try to see if racer_id is compatible with UUID
    
    RETURN jsonb_build_object(
        'event_exists', v_event_exists,
        'betting_active', v_betting_active,
        'ticket_price', v_ticket_price,
        'bet_count', v_bet_count,
        'total_amount', v_total_amount,
        'last_bet', v_last_bet
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.distribute_event_prizes(p_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_event_record RECORD;
  v_participant_count INT;
  v_completed_count INT;
  v_distributable_pot NUMERIC;
  v_total_collected NUMERIC;
  v_winners RECORD;
  v_prize_amount NUMERIC;
  v_share NUMERIC;
  v_rank INT;
  v_distribution_results JSONB[] := ARRAY[]::JSONB[];
  v_shares NUMERIC[];

  -- Betting integration
  v_winner_user_id UUID;
  v_betting_result JSONB;
BEGIN
  -- 1. Lock Event & Get Details
  SELECT * INTO v_event_record FROM events WHERE id = p_event_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- 2. Idempotency Check
  IF EXISTS (SELECT 1 FROM prize_distributions WHERE event_id = p_event_id AND rpc_success = true) THEN
     RETURN json_build_object('success', true, 'message', 'Premios ya distribuidos previamente', 'race_completed', true, 'already_distributed', true);
  END IF;

  -- 3. Define Distribution Shares
  IF v_event_record.configured_winners = 1 THEN
    v_shares := ARRAY[1.0];
  ELSIF v_event_record.configured_winners = 2 THEN
    v_shares := ARRAY[0.70, 0.30];
  ELSE
    v_shares := ARRAY[0.50, 0.30, 0.20];
  END IF;

  -- 4. Count ALL Participants (excludes spectators)
  SELECT COUNT(*) INTO v_participant_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed', 'banned', 'suspended', 'eliminated');

  IF v_participant_count = 0 THEN
    RETURN json_build_object('success', false, 'message', 'No hay participantes válidos');
  END IF;

  -- 4.5. Check if race is finished or if caller is admin
  SELECT COUNT(*) INTO v_completed_count
  FROM game_players
  WHERE event_id = p_event_id
  AND status = 'completed';

  IF v_completed_count < v_event_record.configured_winners AND v_completed_count < v_participant_count THEN
    IF (auth.role() != 'service_role') AND (NOT public.is_admin(auth.uid())) THEN
        RETURN json_build_object('success', false, 'message', 'La carrera aún no ha terminado o no tienes permisos para forzar la distribución.');
    END IF;
  END IF;

  -- 5. Finalize Event (ALWAYS, even if pot is 0)
  UPDATE events
  SET status = 'completed',
      completed_at = NOW(),
      winner_id = (SELECT user_id FROM game_players WHERE event_id = p_event_id AND status != 'spectator' ORDER BY completed_clues_count DESC, finish_time ASC LIMIT 1)
  WHERE id = p_event_id;

  -- 6. Assign final_placement to ALL non-spectator participants (ALWAYS)
  UPDATE game_players gp
  SET final_placement = ranked.pos
  FROM (
    SELECT id,
      ROW_NUMBER() OVER (
        ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST, last_active ASC NULLS LAST
      ) AS pos
    FROM game_players
    WHERE event_id = p_event_id
      AND status != 'spectator'
  ) AS ranked
  WHERE gp.id = ranked.id;

  -- ══════════════════════════════════════════════════════════
  -- 6.5 FIX: Mark ALL 'active' (non-spectator) players as 'completed'
  --     so the client-side podium screen sees a consistent status.
  --     Players who didn't finish get their final_placement from step 6
  --     (ranked by progress) and status = 'completed'.
  -- ══════════════════════════════════════════════════════════
  UPDATE game_players
  SET status = 'completed'
  WHERE event_id = p_event_id
    AND status = 'active';

  -- 7. Calculate Pot
  v_total_collected := COALESCE(v_event_record.pot, 0);
  v_distributable_pot := v_total_collected * 0.70;

  IF v_distributable_pot <= 0 THEN
      -- Still resolve bets even if prize pot is 0
      SELECT user_id INTO v_winner_user_id
      FROM game_players
      WHERE event_id = p_event_id AND status != 'spectator'
      ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
      LIMIT 1;

      IF v_winner_user_id IS NOT NULL THEN
          v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
      END IF;

      RETURN json_build_object(
        'success', true,
        'message', 'Evento finalizado sin premios (Bote 0)',
        'pot', 0,
        'betting_results', v_betting_result
      );
  END IF;

  -- 8. Select Winners (Top N) and distribute prizes
  v_rank := 0;

  FOR v_winners IN
    SELECT *
    FROM game_players
    WHERE event_id = p_event_id
    AND status IN ('completed') -- All are 'completed' after step 6.5
    ORDER BY completed_clues_count DESC, finish_time ASC NULLS LAST
    LIMIT v_event_record.configured_winners
  LOOP
    v_rank := v_rank + 1;

    -- Identify the #1 winner for betting resolution
    IF v_rank = 1 THEN
       v_winner_user_id := v_winners.user_id;
    END IF;

    IF v_rank <= array_length(v_shares, 1) THEN
        v_share := v_shares[v_rank];
        v_prize_amount := floor(v_distributable_pot * v_share);

        IF v_prize_amount > 0 THEN
            -- A. Update User Wallet
            UPDATE profiles
            SET clovers = COALESCE(clovers, 0) + v_prize_amount
            WHERE id = v_winners.user_id;

            -- B. Record Distribution Log
            INSERT INTO prize_distributions
            (event_id, user_id, position, amount, pot_total, participants_count, entry_fee, rpc_success)
            VALUES
            (p_event_id, v_winners.user_id, v_rank, v_prize_amount, v_distributable_pot, v_participant_count, v_event_record.entry_fee, true);

            -- C. Log to Wallet Ledger
            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
              v_winners.user_id,
              v_prize_amount,
              'Premio Competencia: ' || v_event_record.title || ' (Posición ' || v_rank || ')',
              jsonb_build_object('type', 'event_prize', 'event_id', p_event_id, 'rank', v_rank)
            );

            -- D. Add to results
            v_distribution_results := array_append(v_distribution_results, jsonb_build_object(
                'user_id', v_winners.user_id,
                'rank', v_rank,
                'amount', v_prize_amount
            ));
        END IF;
    END IF;
  END LOOP;

  -- ══════════════════════════════════════════════════════════
  -- 9. RESOLVE BETS: Pass the #1 winner's user_id
  -- ══════════════════════════════════════════════════════════
  IF v_winner_user_id IS NOT NULL THEN
      v_betting_result := public.resolve_event_bets(p_event_id, v_winner_user_id);
  ELSE
      v_betting_result := jsonb_build_object('success', false, 'message', 'No winner found to resolve bets');
  END IF;

  RETURN json_build_object(
    'success', true,
    'pot_total', v_total_collected,
    'distributable_pot', v_distributable_pot,
    'winners_count', v_rank,
    'results', v_distribution_results,
    'betting_results', v_betting_result
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$
;

create or replace view "public"."event_pools" as  SELECT event_id,
    COALESCE(sum(amount), (0)::bigint) AS total_pot,
    count(*) AS total_bets
   FROM public.bets
  GROUP BY event_id;


CREATE OR REPLACE FUNCTION public.execute_combat_power(p_event_id uuid, p_caster_id uuid, p_target_id uuid, p_power_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_power_slug text;
    v_power_duration integer;
    v_has_shield boolean;
    v_quantity integer;
BEGIN
    -- 1. Obtener detalles del poder
    SELECT slug, duration INTO v_power_slug, v_power_duration 
    FROM public.powers WHERE id = p_power_id;

    -- 2. Verificar si el atacante tiene el poder disponible
    SELECT quantity INTO v_quantity 
    FROM public.player_powers 
    WHERE game_player_id = p_caster_id AND power_id = p_power_id;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
        RETURN json_build_object('success', false, 'reason', 'no_quantity');
    END IF;

    -- 3. Verificar si el objetivo tiene un escudo activo
    SELECT EXISTS (
        SELECT 1 FROM public.active_powers 
        WHERE target_id = p_target_id 
        AND power_slug = 'shield'
        AND expires_at > now()
    ) INTO v_has_shield;

    -- 4. Lógica de resolución
    IF v_has_shield THEN
        -- ELIMINAR EL ESCUDO (Se consume al proteger)
        DELETE FROM public.active_powers 
        WHERE target_id = p_target_id AND power_slug = 'shield';

        -- REGISTRAR EVENTO DE BLOQUEO (Para el feedback del defensor)
        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
        VALUES (p_event_id, p_caster_id, p_target_id, p_power_id, v_power_slug, 'shield_blocked');

        -- DESCONTAR PODER AL ATACANTE
        UPDATE public.player_powers 
        SET quantity = quantity - 1 
        WHERE game_player_id = p_caster_id AND power_id = p_power_id;

        RETURN json_build_object('success', true, 'blocked', true, 'reason', 'shield_absorbed');

    ELSE
        -- NO HAY ESCUDO: APLICAR EL PODER
        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (p_event_id, p_caster_id, p_target_id, p_power_id, v_power_slug, now() + (v_power_duration || ' seconds')::interval);

        -- REGISTRAR EVENTO DE ÉXITO
        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
        VALUES (p_event_id, p_caster_id, p_target_id, p_power_id, v_power_slug, 'success');

        -- DESCONTAR PODER AL ATACANTE
        UPDATE public.player_powers 
        SET quantity = quantity - 1 
        WHERE game_player_id = p_caster_id AND power_id = p_power_id;

        RETURN json_build_object('success', true, 'blocked', false, 'reason', 'applied');
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.finish_minigame_legally(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE profiles
    SET is_playing = false
    WHERE id = p_user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.finish_race_and_distribute(target_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  current_user_id uuid;
  event_record record;
  player_record record;
  participants_count integer;
  entry_fee integer;
  total_pot decimal;
  tier_name text;
  
  -- Shares
  p1_share decimal := 0;
  p2_share decimal := 0;
  p3_share decimal := 0;
  
  -- Leaderboard
  leaderboard_cursor refcursor;
  p_rank integer := 0;
  p_row record;
  prize_amount integer;
  
  results_json jsonb := '[]'::jsonb;
begin
  -- 1. Get Current User
  current_user_id := auth.uid();
  
  -- 2. Validate Event & Caller Status
  select * into event_record from events where id = target_event_id;
  
  if event_record.status = 'completed' then
    return json_build_object('success', true, 'message', 'Event already completed');
  end if;
  
  select * into player_record from game_players 
  where event_id = target_event_id and user_id = current_user_id;
  
  if player_record is null then
     return json_build_object('success', false, 'message', 'Player not found in event');
  end if;
  
  -- OPTIONAL: Strict check - only allow if caller has finished?
  -- For now, we assume the client calls this only when finished. 
  -- But for security, we should check if they solved all clues?
  -- Replicating "finish" logic might be complex if "total clues" isn't stored strictly.
  -- We'll rely on the fact that ONLY a finished player hits the endpoint in the app flow.
  -- And even if they call it early, they might just close the event for everyone else? 
  -- RISK: A hacker could call this to end the race early.
  -- MITIGATION: We trust the app flow for now, or add a check for 'completed_clues_count'.
  
  -- 3. Calculate Pot
  entry_fee := coalesce(event_record.entry_fee, 0);
  
  -- Count valid participants (same filter as AdminService)
  select count(*) into participants_count
  from game_players
  where event_id = target_event_id
  and status in ('active', 'completed', 'banned', 'suspended', 'eliminated');
  
  total_pot := (participants_count * entry_fee) * 0.70;
  
  if total_pot <= 0 then
     -- Close event even if no pot
     update events set status = 'completed', completed_at = now() where id = target_event_id;
     return json_build_object('success', true, 'message', 'Event completed (No Pot)');
  end if;
  
  -- 4. Determine Tiers
  if participants_count < 5 then
    tier_name := 'Tier 1 (<5)';
    p1_share := 1.00;
  elsif participants_count < 10 then
    tier_name := 'Tier 2 (5-9)';
    p1_share := 0.70;
    p2_share := 0.30;
  else
    tier_name := 'Tier 3 (10+)';
    p1_share := 0.50;
    p2_share := 0.30;
    p3_share := 0.20;
  end if;
  
  -- 5. Fetch Leaderboard (TOP 3)
  -- Order by completed_clues DESC, last_completion_time ASC
  -- Note: If multiple people finished, this respects the order.
  -- If only the caller finished, they are #1. Others are #2, #3 based on clues.
  open leaderboard_cursor for 
    select user_id, completed_clues_count
    from game_players
    where event_id = target_event_id
    and status != 'spectator'
    order by completed_clues_count desc, last_completion_time asc
    limit 3;
    
  loop
    fetch leaderboard_cursor into p_row;
    exit when not found;
    
    p_rank := p_rank + 1;
    prize_amount := 0;
    
    if p_rank = 1 and p1_share > 0 then
       prize_amount := round(total_pot * p1_share);
    elsif p_rank = 2 and p2_share > 0 then
       prize_amount := round(total_pot * p2_share);
    elsif p_rank = 3 and p3_share > 0 then
       prize_amount := round(total_pot * p3_share);
    end if;
    
    if prize_amount > 0 then
       -- Update Wallet
       update profiles set clovers = coalesce(clovers, 0) + prize_amount where id = p_row.user_id;
       
       -- Record Prize in Game History (Logic we added to AdminService)
       update game_players set clovers = prize_amount 
       where event_id = target_event_id and user_id = p_row.user_id;
       
       results_json := results_json || jsonb_build_object('rank', p_rank, 'user', p_row.user_id, 'amount', prize_amount);
    end if;
  end loop;
  
  close leaderboard_cursor;
  
  -- 6. Close Event
  update events set status = 'completed', completed_at = now(), winner_id = current_user_id
  where id = target_event_id;
  
  return json_build_object(
    'success', true, 
    'message', 'Event completed and prizes distributed',
    'pot', total_pot,
    'results', results_json
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_clues_for_event(target_event_id uuid, quantity integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.clues (event_id, sequence_index, title, description)
  select 
    target_event_id, 
    s.i, 
    'Pista ' || s.i, 
    'Descripción pendiente para la pista ' || s.i
  from generate_series(1, quantity) as s(i);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_auto_event_settings()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  SELECT value INTO v_result
  FROM public.app_config
  WHERE key = 'online_automation_config';
  
  RETURN coalesce(v_result, '{}'::jsonb);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_clues_with_progress(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id UUID;
    v_result JSONB := '[]'::JSONB;
    v_clue RECORD;
    v_progress RECORD;
    v_prev_completed BOOLEAN := TRUE; -- Primera pista siempre desbloqueada
    v_is_completed BOOLEAN;
    v_is_locked BOOLEAN;
    v_clue_json JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSONB;
    END IF;

    -- Iterar sobre las pistas del evento en orden secuencial
    FOR v_clue IN
        SELECT c.id, c.event_id, c.sequence_index, c.title, c.description,
               c.hint, c.type, c.puzzle_type, c.minigame_url,
               c.riddle_question, c.xp_reward, c.created_at,
               c.latitude, c.longitude
        FROM clues c
        WHERE c.event_id = p_event_id
        ORDER BY c.sequence_index ASC
    LOOP
        -- Obtener progreso del usuario para esta pista
        SELECT ucp.is_completed, ucp.is_locked
        INTO v_progress
        FROM user_clue_progress ucp
        WHERE ucp.user_id = v_user_id AND ucp.clue_id = v_clue.id;

        -- Lógica secuencial (Mario Kart Style)
        v_is_locked := NOT v_prev_completed;
        v_is_completed := COALESCE(v_progress.is_completed, FALSE);

        -- Integrity Check: Una pista no puede estar completada si está bloqueada
        IF v_is_locked THEN
            v_is_completed := FALSE;
        END IF;

        -- Construir JSON de la pista (SIN riddle_answer por seguridad)
        v_clue_json := jsonb_build_object(
            'id', v_clue.id,
            'event_id', v_clue.event_id,
            'sequence_index', v_clue.sequence_index,
            'title', v_clue.title,
            'description', v_clue.description,
            'hint', v_clue.hint,
            'type', v_clue.type,
            'puzzle_type', v_clue.puzzle_type,
            'minigame_url', v_clue.minigame_url,
            'riddle_question', v_clue.riddle_question,
            'xp_reward', v_clue.xp_reward,
            'created_at', v_clue.created_at,
            'latitude', v_clue.latitude,
            'longitude', v_clue.longitude,
            'is_completed', v_is_completed,
            'isCompleted', v_is_completed,
            'is_locked', v_is_locked
        );

        v_result := v_result || v_clue_json;

        -- Actualizar para la siguiente iteración
        v_prev_completed := v_is_completed;
    END LOOP;

    RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_bets_enriched(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'bet_id', b.id,
            'user_id', b.user_id,
            'bettor_name', COALESCE(bettor.name, 'Apostador'),
            'bettor_avatar_id', bettor.avatar_id,
            'racer_id', b.racer_id,
            'racer_name', COALESCE(racer.name, 'Participante'),
            'racer_avatar_id', racer.avatar_id,
            'amount', b.amount,
            'created_at', b.created_at
        ) ORDER BY b.created_at DESC
    ), '[]'::jsonb)
    INTO v_result
    FROM public.bets b
    LEFT JOIN public.profiles bettor ON bettor.id = b.user_id
    LEFT JOIN public.profiles racer  ON racer.id  = b.racer_id::uuid
    WHERE b.event_id = p_event_id;

    RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_betting_stats(p_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total_pot BIGINT;
  v_total_bets BIGINT;
BEGIN
  SELECT 
    COALESCE(SUM(amount), 0),
    COUNT(*)
  INTO v_total_pot, v_total_bets
  FROM bets
  WHERE event_id = p_event_id;

  RETURN json_build_object(
    'total_pot', v_total_pot,
    'total_bets', v_total_bets
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_financial_results(p_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
declare
  v_event_status text;
  v_pot numeric;
  v_winners json;
  v_distribution_result json;
begin
  -- Get event status and pot
  select status, pot into v_event_status, v_pot
  from events
  where id = p_event_id;

  -- If not finished, return basics
  if v_event_status != 'finished' then
    return json_build_object(
      'status', v_event_status,
      'pot', v_pot,
      'distribution', null
    );
  end if;

  -- Start with empty result
  v_distribution_result := json_build_object(
      'status', v_event_status,
      'pot', v_pot,
      'winners', '[]'::json,
      'bet_winners', '[]'::json  -- We could fetch this from a prize_distributions log table if it exists
  );

  -- NOTE: This part depends on where 'distribute_event_prizes' stores its results.
  -- Assuming 'prize_distributions' table stores the result log.
  
  select results into v_winners
  from prize_distributions
  where event_id = p_event_id
  order by created_at desc
  limit 1;

  if v_winners is not null then
     v_distribution_result := json_build_object(
      'status', v_event_status,
      'pot', v_pot,
      'results', v_winners -- This likely contains the 'results' array from the distribution RPC
    );
  end if;

  return v_distribution_result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_leaderboard(target_event_id uuid)
 RETURNS TABLE(id uuid, name text, avatar_url text, level integer, profession text, total_xp integer, completed_clues_count integer, last_completion_time timestamp with time zone, user_id uuid, game_player_id uuid, coins bigint, lives integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.name, 'Jugador')::TEXT,
    COALESCE(p.avatar_url, '')::TEXT,
    p.level,
    p.profession::TEXT,
    p.total_xp,
    gp.completed_clues_count,
    gp.last_active, 
    p.id as user_id,
    gp.id as game_player_id,
    gp.coins,
    gp.lives
  FROM game_players gp
  JOIN profiles p ON gp.user_id = p.id
  WHERE gp.event_id = target_event_id
  ORDER BY gp.completed_clues_count DESC, gp.last_active ASC NULLS LAST;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_event_participants_count(target_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  total_count integer;
begin
  select count(*) into total_count
  from game_players
  where event_id = target_event_id
  and status in ('active', 'completed', 'banned', 'suspended', 'eliminated');
  
  return total_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_game_leaderboard(target_game_id uuid)
 RETURNS TABLE(id uuid, name text, avatar_url text, level integer, profession text, total_coins bigint, clues_completed integer, status text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.name, 'Jugador') as name,
    COALESCE(p.avatar_url, '') as avatar_url,
    p.level,
    p.profession,
    p.coins as total_coins,
    gp.completed_clues_count as clues_completed,
    p.status -- Obtenemos el status ('active', 'invisible', etc.)
  FROM game_players gp
  JOIN profiles p ON gp.user_id = p.id
  WHERE gp.event_id = target_game_id -- Asegúrate de que el nombre de la columna sea correcto (event_id o game_id)
  ORDER BY gp.completed_clues_count DESC, p.coins DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_game_player_id(p_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id 
  FROM public.game_players 
  WHERE user_id = p_user_id 
  LIMIT 1;
  
  RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_gateway_fee_percentage()
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  fee numeric;
BEGIN
  SELECT (value::text)::numeric INTO fee
  FROM public.app_config
  WHERE key = 'gateway_fee_percentage';
  
  -- Default to 0 if not found (no fee displayed)
  RETURN COALESCE(fee, 0.0);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_event_id()
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT event_id
  FROM public.game_players
  WHERE user_id = auth.uid()
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_event_id_secure()
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT event_id
  FROM public.game_players
  WHERE user_id = auth.uid()
  LIMIT 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_event_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT event_id FROM game_players WHERE user_id = auth.uid()
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_inventory(p_user_id uuid)
 RETURNS TABLE(power_id uuid, quantity integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  return query
  select pp.power_id, pp.quantity
  from public.player_powers pp
  join public.game_players gp on gp.id = pp.game_player_id
  where gp.user_id = p_user_id
  and pp.quantity > 0;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_inventory_by_event(p_user_id uuid, p_event_id uuid)
 RETURNS TABLE(power_id uuid, slug text, name text, quantity integer, description text, icon text, type text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_game_player_id uuid;
BEGIN
  -- 1. Get Game Player ID
  SELECT id INTO v_game_player_id
  FROM public.game_players
  WHERE user_id = p_user_id AND event_id = p_event_id;

  IF v_game_player_id IS NULL THEN
    RETURN;
  END IF;

  -- 2. Return inventory with JOIN to powers table
  RETURN QUERY
  SELECT 
    pp.power_id,
    p.slug,
    p.name,
    pp.quantity,
    p.description,
    p.icon,
    p.power_type
  FROM public.player_powers pp
  JOIN public.powers p ON pp.power_id = p.id
  WHERE pp.game_player_id = v_game_player_id
  AND pp.quantity > 0;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_event_winnings(p_event_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_winnings INTEGER := 0;
    v_won BOOLEAN := FALSE;
BEGIN
    -- Sum up all 'bet_payout' type entries in ledger for this event/user
    -- The metadata contains event_id, so we can filter by it.
    -- However, metadata is JSONB.
    
    SELECT COALESCE(SUM(amount), 0) INTO v_winnings
    FROM wallet_ledger
    WHERE user_id = p_user_id
    AND (metadata->>'type') = 'bet_payout'
    AND (metadata->>'event_id') = p_event_id::text;
    
    IF v_winnings > 0 THEN
        v_won := TRUE;
    END IF;

    RETURN jsonb_build_object(
        'won', v_won,
        'amount', v_winnings
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_event_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  function_url text := 'https://hyjelngckvqoanckqwep.supabase.co/functions/v1/delete-event-image';
  service_role_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh5amVsbmdja3Zxb2FuY2txd2VwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTIxMjUyMSwiZXhwIjoyMDgwNzg4NTIxfQ.RXoN5zT-kUW1kXjgJ4CLpS3V7_-9nh4ZrMVXzS5V5rk'; 
begin
  perform net.http_post(
      url := function_url,
      body := jsonb_build_object(
          'type', 'DELETE',
          'old_record', old
      ),
      headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || service_role_key
      )
  );
  return old;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.profiles (id, name, email, status)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'name',
    new.email,
    'pending' -- Forzar estado pendiente al crear
  );
  RETURN new;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_status_on_power_expiry()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Si el poder que se borra o expira es invisibilidad
  IF OLD.power_slug = 'invisibility' THEN
    UPDATE public.profiles 
    SET status = 'active'
    WHERE id = (SELECT user_id FROM public.game_players WHERE id = OLD.target_id);
  END IF;
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_user_email_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Using WARNING so Supabase doesn't filter it out of the Postgres Logs
  RAISE WARNING '⚡ [EMAIL_TEST] Trigger fired for ID: %', NEW.id;
  RAISE WARNING '⚡ [EMAIL_TEST] OLD email: % | NEW email: %', OLD.email, NEW.email;
  RAISE WARNING '⚡ [EMAIL_TEST] OLD change: % | NEW change: %', OLD.email_change, NEW.email_change;

  IF (OLD.email IS DISTINCT FROM NEW.email) OR 
     (OLD.email_change IS DISTINCT FROM NEW.email_change AND (NEW.email_change IS NULL OR NEW.email_change = '')) THEN
    
    RAISE WARNING '✅ [EMAIL_TEST] Condition met! Updating public.profiles...';
    
    UPDATE public.profiles
    SET
      email_verified = true,
      email = NEW.email
    WHERE id = NEW.id;

  ELSE
    RAISE WARNING '❌ [EMAIL_TEST] No email change detected in this specific update.';
  END IF;
  
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_clue_count(p_user_id uuid, p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE game_players
  SET 
    completed_clues_count = completed_clues_count + 1,
    last_active = NOW()
  WHERE user_id = p_user_id AND event_id = p_event_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.initialize_game_for_user(target_user_id uuid, target_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  first_clue_id bigint;
BEGIN
  -- 1. Insertar o resetear jugador
  INSERT INTO public.game_players (user_id, event_id, lives, joined_at)
  VALUES (target_user_id, target_event_id, 3, now())
  ON CONFLICT (user_id, event_id) DO UPDATE SET lives = 3;

  -- 2. ACTIVAR EL PERFIL (Crucial para el flujo de la App)
  UPDATE public.profiles 
  SET status = 'active', is_playing = true 
  WHERE id = target_user_id;

  -- 3. Inicializar pistas (Lógica existente...)
  SELECT id INTO first_clue_id FROM public.clues WHERE event_id = target_event_id ORDER BY sequence_index ASC LIMIT 1;
  
  IF first_clue_id IS NOT NULL THEN
    INSERT INTO public.user_clue_progress (user_id, clue_id, is_locked, is_completed)
    SELECT target_user_id, id, true, false FROM public.clues WHERE event_id = target_event_id
    ON CONFLICT (user_id, clue_id) DO NOTHING;
    
    UPDATE public.user_clue_progress SET is_locked = false
    WHERE user_id = target_user_id AND clue_id = first_clue_id;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = p_user_id AND role IN ('admin', 'user_staff')
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin_or_staff(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = p_user_id AND role IN ('admin', 'user_staff')
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_bcv_rate_valid()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  last_update timestamptz;
BEGIN
  SELECT updated_at INTO last_update
  FROM public.app_config
  WHERE key = 'bcv_exchange_rate';

  -- NULL = never updated = STALE → block withdrawals
  IF last_update IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 26 hours = 1 day + 2 hours of grace period
  -- If the cron runs at 12:00 AM and fails, admins have until 2:00 AM
  -- the next day to notice and fix it manually.
  RETURN (now() - last_update) < INTERVAL '26 hours';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_event_completed(p_event_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_is_completed BOOLEAN;
BEGIN
  SELECT is_completed INTO v_is_completed
  FROM events
  WHERE id = p_event_id;
  
  RETURN COALESCE(v_is_completed, FALSE);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_staff(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = p_user_id AND role = 'user_staff'
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.join_game(p_game_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO game_players (game_id, user_id, coins, current_challenge_index)
  VALUES (p_game_id, p_user_id, 100, 0)
  ON CONFLICT (game_id, user_id) DO NOTHING;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.join_online_free_event(p_user_id uuid, p_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_existing_player UUID;
BEGIN
  -- ── Step 1: Idempotency ──
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = p_user_id AND event_id = p_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    -- Ensure request exists
    UPDATE game_requests SET status = 'approved' WHERE user_id = p_user_id AND event_id = p_event_id;
    IF NOT FOUND THEN
      INSERT INTO game_requests (user_id, event_id, status) VALUES (p_user_id, p_event_id, 'approved');
    END IF;
    
    RETURN json_build_object('success', true, 'note', 'ALREADY_PLAYER');
  END IF;

  -- ── Step 2: Create game_player (upgrade spectator if exists) ──
  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = p_user_id AND event_id = p_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (p_user_id, p_event_id, 'active', 3, NOW());
  END IF;

  -- ── Step 3: Create game_request (The FIX) ──
  UPDATE game_requests SET status = 'approved' WHERE user_id = p_user_id AND event_id = p_event_id;
  IF NOT FOUND THEN
    INSERT INTO game_requests (user_id, event_id, status) VALUES (p_user_id, p_event_id, 'approved');
  END IF;

  RETURN json_build_object('success', true);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.join_online_paid_event(p_user_id uuid, p_event_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_entry_fee BIGINT;
  v_payment_result JSON;
  v_existing_player UUID;
BEGIN
  SELECT id INTO v_existing_player
  FROM game_players
  WHERE user_id = p_user_id AND event_id = p_event_id AND status != 'spectator'
  LIMIT 1;

  IF v_existing_player IS NOT NULL THEN
    RETURN json_build_object('success', true, 'paid', false, 'note', 'ALREADY_PLAYER');
  END IF;

  SELECT COALESCE(entry_fee, 0)::BIGINT INTO v_entry_fee
  FROM events WHERE id = p_event_id;

  IF v_entry_fee = 0 THEN
    RETURN json_build_object('success', false, 'error', 'EVENT_IS_FREE');
  END IF;

  v_payment_result := secure_clover_payment(p_user_id, v_entry_fee, 'online_event_entry:' || p_event_id::TEXT);

  IF (v_payment_result->>'success')::BOOLEAN != true THEN
    RETURN json_build_object('success', false, 'error', 'PAYMENT_FAILED', 'payment_error', v_payment_result->>'error');
  END IF;

  UPDATE game_players
    SET status = 'active', lives = 3, joined_at = NOW()
    WHERE user_id = p_user_id AND event_id = p_event_id AND status = 'spectator';

  IF NOT FOUND THEN
    INSERT INTO game_players (user_id, event_id, status, lives, joined_at)
    VALUES (p_user_id, p_event_id, 'active', 3, NOW());
  END IF;

  UPDATE events SET pot = COALESCE(pot, 0) + v_entry_fee WHERE id = p_event_id;

  RETURN json_build_object(
    'success', true,
    'paid', true,
    'amount', v_entry_fee,
    'new_balance', (v_payment_result->>'new_balance')::NUMERIC
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.log_admin_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_admin_id UUID;
    v_details JSONB;
    v_target_id UUID;
    v_target_table TEXT := TG_TABLE_NAME;
    v_action_type TEXT := TG_OP; -- INSERT, UPDATE, DELETE
BEGIN
    -- Attempt to get current user ID (might be null for system tasks)
    v_admin_id := auth.uid();

    -- Construct Details JSON
    IF (TG_OP = 'INSERT') THEN
        v_details := jsonb_build_object('new', row_to_json(NEW));
        v_target_id := NEW.id;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Only log if actual changes happened (optional optimization)
        -- IF NEW IS NOT DISTINCT FROM OLD THEN RETURN NEW; END IF;
        
        v_details := jsonb_build_object(
            'old', row_to_json(OLD), 
            'new', row_to_json(NEW)
        );
        -- Simple diff isn't native without extensions, so we store snapshots
        v_target_id := NEW.id;
    ELSIF (TG_OP = 'DELETE') THEN
        v_details := jsonb_build_object('old', row_to_json(OLD));
        v_target_id := OLD.id;
    END IF;

    -- Insert Log
    INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
    VALUES (v_admin_id, v_action_type, v_target_table, v_target_id, v_details);

    -- Return result for the trigger to proceed
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.log_sensitive_profile_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Only log if sensitive fields changed
    IF (NEW.role IS DISTINCT FROM OLD.role) OR
       (NEW.clovers IS DISTINCT FROM OLD.clovers) THEN
       
        INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
        VALUES (
            auth.uid(), 
            'UPDATE_SENSITIVE', 
            'profiles', 
            NEW.id, 
            jsonb_build_object(
                'old_role', OLD.role, 'new_role', NEW.role,
                'old_clovers', OLD.clovers, 'new_clovers', NEW.clovers
            )
        );
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.lose_life(p_user_id uuid, p_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    current_lives integer;
    new_lives integer;
    v_is_protected boolean;
BEGIN
    -- Select with locking
    SELECT lives, is_protected INTO current_lives, v_is_protected
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player not found (Event: %, User: %)', p_event_id, p_user_id;
    END IF;

    -- CHECK PROTECTION
    IF v_is_protected THEN
        -- Consume protection atomically
        UPDATE public.game_players
        SET is_protected = false,
            updated_at = now()
        WHERE event_id = p_event_id AND user_id = p_user_id;
        
        -- Also try to clean up the visual effect if possible (best effort)
        -- We won't error if this fails, as the state of truth is is_protected
        DELETE FROM public.active_powers 
        WHERE target_id = (SELECT id FROM public.game_players WHERE event_id = p_event_id AND user_id = p_user_id) 
        AND power_slug IN ('shield', 'return');

        -- Return current lives (no damage taken)
        RETURN current_lives; 
    END IF;

    IF current_lives > 0 THEN
        new_lives := current_lives - 1;
    ELSE
        new_lives := 0;
    END IF;

    UPDATE public.game_players
    SET lives = new_lives,
        updated_at = now()
    WHERE event_id = p_event_id AND user_id = p_user_id;

    RETURN new_lives;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.place_bets_batch(p_event_id uuid, p_user_id uuid, p_racer_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_ticket_price INTEGER;
    v_betting_active BOOLEAN;
    v_event_status TEXT;
    v_total_cost INTEGER;
    v_racer_id UUID;
    v_count INTEGER;
    v_payment_result JSONB;
BEGIN
    -- [SECURITY PATCH] IDOR Protection: only the authenticated user can place their own bets
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Security Violation: You can only place bets for yourself.';
    END IF;

    -- 1. Validate Event & Betting State
    SELECT bet_ticket_price, betting_active, status
    INTO v_ticket_price, v_betting_active, v_event_status
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    IF v_event_status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Betting is only allowed while event is pending');
    END IF;

    IF v_betting_active = FALSE THEN
        RETURN jsonb_build_object('success', false, 'message', 'Betting is closed for this event');
    END IF;

    v_count := array_length(p_racer_ids, 1);
    IF v_count IS NULL OR v_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'No racers selected');
    END IF;

    -- 2. Calculate Cost
    v_total_cost := v_ticket_price * v_count;

    -- 3. Atomic Payment
    v_payment_result := public.secure_clover_payment(
        p_user_id,
        v_total_cost,
        'Bet on ' || v_count || ' racers in event ' || p_event_id
    );

    IF (v_payment_result->>'success')::boolean = false THEN
        RETURN v_payment_result;
    END IF;

    -- 4. Insert Bets (UUID racer_id)
    FOREACH v_racer_id IN ARRAY p_racer_ids
    LOOP
        INSERT INTO public.bets (event_id, user_id, racer_id, amount)
        VALUES (p_event_id, p_user_id, v_racer_id, v_ticket_price)
        ON CONFLICT (event_id, user_id, racer_id) DO NOTHING;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bets placed successfully',
        'total_cost', v_total_cost,
        'new_balance', (v_payment_result->>'new_balance')
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.process_paid_clover_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    treboles_comprados numeric;
BEGIN
    -- 1. Verificamos el cambio de estado a 'success' (según tu requerimiento)
    IF (NEW.status = 'success' AND OLD.status IS DISTINCT FROM 'success') THEN
        
        -- 2. Extraemos la cantidad del extra_data (campo 'clovers_amount' de tu payload)
        treboles_comprados := (NEW.extra_data->>'clovers_amount')::numeric;

        -- 3. Validación de seguridad
        IF treboles_comprados IS NULL THEN
            RAISE EXCEPTION 'Error: clovers_amount no encontrado en extra_data';
        END IF;

        -- 4. Actualizamos el saldo en el perfil del usuario
        UPDATE public.profiles
        SET clovers = COALESCE(clovers, 0) + treboles_comprados
        WHERE id = NEW.user_id;

        -- 5. Registramos el movimiento en el Ledger para auditoría
        INSERT INTO public.wallet_ledger (user_id, order_id, amount, description)
        VALUES (
            NEW.user_id, 
            NEW.id, 
            treboles_comprados, 
            'Compra de tréboles - Ref: ' || NEW.pago_pago_order_id
        );
    END IF;

    RETURN NEW;
END;
$function$
;

create or replace view "public"."profiles_public" as  SELECT id,
    name,
    avatar_id,
    level,
    total_xp,
    profession
   FROM public.profiles;


CREATE OR REPLACE FUNCTION public.register_race_finisher(p_event_id uuid, p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_event_status text;
  v_configured_winners int;
  v_total_participants int;
  v_winners_count int;
  v_user_status text;
  v_position int;
  v_prize_amount int;
  v_current_placement int;
BEGIN
  -- A. Lock Event
  SELECT status, configured_winners
  INTO v_event_status, v_configured_winners
  FROM events
  WHERE id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Evento no encontrado');
  END IF;

  -- B. Validate User Status
  SELECT status, final_placement INTO v_user_status, v_current_placement
  FROM game_players
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- If already completed, return existing data
  IF v_user_status = 'completed' THEN
     SELECT amount INTO v_prize_amount
     FROM prize_distributions
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object(
        'success', true,
        'message', 'Ya has completado esta carrera',
        'position', v_current_placement,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
     );
  END IF;

  -- If event already completed and user is NOT completed, mark them late
  IF v_event_status = 'completed' THEN
     SELECT COUNT(*) INTO v_winners_count
     FROM game_players WHERE event_id = p_event_id AND status = 'completed';
     v_position := v_winners_count + 1;

     UPDATE game_players
     SET status = 'completed',
         finish_time = NOW(),
         final_placement = v_position,
         completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id)
     WHERE event_id = p_event_id AND user_id = p_user_id;

     RETURN json_build_object('success', true, 'position', v_position, 'prize', 0, 'race_completed', true);
  END IF;

  IF v_user_status != 'active' THEN
     RETURN json_build_object('success', false, 'message', 'Usuario no activo en el evento');
  END IF;

  -- C. Count current winners
  SELECT COUNT(*) INTO v_winners_count
  FROM game_players
  WHERE event_id = p_event_id AND status = 'completed';

  -- If podium already full (race condition edge case), reject
  IF v_winners_count >= v_configured_winners THEN
     UPDATE events SET status = 'completed', completed_at = NOW() WHERE id = p_event_id AND status != 'completed';
     RETURN json_build_object('success', false, 'message', 'Podio completo', 'race_completed', true);
  END IF;

  -- D. Calculate Position
  v_position := v_winners_count + 1;

  -- E. Register Completion with Position
  UPDATE game_players
  SET
    status = 'completed',
    finish_time = NOW(),
    completed_clues_count = (SELECT COUNT(*) FROM clues WHERE event_id = p_event_id),
    final_placement = v_position
  WHERE event_id = p_event_id AND user_id = p_user_id;

  -- ══════════════════════════════════════════════════════════
  -- FIX: REMOVED direct call to resolve_event_bets at position=1.
  -- Bet resolution is now handled ONLY by distribute_event_prizes
  -- (centralized, after all placements are finalized).
  -- The previous direct call here caused:
  --   1. Redundant resolution (also called by distribute_event_prizes)
  --   2. Auth failure (player's JWT ≠ admin → Access Denied)
  -- ══════════════════════════════════════════════════════════

  -- F. Check if event should close (Podium Full OR Last Participant)
  SELECT COUNT(*) INTO v_total_participants
  FROM game_players
  WHERE event_id = p_event_id
  AND status IN ('active', 'completed');

  IF (v_position >= v_configured_winners) OR (v_position >= v_total_participants) THEN
      -- Distribute prizes (handles event finalization, placements, prizes, AND bets)
      PERFORM distribute_event_prizes(p_event_id);

      -- Retrieve prize for this user
      SELECT amount INTO v_prize_amount
      FROM prize_distributions
      WHERE event_id = p_event_id AND user_id = p_user_id;

      RETURN json_build_object(
        'success', true,
        'position', v_position,
        'prize', COALESCE(v_prize_amount, 0),
        'race_completed', true
      );
  END IF;

  -- Normal return (event not yet closed)
  RETURN json_build_object(
    'success', true,
    'position', v_position,
    'prize', 0,
    'race_completed', false
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_competition_final_v3(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_player_ids UUID[];
BEGIN
    -- 1. Capturar todos los IDs de game_players vinculados al evento
    SELECT array_agg(id) INTO v_player_ids 
    FROM public.game_players 
    WHERE event_id = p_event_id;

    -- 2. Borrar dependencias que usan game_player_id
    IF v_player_ids IS NOT NULL THEN
        DELETE FROM public.active_powers WHERE caster_id = ANY(v_player_ids) OR target_id = ANY(v_player_ids);
        DELETE FROM public.player_inventory WHERE game_player_id = ANY(v_player_ids);
        DELETE FROM public.player_powers WHERE game_player_id = ANY(v_player_ids);
        DELETE FROM public.transactions WHERE game_player_id = ANY(v_player_ids);
        DELETE FROM public.player_completed_challenges WHERE game_player_id = ANY(v_player_ids);
    END IF;

    -- 3. Borrar progreso de pistas (basado en user_id y clue_id)
    DELETE FROM public.user_clue_progress 
    WHERE clue_id IN (SELECT id FROM public.clues WHERE event_id = p_event_id);

    -- 4. Borrar registros de participación y solicitudes
    DELETE FROM public.game_players WHERE event_id = p_event_id;
    DELETE FROM public.game_requests WHERE event_id = p_event_id;

    -- 5. Resetear estado de los perfiles para que no queden bloqueados
    UPDATE public.profiles 
    SET is_playing = false, status = 'active' 
    WHERE id IN (
        SELECT user_id FROM public.game_players WHERE event_id = p_event_id
    );

    -- 6. Resetear el evento a su estado inicial
    UPDATE public.events 
    SET 
        winner_id = NULL, 
        completed_at = NULL, 
        is_completed = false, 
        status = 'pending' -- Lo ponemos en pending para forzar reinicio manual
    WHERE id = p_event_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_competition_final_v4(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- 1. Borrar progreso individual de pistas (user_clue_progress)
    -- Crucial: Esto limpia lo que el usuario 'ya hizo' en las pistas del evento
    DELETE FROM public.user_clue_progress 
    WHERE clue_id IN (SELECT id FROM public.clues WHERE event_id = p_event_id);

    -- 2. Borrar poderes activos y efectos en curso
    DELETE FROM public.active_powers WHERE event_id = p_event_id;

    -- 3. Borrar dependencias del jugador (inventario, poderes, retos, transacciones)
    -- Usamos una subconsulta para identificar a los jugadores de este evento específico
    DELETE FROM public.player_inventory WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_powers WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_completed_challenges WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.transactions WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);

    -- 4. Borrar la participación y las solicitudes de acceso
    DELETE FROM public.game_players WHERE event_id = p_event_id;
    DELETE FROM public.game_requests WHERE event_id = p_event_id;

    -- 5. Resetear perfiles globales
    -- IMPORTANTE: Cambiamos is_playing a false para que la app no los bloquee en el juego
    UPDATE public.profiles 
    SET is_playing = false, status = 'active' 
    WHERE id IN (
        SELECT user_id FROM public.game_players WHERE event_id = p_event_id
    );

    -- 6. Resetear el estado del evento principal
    UPDATE public.events 
    SET 
        winner_id = NULL, 
        completed_at = NULL, 
        is_completed = false, 
        status = 'pending' 
    WHERE id = p_event_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_competition_nuclear(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- 1. Eliminar poderes activos en el evento
    DELETE FROM public.active_powers WHERE event_id = p_event_id;

    -- 2. Limpiar el progreso de pistas de todos los usuarios vinculados a este evento
    DELETE FROM public.user_clue_progress 
    WHERE clue_id IN (SELECT id FROM public.clues WHERE event_id = p_event_id);

    -- 3. Limpiar inventarios, poderes y transacciones de los jugadores del evento
    DELETE FROM public.player_inventory WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_powers WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.transactions WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);
    DELETE FROM public.player_completed_challenges WHERE game_player_id IN (SELECT id FROM public.game_players WHERE event_id = p_event_id);

    -- 4. Eliminar la participación principal y solicitudes
    DELETE FROM public.game_players WHERE event_id = p_event_id;
    DELETE FROM public.game_requests WHERE event_id = p_event_id;

    -- 5. Resetear el estado del evento
    UPDATE public.events 
    SET 
        winner_id = NULL, 
        completed_at = NULL, 
        is_completed = false, 
        status = 'active' 
    WHERE id = p_event_id;

    -- 6. Opcional: Resetear el flag is_playing en los perfiles de los usuarios afectados
    -- Esto ayuda si la app bloquea al usuario en "modo juego"
    UPDATE public.profiles 
    SET is_playing = false 
    WHERE id IN (SELECT user_id FROM public.game_players WHERE event_id = p_event_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_lives(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_game_player_id uuid;
BEGIN
  SELECT id INTO v_game_player_id
  FROM public.game_players
  WHERE user_id = p_user_id
  ORDER BY joined_at DESC
  LIMIT 1;

  IF v_game_player_id IS NULL THEN RETURN 0; END IF;

  UPDATE public.game_players
  SET lives = 3
  WHERE id = v_game_player_id;

  RETURN 3;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_lives(p_user_id uuid, p_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.game_players
  SET lives = 3
  WHERE user_id = p_user_id AND event_id = p_event_id;

  RETURN 3;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_event_bets(p_event_id uuid, p_winner_racer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_total_pool        INTEGER;
    v_ticket_price      INTEGER;
    v_winners_count     INTEGER;
    v_net_profit        INTEGER;
    v_commission_pct    INTEGER;
    v_commission        INTEGER;
    v_distributable     INTEGER;
    v_payout            INTEGER;
    v_dust              INTEGER;
    v_runner_total      INTEGER;
    v_runner_user_id    UUID;
    v_event_title       TEXT;
BEGIN
    -- ══════════════════════════════════════════════
    -- SECURITY NOTE: No auth check here.
    -- This function is SECURITY DEFINER and MUST only be called
    -- internally by distribute_event_prizes (also SECURITY DEFINER).
    -- No GRANT to 'authenticated' exists, so direct RPC calls are
    -- blocked by PostgREST. The previous admin-only check using
    -- auth.role() / is_admin(auth.uid()) blocked ALL internal calls
    -- when triggered by a normal player finishing the race.
    -- ══════════════════════════════════════════════

    -- ──────────────────────────────────────────────
    -- 1. IDEMPOTENCY: Check if bets were already resolved
    -- ──────────────────────────────────────────────
    IF EXISTS (
        SELECT 1 FROM public.wallet_ledger
        WHERE metadata->>'type' IN ('bet_payout', 'runner_bet_commission')
          AND metadata->>'event_id' = p_event_id::text
        LIMIT 1
    ) THEN
        RETURN jsonb_build_object('success', true, 'message', 'Bets already resolved for this event.');
    END IF;

    -- ──────────────────────────────────────────────
    -- 2. LOAD EVENT DATA
    -- ──────────────────────────────────────────────
    SELECT title, bet_ticket_price, COALESCE(runner_bet_commission_pct, 10)
    INTO v_event_title, v_ticket_price, v_commission_pct
    FROM public.events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Event not found');
    END IF;

    -- p_winner_racer_id IS a user_id (profiles.id).
    -- Verify the player exists in the event:
    SELECT user_id INTO v_runner_user_id
    FROM public.game_players
    WHERE event_id = p_event_id AND user_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 3. CALCULATE TOTAL POOL
    -- ──────────────────────────────────────────────
    SELECT COALESCE(SUM(amount), 0) INTO v_total_pool
    FROM public.bets
    WHERE event_id = p_event_id;

    IF v_total_pool = 0 THEN
        RETURN jsonb_build_object('success', true, 'message', 'No bets placed, no payout.');
    END IF;

    -- ──────────────────────────────────────────────
    -- 4. COUNT WINNING TICKETS
    --    bets.racer_id stores user_id (profiles.id)
    -- ──────────────────────────────────────────────
    SELECT COUNT(*) INTO v_winners_count
    FROM public.bets
    WHERE event_id = p_event_id AND racer_id = p_winner_racer_id;

    -- ──────────────────────────────────────────────
    -- 5. HOUSE WIN: Nobody bet on the winner
    -- ──────────────────────────────────────────────
    IF v_winners_count = 0 THEN
        v_runner_total := FLOOR(v_total_pool * v_commission_pct / 100.0)::INTEGER;

        IF v_runner_total > 0 AND v_runner_user_id IS NOT NULL THEN
            UPDATE public.profiles
            SET clovers = COALESCE(clovers, 0) + v_runner_total
            WHERE id = v_runner_user_id;

            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
                v_runner_user_id,
                v_runner_total,
                'Comisión Apuestas (House Win): ' || COALESCE(v_event_title, 'Evento'),
                jsonb_build_object(
                    'type', 'runner_bet_commission',
                    'event_id', p_event_id,
                    'scenario', 'house_win',
                    'total_pool', v_total_pool,
                    'commission_pct', v_commission_pct
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'scenario', 'house_win',
            'total_pool', v_total_pool,
            'commission_pct', v_commission_pct,
            'runner_commission', v_runner_total,
            'house_profit', v_total_pool - COALESCE(v_runner_total, 0),
            'payout_per_ticket', 0,
            'total_winners', 0
        );
    END IF;

    -- ──────────────────────────────────────────────
    -- 6. CALCULATE NET PROFIT
    -- ──────────────────────────────────────────────
    v_net_profit := v_total_pool - (v_winners_count * v_ticket_price);

    -- ──────────────────────────────────────────────
    -- 7. UNANIMOUS CASE: All bettors chose the winner
    -- ──────────────────────────────────────────────
    IF v_net_profit <= 0 THEN
        v_payout := v_ticket_price;
        v_commission := 0;
        v_runner_total := 0;
        v_dust := v_total_pool - (v_payout * v_winners_count);

        -- Credit each winning bettor (refund)
        WITH winners AS (
            SELECT user_id
            FROM public.bets
            WHERE event_id = p_event_id AND racer_id = p_winner_racer_id
        ),
        updated_profiles AS (
            UPDATE public.profiles
            SET clovers = clovers + v_payout
            FROM winners
            WHERE profiles.id = winners.user_id
            RETURNING profiles.id
        )
        INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
        SELECT
            user_id,
            v_payout,
            'Apuesta Devuelta (Unánime): ' || COALESCE(v_event_title, 'Evento'),
            jsonb_build_object(
                'type', 'bet_payout',
                'event_id', p_event_id,
                'scenario', 'unanimous',
                'racer_id', p_winner_racer_id
            )
        FROM winners;

        -- Dust to runner
        IF v_dust > 0 AND v_runner_user_id IS NOT NULL THEN
            v_runner_total := v_dust;
            UPDATE public.profiles
            SET clovers = COALESCE(clovers, 0) + v_dust
            WHERE id = v_runner_user_id;

            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
                v_runner_user_id,
                v_dust,
                'Comisión Apuestas (Residuo): ' || COALESCE(v_event_title, 'Evento'),
                jsonb_build_object(
                    'type', 'runner_bet_commission',
                    'event_id', p_event_id,
                    'scenario', 'unanimous_dust'
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'scenario', 'unanimous',
            'total_pool', v_total_pool,
            'net_profit', 0,
            'runner_commission', v_runner_total,
            'payout_per_ticket', v_payout,
            'total_winners', v_winners_count
        );
    END IF;

    -- ──────────────────────────────────────────────
    -- 8. NORMAL CASE: Commission from net profit
    -- ──────────────────────────────────────────────
    v_commission    := FLOOR(v_net_profit * v_commission_pct / 100.0)::INTEGER;
    v_distributable := v_total_pool - v_commission;
    v_payout        := FLOOR(v_distributable::NUMERIC / v_winners_count)::INTEGER;
    v_dust          := v_distributable - (v_payout * v_winners_count);
    v_runner_total  := v_commission + v_dust;

    -- 8a. Credit each winning bettor
    WITH winners AS (
        SELECT user_id
        FROM public.bets
        WHERE event_id = p_event_id AND racer_id = p_winner_racer_id
    ),
    updated_profiles AS (
        UPDATE public.profiles
        SET clovers = clovers + v_payout
        FROM winners
        WHERE profiles.id = winners.user_id
        RETURNING profiles.id
    )
    INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
    SELECT
        user_id,
        v_payout,
        'Apuesta Ganada: ' || COALESCE(v_event_title, 'Evento'),
        jsonb_build_object(
            'type', 'bet_payout',
            'event_id', p_event_id,
            'scenario', 'normal',
            'racer_id', p_winner_racer_id
        )
    FROM winners;

    -- 8b. Credit runner (commission + dust)
    IF v_runner_total > 0 AND v_runner_user_id IS NOT NULL THEN
        UPDATE public.profiles
        SET clovers = COALESCE(clovers, 0) + v_runner_total
        WHERE id = v_runner_user_id;

        INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
        VALUES (
            v_runner_user_id,
            v_runner_total,
            'Comisión Apuestas: ' || COALESCE(v_event_title, 'Evento'),
            jsonb_build_object(
                'type', 'runner_bet_commission',
                'event_id', p_event_id,
                'scenario', 'normal',
                'net_profit', v_net_profit,
                'commission_pct', v_commission_pct,
                'commission_base', v_commission,
                'dust', v_dust
            )
        );
    END IF;

    -- INVARIANT: (v_payout * v_winners_count) + v_runner_total = v_total_pool
    RETURN jsonb_build_object(
        'success', true,
        'scenario', 'normal',
        'total_pool', v_total_pool,
        'net_profit', v_net_profit,
        'commission_pct', v_commission_pct,
        'runner_commission', v_runner_total,
        'payout_per_ticket', v_payout,
        'total_winners', v_winners_count,
        'dust', v_dust
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.safe_reset_event(target_event_id uuid, admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event_exists  boolean;
  v_event_status  text;
  v_clue_count_before integer;
  v_clue_count_after  integer;
  v_gp_ids        uuid[];
  v_clue_ids      bigint[];
  v_deleted_progress  integer := 0;
  v_deleted_powers    integer := 0;
  v_deleted_active    integer := 0;
  v_deleted_transactions integer := 0;
  v_deleted_combat    integer := 0;
  v_deleted_bets      integer := 0;
  v_deleted_prizes    integer := 0;
  v_deleted_players   integer := 0;
  v_deleted_requests  integer := 0;
BEGIN
  -- =====================================================================
  -- STEP 0: VALIDATE EVENT EXISTS
  -- =====================================================================
  SELECT EXISTS(SELECT 1 FROM events WHERE id = target_event_id)
    INTO v_event_exists;

  IF NOT v_event_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'EVENT_NOT_FOUND',
      'message', format('No existe un evento con id %s', target_event_id)
    );
  END IF;

  -- Get current status
  SELECT status INTO v_event_status
    FROM events WHERE id = target_event_id;

  -- =====================================================================
  -- STEP 1: SNAPSHOT — Count structural data BEFORE reset
  -- This is our integrity anchor. Clues must survive untouched.
  -- =====================================================================
  SELECT count(*) INTO v_clue_count_before
    FROM clues WHERE event_id = target_event_id;

  -- =====================================================================
  -- STEP 2: COLLECT IDs — Gather game_player and clue IDs
  -- =====================================================================
  SELECT array_agg(id) INTO v_gp_ids
    FROM game_players WHERE event_id = target_event_id;

  SELECT array_agg(id) INTO v_clue_ids
    FROM clues WHERE event_id = target_event_id;

  -- =====================================================================
  -- STEP 3: DELETE TRANSACTIONAL DATA (child tables first)
  -- ORDER MATTERS: Delete children before parents to respect FK constraints.
  -- =====================================================================

  -- 3a. User clue progress (depends on clues)
  IF v_clue_ids IS NOT NULL AND array_length(v_clue_ids, 1) > 0 THEN
    DELETE FROM user_clue_progress WHERE clue_id = ANY(v_clue_ids);
    GET DIAGNOSTICS v_deleted_progress = ROW_COUNT;
  END IF;

  -- 3b. Player-level data (depends on game_players)
  IF v_gp_ids IS NOT NULL AND array_length(v_gp_ids, 1) > 0 THEN
    -- Player powers inventory
    DELETE FROM player_powers WHERE game_player_id = ANY(v_gp_ids);
    GET DIAGNOSTICS v_deleted_powers = ROW_COUNT;

    -- Transactions log
    DELETE FROM transactions WHERE game_player_id = ANY(v_gp_ids);
    GET DIAGNOSTICS v_deleted_transactions = ROW_COUNT;

    -- Combat events (also handled by CASCADE, but explicit is safer)
    DELETE FROM combat_events
      WHERE attacker_id = ANY(v_gp_ids) OR target_id = ANY(v_gp_ids);
    GET DIAGNOSTICS v_deleted_combat = ROW_COUNT;
  END IF;

  -- 3c. Event-level transactional data
  DELETE FROM active_powers WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_active = ROW_COUNT;

  DELETE FROM bets WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_bets = ROW_COUNT;

  DELETE FROM prize_distributions WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_prizes = ROW_COUNT;

  -- 3d. Player registrations (parent of player_powers, transactions, etc.)
  DELETE FROM game_players WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_players = ROW_COUNT;

  -- 3e. Join requests
  DELETE FROM game_requests WHERE event_id = target_event_id;
  GET DIAGNOSTICS v_deleted_requests = ROW_COUNT;

  -- =====================================================================
  -- STEP 4: RESET EVENT STATUS (soft reset, no DELETE)
  -- =====================================================================
  UPDATE events
    SET status       = 'pending',
        winner_id    = NULL,
        completed_at = NULL,
        is_completed = false,
        pot          = 0
    WHERE id = target_event_id;

  -- =====================================================================
  -- STEP 5: INTEGRITY VERIFICATION — Clues must be intact
  -- =====================================================================
  SELECT count(*) INTO v_clue_count_after
    FROM clues WHERE event_id = target_event_id;

  IF v_clue_count_before <> v_clue_count_after THEN
    -- THIS SHOULD NEVER HAPPEN. If it does, abort everything.
    RAISE EXCEPTION 'INTEGRITY VIOLATION: Clue count changed from % to % during reset. Transaction rolled back.',
      v_clue_count_before, v_clue_count_after;
  END IF;

  -- =====================================================================
  -- STEP 6: AUDIT LOG — Record who did what
  -- =====================================================================
  INSERT INTO admin_audit_logs (admin_id, action_type, target_table, target_id, details)
  VALUES (
    admin_id,
    'event_reset',
    'events',
    target_event_id,
    jsonb_build_object(
      'previous_status', v_event_status,
      'clues_preserved', v_clue_count_after,
      'deleted_progress', v_deleted_progress,
      'deleted_player_powers', v_deleted_powers,
      'deleted_active_powers', v_deleted_active,
      'deleted_transactions', v_deleted_transactions,
      'deleted_combat_events', v_deleted_combat,
      'deleted_bets', v_deleted_bets,
      'deleted_prizes', v_deleted_prizes,
      'deleted_players', v_deleted_players,
      'deleted_requests', v_deleted_requests
    )
  );

  -- =====================================================================
  -- STEP 7: RETURN SUMMARY
  -- =====================================================================
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Evento reiniciado de forma segura',
    'event_id', target_event_id,
    'previous_status', v_event_status,
    'clues_preserved', v_clue_count_after,
    'summary', jsonb_build_object(
      'progress_cleared', v_deleted_progress,
      'players_removed', v_deleted_players,
      'requests_removed', v_deleted_requests,
      'powers_cleared', v_deleted_powers + v_deleted_active,
      'transactions_cleared', v_deleted_transactions,
      'combat_logs_cleared', v_deleted_combat,
      'bets_cleared', v_deleted_bets,
      'prizes_cleared', v_deleted_prizes
    )
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.secure_clover_payment(p_user_id uuid, p_amount bigint, p_reason text DEFAULT 'clover_payment'::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_current BIGINT;
  v_new BIGINT;
  v_caller_id UUID;
  v_caller_role TEXT;
BEGIN
  v_caller_id := auth.uid();

  -- Security gate:
  -- - NULL auth.uid() (internal/service context): allowed
  -- - Same user: allowed
  -- - Different user: only allowed for admin
  IF v_caller_id IS NOT NULL AND p_user_id != v_caller_id THEN
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS DISTINCT FROM 'admin' THEN
      RAISE EXCEPTION 'Security Violation: Cannot debit another user.';
    END IF;
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_AMOUNT');
  END IF;

  SELECT COALESCE(clovers, 0)::BIGINT INTO v_current
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_current IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  IF v_current < p_amount THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INSUFFICIENT_CLOVERS',
      'current', v_current,
      'required', p_amount
    );
  END IF;

  v_new := v_current - p_amount;

  UPDATE public.profiles
  SET clovers = v_new
  WHERE id = p_user_id;

  INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
  VALUES (
    p_user_id,
    -p_amount,
    p_reason,
    jsonb_build_object('type', 'clover_payment')
  );

  RETURN json_build_object('success', true, 'new_balance', v_new);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.skip_clue_rpc(p_clue_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_user_id UUID;
    v_clue RECORD;
    v_next_clue RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- 1. Obtener datos de la pista
    SELECT * INTO v_clue FROM clues WHERE id = p_clue_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Clue not found');
    END IF;

    -- 2. Marcar pista como completada (skip)
    INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked, completed_at)
    VALUES (v_user_id, p_clue_id, true, false, NOW())
    ON CONFLICT (user_id, clue_id)
    DO UPDATE SET is_completed = true, completed_at = NOW(), is_locked = false;

    -- 3. Desbloquear siguiente pista
    SELECT id INTO v_next_clue
    FROM clues
    WHERE event_id = v_clue.event_id AND sequence_index > v_clue.sequence_index
    ORDER BY sequence_index ASC
    LIMIT 1;

    IF v_next_clue IS NOT NULL THEN
        INSERT INTO user_clue_progress (user_id, clue_id, is_completed, is_locked)
        VALUES (v_user_id, v_next_clue.id, false, false)
        ON CONFLICT (user_id, clue_id)
        DO UPDATE SET is_locked = false;
    END IF;

    -- [FIX] Increment progress in game_players
    UPDATE game_players
    SET 
        completed_clues_count = completed_clues_count + 1,
        last_active = NOW()
    WHERE user_id = v_user_id AND event_id = v_clue.event_id;

    RETURN jsonb_build_object('success', true, 'message', 'Clue skipped');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.start_event(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event RECORD;
  v_caller_role TEXT;
BEGIN
  -- 1. Validate caller is admin/staff or service_role
  IF (auth.jwt() ->> 'role') = 'service_role' THEN
    v_caller_role := 'service_role';
  ELSE
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'user_staff') THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Solo administradores pueden iniciar eventos.';
    END IF;
  END IF;

  -- 2. Fetch the event and validate it exists
  SELECT id, status, title
  INTO v_event
  FROM public.events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EVENT_NOT_FOUND: El evento % no existe.', p_event_id;
  END IF;

  -- 3. Validate the event is in 'pending' state
  IF v_event.status != 'pending' THEN
    RAISE EXCEPTION 'INVALID_STATE: El evento ya está en estado "%". Solo se pueden iniciar eventos en estado "pending".', v_event.status;
  END IF;

  -- 4. Atomically update the event status to 'active'
  UPDATE public.events
  SET status = 'active'
  WHERE id = p_event_id
  AND status = 'pending'; -- Double-check for race condition

  RETURN jsonb_build_object(
    'success', true,
    'event_id', p_event_id,
    'event_title', v_event.title,
    'activated_by', v_caller_role
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_c_order_plan_to_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- When an order is paid/success
    IF NEW.status IN ('success', 'paid') AND (OLD.status NOT IN ('success', 'paid') OR OLD.status IS NULL) THEN
        -- Update the corresponding ledger entry
        -- We wait a tiny bit or just allow that the ledger entry might be created by another trigger momentarily
        -- Ideally, we update the row that matches.
        UPDATE public.wallet_ledger
        SET metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{plan_id}',
            to_jsonb(NEW.plan_id)
        )
        WHERE (metadata->>'order_id' = NEW.pago_pago_order_id OR metadata->>'order_id' = NEW.id::text)
          AND (metadata->>'plan_id') IS NULL;
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_ban(user_id uuid, new_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  caller_role TEXT;
BEGIN
  -- 1. Verificamos quién está llamando a la función
  SELECT role INTO caller_role FROM profiles WHERE id = auth.uid();

  -- 2. Si no es admin, bloqueamos la ejecución
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RAISE EXCEPTION 'Forbidden: Admin role required';
  END IF;

  -- 3. Si es admin, procedemos
  UPDATE profiles SET status = new_status WHERE id = user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_event_member_ban(p_user_id uuid, p_event_id uuid, p_new_status text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- ☢️ NUCLEAR OPTION: Desactivar TODOS los triggers temporalmente
  ALTER TABLE public.game_players DISABLE TRIGGER ALL;

  UPDATE public.game_players
  SET status = p_new_status
  WHERE user_id = p_user_id AND event_id = p_event_id;

  -- Reactivar triggers
  ALTER TABLE public.game_players ENABLE TRIGGER ALL;

  IF FOUND THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Seguridad: Reactivar triggers si algo falla
  ALTER TABLE public.game_players ENABLE TRIGGER ALL;
  RAISE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_event_member_ban_v2(p_user_id uuid, p_event_id uuid, p_new_status text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- ☢️ NUCLEAR OPTION V2.1: Desactivar solo TRIGGERS DE USUARIO
  -- 'USER' apaga solo los triggers creados por nosotros (el culpable).
  ALTER TABLE public.game_players DISABLE TRIGGER USER;

  UPDATE public.game_players
  SET status = p_new_status
  WHERE user_id = p_user_id AND event_id = p_event_id;

  -- Reactivar triggers
  ALTER TABLE public.game_players ENABLE TRIGGER USER;

  IF FOUND THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Seguridad: Reactivar triggers si algo falla
  ALTER TABLE public.game_players ENABLE TRIGGER USER;
  RAISE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trigger_auto_online_event()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_url        text;
  v_key        text;
  v_enabled    boolean;
  v_req_id     bigint;
BEGIN
  -- 1a. Fast-exit: skip if automation is disabled (avoids unnecessary HTTP call)
  SELECT (value ->> 'enabled')::boolean
  INTO v_enabled
  FROM public.app_config
  WHERE key = 'online_automation_config';

  IF v_enabled IS NOT TRUE THEN
    RETURN;
  END IF;

  -- 1b. Read Edge Function URL and service key from Vault
  SELECT decrypted_secret INTO v_url
  FROM vault.decrypted_secrets
  WHERE name = 'automate_func_url';

  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets
  WHERE name = 'automate_func_key';

  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE WARNING '[trigger_auto_online_event] Vault secrets not found. Skipping.';
    RETURN;
  END IF;

  -- 1c. Call the Edge Function asynchronously via pg_net
  SELECT net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := '{}'::jsonb
  ) INTO v_req_id;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.trigger_bcv_update()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.update_auto_event_settings(p_settings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Validate admin or staff
  IF NOT (
    (auth.jwt() ->> 'role' = 'service_role') OR 
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'user_staff'))
  ) THEN
    RAISE EXCEPTION 'Solo administradores pueden cambiar la configuración';
  END IF;

  INSERT INTO public.app_config (key, value, updated_at, updated_by)
  VALUES ('online_automation_config', p_settings, now(), auth.uid())
  ON CONFLICT (key) DO UPDATE 
  SET value = EXCLUDED.value, updated_at = now(), updated_by = EXCLUDED.updated_by;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_game_progress(p_game_id uuid, p_user_id uuid, p_coins_reward integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.game_players
  SET 
    current_challenge_index = current_challenge_index + 1,
    coins = coins + p_coins_reward,
    updated_at = now() -- Asumiendo que tienes updated_at, si no, borra esta línea
  WHERE game_id = p_game_id AND user_id = p_user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.use_life_steal_atomic(p_caster_gp_id uuid, p_target_gp_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.use_power_mechanic(p_caster_id uuid, p_target_id uuid, p_power_slug text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_power_id uuid;
    v_power_duration int;
    v_power_cost int;
    v_event_id uuid;
    v_now timestamptz := timezone('utc', now());
    v_caster_is_protected boolean; 
    v_target_is_protected boolean;
    v_defense_slug text;
    v_final_caster uuid := p_caster_id;
    v_final_target uuid := p_target_id;
    v_returned boolean := false;
    v_returned_by_name text;
    v_target_lives int;
    v_caster_role text;
    -- Commission variables
    v_spectator_config jsonb;
    v_commission int;
    v_target_user_id uuid;
    -- Gift max quantity check
    v_target_current_qty int;
    v_max_power_quantity int := 3;
BEGIN
    -- 0. SECURITY: Validate caller owns the caster
    IF NOT EXISTS (
        SELECT 1 FROM public.game_players gp
        WHERE gp.id = p_caster_id AND gp.user_id = auth.uid()
    ) THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized');
    END IF;

    -- 1. OBTENCIÓN DE DATOS BÁSICOS
    SELECT event_id, status INTO v_event_id, v_caster_role 
    FROM public.game_players WHERE id = p_caster_id;
    
    -- Obtener ID, duración y costo del poder usado
    SELECT id, duration, cost INTO v_power_id, v_power_duration, v_power_cost 
    FROM public.powers WHERE slug = p_power_slug;
    
    IF v_power_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'power_not_found');
    END IF;

    -- 1.5 BLOQUEO: Espectadores NO pueden usar blur_screen (AoE)
    -- blur_screen afecta a todos los jugadores simultáneamente, lo cual
    -- genera un desbalance económico con el sistema de comisiones.
    IF v_caster_role = 'spectator' AND p_power_slug = 'blur_screen' THEN
        RETURN json_build_object('success', false, 'error', 'spectator_blur_blocked');
    END IF;

    -- 2. CONSUMO DE MUNICIÓN
    UPDATE public.player_powers 
    SET quantity = quantity - 1, last_used_at = v_now
    WHERE game_player_id = p_caster_id AND power_id = v_power_id AND quantity > 0;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'no_ammo');
    END IF;

    -- ============================================================
    -- 2.5 COMISIÓN POR ATAQUE DE ESPECTADOR (50% al competidor)
    -- Aplica siempre que: caster es spectator, poder es de ataque
    -- (freeze, black_screen, life_steal) y NO blur_screen.
    -- Se aplica ANTES de escudo/return para que siempre se pague.
    -- ============================================================
    IF v_caster_role = 'spectator' 
       AND p_power_slug IN ('freeze', 'black_screen', 'life_steal') 
    THEN
        -- Obtener user_id del target (competidor atacado)
        SELECT user_id INTO v_target_user_id 
        FROM public.game_players WHERE id = p_target_id;

        -- Obtener costo desde spectator_config del evento (override) o usar powers.cost
        SELECT spectator_config INTO v_spectator_config
        FROM public.events WHERE id = v_event_id;

        IF v_spectator_config IS NOT NULL AND (v_spectator_config->>p_power_slug) IS NOT NULL THEN
            v_power_cost := (v_spectator_config->>p_power_slug)::INT;
        END IF;

        -- Calcular comisión: 50% en tréboles enteros
        v_commission := FLOOR(v_power_cost / 2.0)::INT;

        IF v_commission > 0 AND v_target_user_id IS NOT NULL THEN
            -- Acreditar tréboles al competidor atacado
            UPDATE public.profiles 
            SET clovers = COALESCE(clovers, 0) + v_commission 
            WHERE id = v_target_user_id;

            -- Registrar en wallet_ledger para auditoría
            INSERT INTO public.wallet_ledger (user_id, amount, description, metadata)
            VALUES (
                v_target_user_id, 
                v_commission, 
                'Comisión por ataque recibido: ' || p_power_slug,
                jsonb_build_object(
                    'type', 'attack_commission',
                    'power_slug', p_power_slug,
                    'power_cost', v_power_cost,
                    'commission_rate', 0.5,
                    'event_id', v_event_id,
                    'attacker_game_player_id', p_caster_id
                )
            );
        END IF;
    END IF;

    -- 3. DEFENSE POWERS (Shield, Return, Invisibility)
    IF p_power_slug IN ('shield', 'return', 'invisibility') THEN
        
        -- A. GIFTING LOGIC (If caster != target)
        -- Spectators (or players) targeting someone else GIFT the item.
        IF p_caster_id != p_target_id THEN
             -- *** MAX QUANTITY CHECK ***
             -- Check if target already has max quantity of this power
             SELECT COALESCE(quantity, 0) INTO v_target_current_qty
             FROM public.player_powers
             WHERE game_player_id = p_target_id AND power_id = v_power_id;

             IF v_target_current_qty >= v_max_power_quantity THEN
                 -- Refund ammo to caster (we consumed it in step 2)
                 UPDATE public.player_powers 
                 SET quantity = quantity + 1 
                 WHERE game_player_id = p_caster_id AND power_id = v_power_id;

                 RETURN json_build_object(
                     'success', false, 
                     'error', 'target_inventory_full',
                     'power_slug', p_power_slug,
                     'current_qty', v_target_current_qty,
                     'max_qty', v_max_power_quantity
                 );
             END IF;

             -- Add to target's inventory
             INSERT INTO public.player_powers (game_player_id, power_id, quantity)
             VALUES (p_target_id, v_power_id, 1)
             ON CONFLICT (game_player_id, power_id) 
             DO UPDATE SET quantity = public.player_powers.quantity + 1;

             -- Log Gift
             INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
             VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'gifted');

             RETURN json_build_object('success', true, 'gifted', true);
        END IF;

        -- B. ACTIVATION LOGIC (Self-Cast)
        -- Proceed with existing activation logic for self-targeting
        
        -- Get Target's Protection Status (The intended beneficiary - Self)
        SELECT is_protected INTO v_target_is_protected 
        FROM public.game_players WHERE id = p_target_id;

        -- Check if ALREADY protected (Mutual Exclusion for ALL defense powers on TARGET)
        IF v_target_is_protected THEN
             -- Refund ammo to Caster
             UPDATE public.player_powers SET quantity = quantity + 1 
             WHERE game_player_id = p_caster_id AND power_id = v_power_id;
             RETURN json_build_object('success', false, 'error', 'target_already_protected');
        END IF;

        -- Activate Protection on TARGET
        UPDATE public.game_players SET is_protected = true, updated_at = now() 
        WHERE id = p_target_id;

        -- Insert into active_powers for UI/Logging
        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 
                CASE 
                    WHEN p_power_slug = 'shield' THEN v_now + interval '1 year'
                    WHEN p_power_slug = 'return' THEN v_now + interval '1 year'
                    ELSE v_now + (COALESCE(v_power_duration, 20) || ' seconds')::interval
                END);
        
        RETURN json_build_object(
            'success', true, 
            'action', p_power_slug || '_activated',
            'defense_slug', p_power_slug,
            'target_id', p_target_id
        );
    END IF;

    -- 4. ATAQUE DE ÁREA (Blur Screen) - Solo jugadores, NO espectadores
    IF p_power_slug = 'blur_screen' THEN
        DECLARE
            v_aoe_target_id uuid;
            v_aoe_is_protected boolean;
            v_aoe_defense_slug text;
            v_aoe_final_caster uuid;
            v_aoe_final_target uuid;
            v_aoe_returned boolean;
            v_aoe_returned_by_name text;
        BEGIN
            FOR v_aoe_target_id IN 
                SELECT id FROM public.game_players 
                WHERE event_id = v_event_id AND id != p_caster_id AND status != 'spectator'
            LOOP
                v_aoe_returned := false;
                v_aoe_final_caster := p_caster_id;
                v_aoe_final_target := v_aoe_target_id;

                -- Check Protection
                SELECT is_protected INTO v_aoe_is_protected FROM public.game_players WHERE id = v_aoe_target_id;
                
                IF v_aoe_is_protected THEN
                    -- Identify Defense Type
                    SELECT power_slug INTO v_aoe_defense_slug FROM public.active_powers 
                    WHERE target_id = v_aoe_target_id AND power_slug IN ('shield', 'return', 'invisibility') 
                    ORDER BY created_at DESC LIMIT 1;
                    
                    -- Consume Protection
                    UPDATE public.game_players SET is_protected = false, updated_at = now() 
                    WHERE id = v_aoe_target_id;
                    -- Clean Visuals
                    DELETE FROM public.active_powers 
                    WHERE target_id = v_aoe_target_id 
                      AND power_slug IN ('shield', 'return', 'invisibility');
                    
                    -- Handle Return vs Shield/Invisibility
                    IF v_aoe_defense_slug = 'return' THEN
                         v_aoe_returned := true;
                         v_aoe_final_caster := v_aoe_target_id;
                         v_aoe_final_target := p_caster_id;
                         
                         INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                         VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'reflected');
                         
                         SELECT name INTO v_aoe_returned_by_name FROM public.profiles 
                         WHERE id = (SELECT user_id FROM public.game_players WHERE id = v_aoe_target_id);
                    ELSE
                        -- Log standard block (Shield or Invisibility)
                        INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                        VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'shield_blocked');
                    END IF;
                END IF;

                -- Apply Effect (If not protected OR if Returned)
                IF NOT v_aoe_is_protected THEN
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                    
                    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
                    VALUES (v_event_id, p_caster_id, v_aoe_target_id, v_power_id, p_power_slug, 'success');
                ELSIF v_aoe_returned THEN
                    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
                    VALUES (v_event_id, v_aoe_final_caster, v_aoe_final_target, v_power_id, p_power_slug, 
                            v_now + (COALESCE(v_power_duration, 15) || ' seconds')::interval);
                END IF;
                
            END LOOP;
            
            RETURN json_build_object('success', true, 'message', 'broadcast_complete');
        END;
    END IF;
    
    -- 5. Check if target is protected (Centralized Check for Direct Attacks)
    SELECT is_protected INTO v_target_is_protected FROM public.game_players WHERE id = p_target_id;

    -- Handle Invisibility (Special case: invisible targets can't be targeted directly)
    IF EXISTS (SELECT 1 FROM public.active_powers WHERE target_id = p_target_id AND power_slug = 'invisibility' AND expires_at > v_now) THEN
        UPDATE public.player_powers SET quantity = quantity + 1 WHERE game_player_id = p_caster_id AND power_id = v_power_id;
        RETURN json_build_object('success', false, 'error', 'target_invisible');
    END IF;

    -- BLOCK BY PROTECTION (Shield, Return, or Invisibility acting as defense)
    IF v_target_is_protected THEN
        
        -- Determine TYPE of protection from active_powers
        SELECT power_slug INTO v_defense_slug FROM public.active_powers 
        WHERE target_id = p_target_id AND power_slug IN ('shield', 'return', 'invisibility') 
        ORDER BY created_at DESC LIMIT 1;

        -- Consume Protection Atomically
        UPDATE public.game_players SET is_protected = false, updated_at = now() WHERE id = p_target_id;
        
        -- Clean Visuals
        DELETE FROM public.active_powers 
        WHERE target_id = p_target_id 
          AND power_slug IN ('shield', 'return', 'invisibility');

        -- A. RETURN LOGIC (reflects attack)
        IF v_defense_slug = 'return' THEN
            v_final_caster := p_target_id; 
            v_final_target := p_caster_id;
            v_returned := true;
            
            INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
            VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'reflected');

            SELECT name INTO v_returned_by_name FROM public.profiles 
            WHERE id = (SELECT user_id FROM public.game_players WHERE id = p_target_id);
        
        -- B. SHIELD / INVISIBILITY LOGIC (blocks attack, no reflection)
        ELSE 
            INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
            VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'shield_blocked');

            RETURN json_build_object('success', true, 'blocked', true, 'reason', 'shield_absorbed');
        END IF;
    END IF;

    -- 6. EXECUTE EFFECT (Direct or Reflected)
    
    IF v_returned THEN
        IF p_power_slug = 'life_steal' THEN
           UPDATE public.game_players SET lives = GREATEST(lives - 1, 0) WHERE id = v_final_target;
           UPDATE public.game_players SET lives = LEAST(lives + 1, 3) WHERE id = v_final_caster;
        END IF;

        INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
        VALUES (v_event_id, v_final_caster, v_final_target, v_power_id, p_power_slug, 
                v_now + (GREATEST(COALESCE(v_power_duration, 10), 5) || ' seconds')::interval);

        RETURN json_build_object('success', true, 'returned', true, 'returned_by_name', v_returned_by_name);
    END IF;

    -- Normal Hit (Life Steal)
    IF p_power_slug = 'life_steal' THEN
       SELECT lives INTO v_target_lives FROM public.game_players WHERE id = p_target_id FOR UPDATE;
       
       IF v_target_lives <= 0 THEN
           RETURN json_build_object('success', true, 'stolen', false, 'reason', 'target_no_lives');
       END IF;
       
       UPDATE public.game_players SET lives = GREATEST(lives - 1, 0) WHERE id = p_target_id;
       UPDATE public.game_players SET lives = LEAST(lives + 1, 3) WHERE id = p_caster_id;
       
       INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
       VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'success');
       
       INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
       VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, v_now + interval '5 seconds');

       RETURN json_build_object('success', true);
    END IF;

    -- Normal Hit (Others)
    INSERT INTO public.active_powers (event_id, caster_id, target_id, power_id, power_slug, expires_at)
    VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 
            v_now + (GREATEST(COALESCE(v_power_duration, 10), 5) || ' seconds')::interval);
            
    INSERT INTO public.combat_events (event_id, attacker_id, target_id, power_id, power_slug, result_type)
    VALUES (v_event_id, p_caster_id, p_target_id, v_power_id, p_power_slug, 'success');
    
    RETURN json_build_object('success', true);

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

create or replace view "public"."user_activity_feed" as  SELECT (wl.id)::text AS id,
    wl.user_id,
    (wl.amount)::integer AS clover_quantity,
    COALESCE(tp.price, co_fk.amount, co_meta.amount, ((wl.metadata ->> 'amount_usd'::text))::numeric, ((wl.metadata ->> 'price_usd'::text))::numeric, (0)::numeric) AS fiat_amount,
        CASE
            WHEN (wl.amount >= (0)::numeric) THEN 'deposit'::text
            ELSE 'withdrawal'::text
        END AS type,
    'completed'::text AS status,
    wl.created_at,
    COALESCE(wl.description,
        CASE
            WHEN (wl.amount >= (0)::numeric) THEN 'Recarga'::text
            ELSE 'Retiro'::text
        END) AS description,
    NULL::text AS payment_url
   FROM (((public.wallet_ledger wl
     LEFT JOIN public.transaction_plans tp ON ((((wl.metadata ->> 'plan_id'::text) IS NOT NULL) AND (((wl.metadata ->> 'plan_id'::text))::uuid = tp.id))))
     LEFT JOIN public.clover_orders co_fk ON ((wl.order_id = co_fk.id)))
     LEFT JOIN public.clover_orders co_meta ON ((((wl.metadata ->> 'order_id'::text) IS NOT NULL) AND (((wl.metadata ->> 'order_id'::text) = co_meta.pago_pago_order_id) OR ((wl.metadata ->> 'order_id'::text) = (co_meta.id)::text)))))
UNION ALL
 SELECT (co.id)::text AS id,
    co.user_id,
    COALESCE(tp.amount, ((co.extra_data ->> 'clovers_amount'::text))::integer, ((co.extra_data ->> 'clovers_quantity'::text))::integer, 0) AS clover_quantity,
    COALESCE(tp.price, ((co.extra_data ->> 'price_usd'::text))::numeric, ((co.extra_data ->> 'amount_usd'::text))::numeric, co.amount) AS fiat_amount,
    'deposit'::text AS type,
    co.status,
    co.created_at,
    'Compra de Tréboles'::text AS description,
    co.payment_url
   FROM (public.clover_orders co
     LEFT JOIN public.transaction_plans tp ON ((co.plan_id = tp.id)))
  WHERE (co.status <> ALL (ARRAY['success'::text, 'paid'::text]));



  create policy "Players can activate powers"
  on "public"."active_powers"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM public.game_players
  WHERE ((game_players.id = active_powers.caster_id) AND (game_players.user_id = auth.uid())))));



  create policy "Admins can view audit logs"
  on "public"."admin_audit_logs"
  as permissive
  for select
  to authenticated
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = ANY (ARRAY['admin'::text, 'user_staff'::text]))))));



  create policy "Admin Write"
  on "public"."app_config"
  as permissive
  for all
  to public
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));



  create policy "app_config_admin_write"
  on "public"."app_config"
  as permissive
  for all
  to public
using ((((auth.jwt() ->> 'role'::text) = 'service_role'::text) OR (( SELECT profiles.role
   FROM public.profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text)));



  create policy "Admins can view all bets"
  on "public"."bets"
  as permissive
  for select
  to public
using (public.is_admin(auth.uid()));



  create policy "staff_deny_delete_clover_orders"
  on "public"."clover_orders"
  as restrictive
  for delete
  to authenticated
using ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_insert_clover_orders"
  on "public"."clover_orders"
  as restrictive
  for insert
  to authenticated
with check ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_update_clover_orders"
  on "public"."clover_orders"
  as restrictive
  for update
  to authenticated
using ((NOT public.is_staff(auth.uid())))
with check ((NOT public.is_staff(auth.uid())));



  create policy "Solo admins gestionan pistas"
  on "public"."clues"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Players can view their own combat events"
  on "public"."combat_events"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.game_players gp
  WHERE ((gp.user_id = auth.uid()) AND ((gp.id = combat_events.attacker_id) OR (gp.id = combat_events.target_id))))));



  create policy "Admins and staff can create events"
  on "public"."events"
  as permissive
  for insert
  to authenticated
with check ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = ANY (ARRAY['admin'::text, 'user_staff'::text]))))));



  create policy "Admins and staff can delete events"
  on "public"."events"
  as permissive
  for delete
  to authenticated
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = ANY (ARRAY['admin'::text, 'user_staff'::text]))))));



  create policy "Admins and staff can update events"
  on "public"."events"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = ANY (ARRAY['admin'::text, 'user_staff'::text]))))))
with check ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = ANY (ARRAY['admin'::text, 'user_staff'::text]))))));



  create policy "Solo administradores pueden gestionar eventos"
  on "public"."events"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "exchange_rate_history_admin_select"
  on "public"."exchange_rate_history"
  as permissive
  for select
  to public
using ((( SELECT profiles.role
   FROM public.profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text));



  create policy "Enable read access for event participants"
  on "public"."game_players"
  as permissive
  for select
  to authenticated
using (((event_id IN ( SELECT public.get_my_event_ids() AS get_my_event_ids)) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));



  create policy "Solo admins pueden actualizar game_players"
  on "public"."game_players"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Solo admins actualizan solicitudes"
  on "public"."game_requests"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Users can view own requests"
  on "public"."game_requests"
  as permissive
  for select
  to public
using (((auth.uid() = user_id) OR (( SELECT profiles.role
   FROM public.profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text)));



  create policy "Enable delete for admins"
  on "public"."mall_stores"
  as permissive
  for delete
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Enable insert for admins"
  on "public"."mall_stores"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Enable update for admins"
  on "public"."mall_stores"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Enable read access for own powers"
  on "public"."player_powers"
  as permissive
  for select
  to authenticated
using ((game_player_id IN ( SELECT game_players.id
   FROM public.game_players
  WHERE (game_players.user_id = auth.uid()))));



  create policy "Enable update for own powers"
  on "public"."player_powers"
  as permissive
  for update
  to authenticated
using ((game_player_id IN ( SELECT game_players.id
   FROM public.game_players
  WHERE (game_players.user_id = auth.uid()))))
with check ((game_player_id IN ( SELECT game_players.id
   FROM public.game_players
  WHERE (game_players.user_id = auth.uid()))));



  create policy "Players can add powers"
  on "public"."player_powers"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM public.game_players
  WHERE ((game_players.id = player_powers.game_player_id) AND (game_players.user_id = auth.uid())))));



  create policy "Admins can manage powers"
  on "public"."powers"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text)))));



  create policy "Users read own profile or public info"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (((auth.uid() = id) OR public.is_admin(auth.uid()) OR true));



  create policy "Admins can manage sponsors"
  on "public"."sponsors"
  as permissive
  for all
  to public
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));



  create policy "Admin full access"
  on "public"."transaction_plans"
  as permissive
  for all
  to public
using ((((auth.jwt() ->> 'role'::text) = 'service_role'::text) OR (( SELECT profiles.role
   FROM public.profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text)));



  create policy "staff_deny_delete_transaction_plans"
  on "public"."transaction_plans"
  as restrictive
  for delete
  to authenticated
using ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_insert_transaction_plans"
  on "public"."transaction_plans"
  as restrictive
  for insert
  to authenticated
with check ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_update_transaction_plans"
  on "public"."transaction_plans"
  as restrictive
  for update
  to authenticated
using ((NOT public.is_staff(auth.uid())))
with check ((NOT public.is_staff(auth.uid())));



  create policy "Players can create own transactions"
  on "public"."transactions"
  as permissive
  for insert
  to public
with check ((EXISTS ( SELECT 1
   FROM public.game_players
  WHERE ((game_players.id = transactions.game_player_id) AND (game_players.user_id = auth.uid())))));



  create policy "Players can view own transactions"
  on "public"."transactions"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.game_players
  WHERE ((game_players.id = transactions.game_player_id) AND (game_players.user_id = auth.uid())))));



  create policy "staff_deny_delete_payment_methods"
  on "public"."user_payment_methods"
  as restrictive
  for delete
  to authenticated
using ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_insert_payment_methods"
  on "public"."user_payment_methods"
  as restrictive
  for insert
  to authenticated
with check ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_update_payment_methods"
  on "public"."user_payment_methods"
  as restrictive
  for update
  to authenticated
using ((NOT public.is_staff(auth.uid())))
with check ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_delete_wallet_ledger"
  on "public"."wallet_ledger"
  as restrictive
  for delete
  to authenticated
using ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_insert_wallet_ledger"
  on "public"."wallet_ledger"
  as restrictive
  for insert
  to authenticated
with check ((NOT public.is_staff(auth.uid())));



  create policy "staff_deny_update_wallet_ledger"
  on "public"."wallet_ledger"
  as restrictive
  for update
  to authenticated
using ((NOT public.is_staff(auth.uid())))
with check ((NOT public.is_staff(auth.uid())));


CREATE TRIGGER tr_reset_status_after_invisibility AFTER DELETE ON public.active_powers FOR EACH ROW EXECUTE FUNCTION public.handle_status_on_power_expiry();

CREATE TRIGGER tr_on_clover_order_paid AFTER UPDATE ON public.clover_orders FOR EACH ROW EXECUTE FUNCTION public.process_paid_clover_order();

CREATE TRIGGER trg_sync_plan_id_to_ledger AFTER UPDATE ON public.clover_orders FOR EACH ROW EXECUTE FUNCTION public.sync_c_order_plan_to_ledger();

CREATE TRIGGER update_clover_orders_updated_at BEFORE UPDATE ON public.clover_orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER log_events_changes AFTER INSERT OR DELETE OR UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.log_admin_change();

CREATE TRIGGER on_event_delete AFTER DELETE ON public.events FOR EACH ROW EXECUTE FUNCTION public.handle_event_deletion();

CREATE TRIGGER trg_check_online_event_room_full AFTER INSERT ON public.game_players FOR EACH ROW EXECUTE FUNCTION public.check_online_event_room_full();

CREATE TRIGGER update_payment_transactions_updated_at BEFORE UPDATE ON public.payment_transactions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER log_profile_sensitive_changes AFTER UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.log_sensitive_profile_changes();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_email_update AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_email_update();


  create policy "Give anon users access to JPG images in folder 1ym05q3_0"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'branding'::text) AND (storage.extension(name) = 'jpg'::text) AND (lower((storage.foldername(name))[1]) = 'public'::text) AND (auth.role() = 'anon'::text)));



  create policy "Public Access"
  on "storage"."objects"
  as permissive
  for all
  to public
using ((bucket_id = 'events-images'::text))
with check ((bucket_id = 'events-images'::text));



  create policy "Sponsor Assets Admin Upload"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'sponsor-assets'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Sponsor Assets Public Read"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'sponsor-assets'::text));



