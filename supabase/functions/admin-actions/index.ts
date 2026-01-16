import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- VALIDACIÓN DE ROL ADMIN (CORRECCIÓN DE SEGURIDAD) ---
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (profileError || profile?.role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Admin role required' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }
    // --- FIN VALIDACIÓN ---

    const url = new URL(req.url);
    const path = url.pathname.split("/").pop();

    // --- APPROVE REQUEST ---
    if (path === "approve-request") {
      const { requestId } = await req.json();

      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      );

      // 1. Obtener la solicitud
      const { data: request, error: reqError } = await supabaseAdmin
        .from("game_requests")
        .select("*")
        .eq("id", requestId)
        .single();

      if (reqError) throw reqError;

      // 2. Aprobar solicitud
      await supabaseAdmin
        .from("game_requests")
        .update({ status: "approved" })
        .eq("id", requestId);

      // 3. CREAR JUGADOR REAL (Aquí está la magia)
      // Al insertar aquí, se genera un UUID nuevo que servirá para inventarios y poderes
      const { error: insertError } = await supabaseAdmin
        .from("game_players")
        .insert({
          user_id: request.user_id,
          event_id: request.event_id,
          lives: 3, // Vidas iniciales
        });

      if (insertError) {
        // Si falla (ej: usuario ya existe), lanzamos error
        throw insertError;
      }

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- GENERATE CLUES ---
    if (path === "generate-clues") {
      const { eventId, quantity } = await req.json();

      if (!eventId || !quantity)
        throw new Error("eventId and quantity are required");

      const { error } = await supabaseClient.rpc("generate_clues_for_event", {
        target_event_id: eventId,
        quantity: quantity,
      });

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, message: "Clues generated" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // --- CREATE CLUES BATCH ---

    if (path === "create-clues-batch") {
      const { eventId, clues } = await req.json();

      if (!eventId || !clues || !Array.isArray(clues))
        throw new Error("eventId and clues array are required");

      const cluesToInsert = clues.map((clue: any, index: number) => ({
        event_id: eventId,
        sequence_index: index,
        title: clue.title,
        description: clue.description,

        // CORRECCIÓN 1: Usar el tipo que viene de Flutter, no forzar 'qrScan'
        type: clue.type || "minigame",

        // CORRECCIÓN 2: Agregar el campo puzzle_type
        puzzle_type: clue.puzzle_type,

        // El resto de campos siguen igual
        riddle_question: clue.riddle_question,
        riddle_answer: clue.riddle_answer,
        xp_reward: clue.xp_reward || 50,
        coin_reward: clue.coin_reward || 10,
      }));

      const { error } = await supabaseClient
        .from("clues")
        .insert(cluesToInsert);

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, message: "Clues created" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // --- RESET EVENT (NUEVO) ---
    if (path === "reset-event") {
      const { eventId } = await req.json();
      if (!eventId) throw new Error("eventId is required");

      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      );

      console.log(`NUCLEAR RESET: Iniciando para evento ${eventId}`);

      // 1. Obtener IDs de pistas para este evento (para borrar progreso)
      const { data: clues } = await supabaseAdmin
        .from("clues")
        .select("id")
        .eq("event_id", eventId);

      const clueIds = clues?.map(c => c.id) || [];

      // 2. Obtener IDs de game_players para este evento (para borrar poderes si no hay cascada)
      const { data: gps } = await supabaseAdmin
        .from("game_players")
        .select("id")
        .eq("event_id", eventId);

      const gpIds = gps?.map(g => g.id) || [];

      // 3. Borrar progreso de pistas
      if (clueIds.length > 0) {
        await supabaseAdmin
          .from("user_clue_progress")
          .delete()
          .in("clue_id", clueIds);
      }

      // 4. Borrar datos asociados a los jugadores
      if (gpIds.length > 0) {
        // Borrar poderes
        await supabaseAdmin
          .from("player_powers")
          .delete()
          .in("game_player_id", gpIds);

        // Borrar desafíos completados (NUEVO)
        await supabaseAdmin
          .from("player_completed_challenges")
          .delete()
          .in("game_player_id", gpIds);

        // Borrar inventario del jugador (NUEVO)
        await supabaseAdmin
          .from("player_inventory")
          .delete()
          .in("game_player_id", gpIds);
      }

      // 5. Borrar inscripciones de jugadores
      const { error: delPlayersError } = await supabaseAdmin
        .from("game_players")
        .delete()
        .eq("event_id", eventId);

      if (delPlayersError) throw delPlayersError;

      // 6. Borrar solicitudes
      const { error: delRequestsError } = await supabaseAdmin
        .from("game_requests")
        .delete()
        .eq("event_id", eventId);

      if (delRequestsError) throw delRequestsError;

      // 7. Resetear el estado del evento
      const { error: resetEventError } = await supabaseAdmin
        .from("events")
        .update({
          status: "pending",
          winner_id: null,
          completed_at: null,
        })
        .eq("id", eventId);

      if (resetEventError) throw resetEventError;

      return new Response(
        JSON.stringify({ success: true, message: "Evento reiniciado nuclearmente (Inscripciones, Solicitudes, Inventario y Progreso eliminados)" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ error: "Not Found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
