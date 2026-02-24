-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.active_powers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  event_id uuid NOT NULL,
  caster_id uuid NOT NULL,
  target_id uuid,
  power_id uuid NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  power_slug text,
  CONSTRAINT active_powers_pkey PRIMARY KEY (id),
  CONSTRAINT active_powers_caster_id_fkey FOREIGN KEY (caster_id) REFERENCES public.game_players(id),
  CONSTRAINT active_powers_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.game_players(id),
  CONSTRAINT active_powers_power_id_fkey FOREIGN KEY (power_id) REFERENCES public.powers(id),
  CONSTRAINT active_powers_slug_fkey FOREIGN KEY (power_slug) REFERENCES public.powers(slug),
  CONSTRAINT active_powers_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);
CREATE TABLE public.admin_audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  admin_id uuid,
  action_type text NOT NULL,
  target_table text NOT NULL,
  target_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT admin_audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT admin_audit_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.app_config (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  key text NOT NULL,
  value jsonb NOT NULL,
  description text,
  updated_at timestamp with time zone DEFAULT now(),
  updated_by text,
  CONSTRAINT app_config_pkey PRIMARY KEY (id)
);
CREATE TABLE public.app_settings (
  key text NOT NULL,
  value jsonb NOT NULL,
  description text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT app_settings_pkey PRIMARY KEY (key)
);
CREATE TABLE public.bets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  user_id uuid NOT NULL,
  racer_id uuid NOT NULL,
  amount integer NOT NULL CHECK (amount > 0),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT bets_pkey PRIMARY KEY (id),
  CONSTRAINT bets_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT bets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT bets_racer_id_fkey FOREIGN KEY (racer_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.clover_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  pago_pago_order_id text UNIQUE,
  user_id uuid NOT NULL,
  amount numeric NOT NULL,
  currency text DEFAULT 'VES'::text,
  status text NOT NULL DEFAULT 'pending'::text,
  transaction_id text,
  bank_reference text,
  payment_url text,
  extra_data jsonb DEFAULT '{}'::jsonb,
  expires_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  plan_id uuid,
  CONSTRAINT clover_orders_pkey PRIMARY KEY (id),
  CONSTRAINT clover_orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.clues (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  event_id uuid NOT NULL,
  sequence_index integer NOT NULL,
  title text DEFAULT 'Nueva Pista'::text,
  description text DEFAULT 'Descripción pendiente'::text,
  hint text,
  type text DEFAULT 'qrScan'::text CHECK (type = ANY (ARRAY['qrScan'::text, 'geolocation'::text, 'minigame'::text, 'npcInteraction'::text])),
  puzzle_type text,
  minigame_url text,
  riddle_question text,
  riddle_answer text,
  xp_reward integer DEFAULT 50,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  latitude double precision,
  longitude double precision,
  CONSTRAINT clues_pkey PRIMARY KEY (id),
  CONSTRAINT clues_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);
CREATE TABLE public.combat_events (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  event_id uuid NOT NULL,
  attacker_id uuid NOT NULL,
  target_id uuid NOT NULL,
  power_id uuid NOT NULL,
  power_slug text,
  result_type text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT combat_events_pkey PRIMARY KEY (id),
  CONSTRAINT combat_events_attacker_id_fkey FOREIGN KEY (attacker_id) REFERENCES public.game_players(id),
  CONSTRAINT combat_events_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.game_players(id),
  CONSTRAINT combat_events_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);
CREATE TABLE public.events (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text,
  date timestamp with time zone NOT NULL,
  image_url text,
  clue text NOT NULL,
  max_participants integer DEFAULT 0,
  created_by_admin_id text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  pin text,
  latitude double precision,
  longitude double precision,
  location_name text,
  winner_id uuid,
  completed_at timestamp with time zone,
  is_completed boolean DEFAULT false,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'active'::text, 'completed'::text])),
  type text NOT NULL DEFAULT 'on_site'::text,
  entry_type text DEFAULT 'free'::text,
  entry_fee bigint DEFAULT 0,
  configured_winners integer DEFAULT 3,
  pot bigint DEFAULT 0,
  spectator_config jsonb DEFAULT '{}'::jsonb,
  betting_active boolean DEFAULT true,
  bet_ticket_price integer DEFAULT 100,
  sponsor_id uuid,
  CONSTRAINT events_pkey PRIMARY KEY (id),
  CONSTRAINT events_sponsor_id_fkey FOREIGN KEY (sponsor_id) REFERENCES public.sponsors(id),
  CONSTRAINT events_winner_id_fkey FOREIGN KEY (winner_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.exchange_rate_history (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  rate numeric,
  previous_rate numeric,
  source text NOT NULL DEFAULT 'manual'::text,
  error_message text,
  scraped_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT exchange_rate_history_pkey PRIMARY KEY (id)
);
CREATE TABLE public.game_players (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  event_id uuid NOT NULL,
  user_id uuid NOT NULL,
  lives integer NOT NULL DEFAULT 3 CHECK (lives <= 3),
  joined_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  final_placement integer,
  completed_clues_count integer DEFAULT 0,
  finish_time timestamp with time zone,
  last_active timestamp with time zone DEFAULT now(),
  status text DEFAULT 'active'::text,
  coins bigint DEFAULT 100,
  is_protected boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT game_players_pkey PRIMARY KEY (id),
  CONSTRAINT game_players_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT game_players_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);
CREATE TABLE public.game_requests (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  event_id uuid NOT NULL,
  status text DEFAULT 'pending'::text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT game_requests_pkey PRIMARY KEY (id),
  CONSTRAINT game_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT game_requests_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);
CREATE TABLE public.mall_stores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  image_url text,
  qr_code_data text NOT NULL,
  products jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT mall_stores_pkey PRIMARY KEY (id),
  CONSTRAINT mall_stores_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id)
);
CREATE TABLE public.minigame_capitals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  flag text NOT NULL,
  capital text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT minigame_capitals_pkey PRIMARY KEY (id)
);
CREATE TABLE public.minigame_emoji_movies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  emojis text NOT NULL,
  valid_answers ARRAY NOT NULL,
  difficulty text DEFAULT 'medium'::text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT minigame_emoji_movies_pkey PRIMARY KEY (id)
);
CREATE TABLE public.minigame_true_false (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  statement text NOT NULL,
  is_true boolean NOT NULL,
  correction text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT minigame_true_false_pkey PRIMARY KEY (id)
);
CREATE TABLE public.player_powers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  game_player_id uuid NOT NULL,
  power_id uuid NOT NULL,
  last_used_at timestamp with time zone,
  acquired_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  quantity integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  CONSTRAINT player_powers_pkey PRIMARY KEY (id),
  CONSTRAINT player_powers_game_player_id_fkey FOREIGN KEY (game_player_id) REFERENCES public.game_players(id),
  CONSTRAINT player_powers_power_id_fkey FOREIGN KEY (power_id) REFERENCES public.powers(id)
);
CREATE TABLE public.powers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  power_type text NOT NULL,
  cost integer NOT NULL DEFAULT 50,
  duration integer DEFAULT 20,
  cooldown integer NOT NULL DEFAULT 60,
  icon text DEFAULT '⚡'::text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  slug text UNIQUE,
  CONSTRAINT powers_pkey PRIMARY KEY (id)
);
CREATE TABLE public.prize_distributions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  event_id uuid NOT NULL,
  user_id uuid NOT NULL,
  position integer NOT NULL CHECK ("position" >= 1 AND "position" <= 3),
  amount integer NOT NULL CHECK (amount >= 0),
  pot_total numeric NOT NULL CHECK (pot_total >= 0::numeric),
  participants_count integer NOT NULL,
  entry_fee integer NOT NULL,
  distributed_at timestamp with time zone DEFAULT now(),
  rpc_success boolean DEFAULT false,
  error_message text,
  CONSTRAINT prize_distributions_pkey PRIMARY KEY (id),
  CONSTRAINT prize_distributions_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id),
  CONSTRAINT prize_distributions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  name text,
  email text,
  avatar_url text,
  level integer DEFAULT 1,
  total_xp integer DEFAULT 0,
  profession text DEFAULT 'Novice'::text,
  status text DEFAULT 'pending'::text,
  stat_speed integer DEFAULT 0,
  stat_strength integer DEFAULT 0,
  stat_intelligence integer DEFAULT 0,
  updated_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  role text DEFAULT 'user'::text,
  inventory ARRAY DEFAULT '{}'::text[],
  is_playing boolean DEFAULT false,
  penalty_level integer DEFAULT 0,
  ban_ends_at timestamp with time zone,
  experience bigint DEFAULT 0,
  avatar_id text,
  clovers numeric DEFAULT 0,
  dni text UNIQUE CHECK (dni ~* '^[VEJPG][0-9]+$'::text),
  phone text UNIQUE,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.sponsors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  plan_type text NOT NULL CHECK (plan_type = ANY (ARRAY['bronce'::text, 'plata'::text, 'oro'::text])),
  logo_url text,
  banner_url text,
  minigame_asset_url text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT sponsors_pkey PRIMARY KEY (id)
);
CREATE TABLE public.transaction_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  amount integer NOT NULL CHECK (amount > 0),
  price numeric NOT NULL CHECK (price > 0::numeric),
  type text NOT NULL CHECK (type = ANY (ARRAY['buy'::text, 'withdraw'::text])),
  is_active boolean DEFAULT true,
  icon_url text,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT transaction_plans_pkey PRIMARY KEY (id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  game_player_id uuid NOT NULL,
  shop_item_id uuid,
  transaction_type text NOT NULL CHECK (transaction_type = ANY (ARRAY['purchase'::text, 'reward'::text, 'power_use'::text])),
  coins_change integer NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_game_player_id_fkey FOREIGN KEY (game_player_id) REFERENCES public.game_players(id)
);
CREATE TABLE public.user_clue_progress (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  clue_id bigint NOT NULL,
  is_completed boolean DEFAULT false,
  is_locked boolean DEFAULT true,
  completed_at timestamp with time zone,
  CONSTRAINT user_clue_progress_pkey PRIMARY KEY (id),
  CONSTRAINT user_clue_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT user_clue_progress_clue_id_fkey FOREIGN KEY (clue_id) REFERENCES public.clues(id)
);
CREATE TABLE public.user_inventory (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  item_name text NOT NULL,
  acquired_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT user_inventory_pkey PRIMARY KEY (id),
  CONSTRAINT user_inventory_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_payment_methods (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  bank_code text,
  account_number text,
  phone_number text,
  dni text CHECK (dni ~* '^[VEJPG][0-9]+$'::text),
  is_default boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_payment_methods_pkey PRIMARY KEY (id),
  CONSTRAINT user_payment_methods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.wallet_ledger (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  order_id uuid,
  amount numeric NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  metadata jsonb,
  CONSTRAINT wallet_ledger_pkey PRIMARY KEY (id),
  CONSTRAINT wallet_ledger_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.clover_orders(id),
  CONSTRAINT wallet_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);