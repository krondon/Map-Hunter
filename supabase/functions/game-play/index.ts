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
      },
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

    const url = new URL(req.url);
    const path = url.pathname.split("/").pop();

    // --- GET CLUES (WITH PROGRESS) ---
    if (path === "get-clues") {
      const { eventId } = await req.json();

      // 1. Traer todas las pistas del evento usando service_role
      //    (las políticas SELECT públicas de clues fueron eliminadas por seguridad)
      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );
      const { data: clues, error: cluesError } = await supabaseAdmin
        .from("clues")
        .select("*")
        .eq("event_id", eventId)
        .order("sequence_index", { ascending: true });

      if (cluesError) throw cluesError;
      if (!clues || clues.length === 0)
        return new Response(JSON.stringify([]), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });

      // 2. Traer el progreso real del usuario para este evento
      const clueIds = clues.map((c) => c.id);
      const { data: progressData } = await supabaseClient
        .from("user_clue_progress")
        .select("clue_id, is_completed, is_locked")
        .eq("user_id", user.id)
        .in("clue_id", clueIds);

      // Process clues sequentially to enforce game logic (Mario Kart Style)
      const processedClues = [];
      let previousClueCompleted = true; // First clue is always unlocked

      for (const clue of clues) {
        // Fix: Ensure strict string comparison for BigInt IDs
        const progress = progressData?.find(
          (p) => String(p.clue_id) === String(clue.id),
        );

        let isCompleted = progress?.is_completed ?? false;
        let isLocked = !previousClueCompleted;

        // Integrity Check: A clue cannot be completed if it is locked (i.e., if previous wasn't completed)
        // This fixes cases where DB might have inconsistent state
        if (isLocked) {
          isCompleted = false;
        }

        // Strip riddle_answer before sending to client — answer validation
        // happens server-side in the "complete-clue" handler.
        const { riddle_answer, ...safeClue } = clue;

        processedClues.push({
          ...safeClue,
          is_completed: isCompleted,
          isCompleted: isCompleted, // Frontend expects camelCase
          is_locked: isLocked,
        });

        // Update for next iteration
        previousClueCompleted = isCompleted;
      }

      return new Response(JSON.stringify(processedClues), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- GET LEADERBOARD ---
    if (path === "get-leaderboard") {
      const { eventId } = await req.json();

      if (!eventId) {
        return new Response(JSON.stringify({ error: "Event ID is required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: leaderboard, error } = await supabaseClient.rpc(
        "get_event_leaderboard",
        { target_event_id: eventId },
      );

      if (error) {
        console.error("Error fetching leaderboard:", error);
        throw error;
      }

      // Map to match Flutter Player model
      const mappedLeaderboard = leaderboard.map((entry: any) => ({
        id: entry.user_id,
        name: entry.name,
        avatarUrl: entry.avatar_url,
        level: entry.level,
        totalXP: entry.total_xp,
        score: entry.score,
        // [FIX] Ensure we pass event-specific progress
        completed_clues_count:
          entry.completed_clues_count ?? entry.completed_clues ?? 0,
        completed_clues:
          entry.completed_clues_count ?? entry.completed_clues ?? 0,
      }));

      return new Response(JSON.stringify(mappedLeaderboard), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- START GAME ---
    if (path === "start-game") {
      const { eventId } = await req.json();
      if (!eventId) throw new Error("eventId is required");

      const { error } = await supabaseClient.rpc("initialize_game_for_user", {
        target_user_id: user.id,
        target_event_id: eventId,
      });
      if (error) throw error;

      return new Response(JSON.stringify({ message: "Game started" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- COMPLETE CLUE ---
    if (path === "complete-clue") {
      const { clueId, answer } = await req.json();
      console.log(`[complete-clue] Processing clueId: ${clueId}`);

      // 1. Usar ADMIN para poder leer la pista aunque el usuario no tenga permiso aún
      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );

      const { data: clue, error: clueError } = await supabaseAdmin
        .from("clues")
        .select("*")
        .eq("id", clueId)
        .single();

      if (clueError || !clue) {
        console.error("[complete-clue] Clue not found:", clueError);
        throw new Error("Clue not found");
      }

      if (
        clue.riddle_answer &&
        answer &&
        clue.riddle_answer.toLowerCase() !== answer.toLowerCase()
      ) {
        return new Response(JSON.stringify({ error: "Incorrect answer" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 1.5 Check if already completed to avoid overwriting timestamp and double counting
      const { data: existingProgress } = await supabaseAdmin
        .from("user_clue_progress")
        .select("is_completed")
        .eq("user_id", user.id)
        .eq("clue_id", clueId)
        .maybeSingle();

      if (!existingProgress?.is_completed) {
        // 2. Marcar pista actual como completada
        const { error: updateError } = await supabaseAdmin
          .from("user_clue_progress")
          .upsert(
            {
              user_id: user.id,
              clue_id: clueId,
              is_completed: true,
              is_locked: false,
              completed_at: new Date().toISOString(),
            },
            { onConflict: "user_id, clue_id" },
          );

        if (updateError) {
          console.error(
            "[complete-clue] Error updating current clue:",
            updateError,
          );
          throw updateError;
        }

        // 2.5 ATOMIC increment of completed_clues_count + last_active timestamp
        // Uses a DB RPC to avoid read-modify-write race conditions between concurrent players
        await supabaseAdmin.rpc("increment_clue_count", {
          p_user_id: user.id,
          p_event_id: clue.event_id,
        });
      } else {
        console.log(
          "[complete-clue] Clue already completed, skipping stats update.",
        );
      }

      console.log(
        `[complete-clue] Current clue completed. Sequence Index: ${clue.sequence_index}`,
      );

      // 3. DESBLOQUEAR SIGUIENTE PISTA (Usamos supabaseAdmin aquí es CLAVE)
      const { data: nextClue, error: nextClueQueryError } = await supabaseAdmin
        .from("clues")
        .select("id, sequence_index")
        .eq("event_id", clue.event_id)
        .gt("sequence_index", clue.sequence_index)
        .order("sequence_index", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (nextClueQueryError) {
        console.error(
          "[complete-clue] Error finding next clue:",
          nextClueQueryError,
        );
      }

      if (nextClue) {
        console.log(
          `[complete-clue] Found next clue ID: ${nextClue.id}, Sequence: ${nextClue.sequence_index}`,
        );

        // Primero verificamos si ya existe progreso para la siguiente pista para no sobrescribir is_completed si ya lo estaba
        const { data: existingNextProgress } = await supabaseAdmin
          .from("user_clue_progress")
          .select("is_completed")
          .eq("user_id", user.id)
          .eq("clue_id", nextClue.id)
          .maybeSingle();

        const isNextCompleted = existingNextProgress?.is_completed ?? false;

        const { error: nextClueError } = await supabaseAdmin
          .from("user_clue_progress")
          .upsert(
            {
              user_id: user.id,
              clue_id: nextClue.id,
              is_locked: false,
              is_completed: isNextCompleted, // Mantenemos el estado completado si ya lo estaba
            },
            { onConflict: "user_id, clue_id" },
          );

        if (nextClueError) {
          console.error(
            "[complete-clue] Error unlocking next clue:",
            nextClueError,
          );
        } else {
          console.log(`[complete-clue] Next clue unlocked successfully.`);
        }
      } else {
        console.log(
          "[complete-clue] No next clue found - User may have completed all clues!",
        );

        // 3.5. CHECK IF USER COMPLETED ALL CLUES AND MARK RACE AS COMPLETED
        // Get total clues for this event
        const { data: allClues } = await supabaseAdmin
          .from("clues")
          .select("id")
          .eq("event_id", clue.event_id);

        if (allClues) {
          const totalClues = allClues.length;

          // Count how many clues this user has completed
          const clueIds = allClues.map((c) => c.id);
          const { data: userProgress } = await supabaseAdmin
            .from("user_clue_progress")
            .select("clue_id")
            .eq("user_id", user.id)
            .eq("is_completed", true)
            .in("clue_id", clueIds);

          const completedCount = userProgress?.length || 0;

          console.log(
            `[complete-clue] User completed ${completedCount}/${totalClues} clues`,
          );

          // If user completed ALL clues, check if race needs to be marked complete
          if (completedCount === totalClues) {
            // Check current event status
            const { data: event } = await supabaseAdmin
              .from("events")
              .select("status, winner_id")
              .eq("id", clue.event_id)
              .single();

            // If race is not yet completed, this player wins!
            // FIX: Removed legacy logic that auto-closed the event here.
            // Now handled by 'register_race_finisher' RPC called from client.
            if (event && event.status !== "completed") {
              console.log(
                `[complete-clue] 🏆 User finished all clues! (Event closure is now handled by RPC)`,
              );
            }
          }
        }
      }

      // 4. Premios DINÁMICOS basados en ranking del jugador (Rubber Banding)
      // Obtener ranking de todos los jugadores del evento ordenados por progreso
      const { data: rankings } = await supabaseAdmin
        .from("game_players")
        .select("id, user_id, completed_clues_count")
        .eq("event_id", clue.event_id)
        .order("completed_clues_count", { ascending: false });

      // Calcular N (total jugadores) y R (posición del jugador actual)
      const N = rankings?.length || 1;
      let R = 1;
      if (rankings) {
        const idx = rankings.findIndex((r) => r.user_id === user.id);
        R = idx >= 0 ? idx + 1 : N;
      }

      // Algoritmo de recompensa adaptativo
      let coinsEarned: number;
      if (R === 1) {
        // Líder absoluto (R=1): Random(15, 25) - Menos monedas para evitar que se escape
        coinsEarned = Math.floor(Math.random() * 11) + 15;
      } else if (R === N && N > 1) {
        // Último lugar (R=N, solo si hay más de 1 jugador): Random(35, 45) - Más monedas para catch-up
        coinsEarned = Math.floor(Math.random() * 11) + 35;
      } else {
        // Pelotón (resto): Random(25, 35)
        coinsEarned = Math.floor(Math.random() * 11) + 25;
      }

      console.log(
        `[complete-clue] 🎯 Ranking: R=${R}/${N}, Reward: ${coinsEarned} coins`,
      );

      // Actualizamos game_players.coins (Session Based Economy)
      const { data: gamePlayer, error: gpError } = await supabaseAdmin
        .from("game_players")
        .select("id, coins, completed_clues_count")
        .eq("user_id", user.id)
        .eq("event_id", clue.event_id)
        .single();

      let newBalance = 0;
      if (gamePlayer) {
        newBalance = (Number(gamePlayer.coins) || 0) + coinsEarned;

        await supabaseAdmin
          .from("game_players")
          .update({ coins: newBalance })
          .eq("id", gamePlayer.id);

        console.log(
          `[complete-clue] ✅ Awarded ${coinsEarned} coins. New Balance: ${newBalance}`,
        );
      } else {
        console.error(
          "[complete-clue] Game player not found for reward update",
        );
      }

      // Mantenemos actualización de XP Global en Profiles (opcional, si el sistema de nivel es global)
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("*")
        .eq("id", user.id)
        .single();

      if (profile) {
        const currentTotalXp =
          Number(profile.total_xp) || Number(profile.experience) || 0;
        const rewardXp = Number(clue.xp_reward) || 0;
        const newTotalXp = currentTotalXp + rewardXp;

        let calculatedLevel = 1;
        let tempXp = newTotalXp;
        while (true) {
          const xpNeededForNext = calculatedLevel * 100;
          if (tempXp >= xpNeededForNext) {
            tempXp -= xpNeededForNext;
            calculatedLevel++;
          } else {
            break;
          }
        }
        const newPartialXp = tempXp;

        let newProfession = profile.profession || "Novice";
        const standardRanks = [
          "Novice",
          "Apprentice",
          "Explorer",
          "Master",
          "Legend",
        ];
        if (standardRanks.includes(newProfession)) {
          if (calculatedLevel < 5) newProfession = "Novice";
          else if (calculatedLevel < 10) newProfession = "Apprentice";
          else if (calculatedLevel < 20) newProfession = "Explorer";
          else if (calculatedLevel < 50) newProfession = "Master";
          else newProfession = "Legend";
        }

        // SOLO actualizamos XP y Level, NO coins global
        await supabaseAdmin
          .from("profiles")
          .update({
            experience: newPartialXp,
            total_xp: newTotalXp,
            level: calculatedLevel,
            profession: newProfession,
          })
          .eq("id", user.id);
      }

      // 5. Check if race was completed and return that info
      const { data: finalEvent } = await supabaseAdmin
        .from("events")
        .select("status")
        .eq("id", clue.event_id)
        .single();

      // FIX: raceCompleted should indicate if the USER finished the race (all clues),
      // not if the EVENT is globally completed.
      // We need to re-verify if user finished all clues here or pass it down.
      // Optimization: We already checked completion above. Let's recalculate or just check user_clue_progress count.

      let userFinishedRace = false;
      const { data: allCluesCount } = await supabaseAdmin
        .from("clues")
        .select("id", { count: "exact", head: true })
        .eq("event_id", clue.event_id);

      const { data: userCluesCount } = await supabaseAdmin
        .from("user_clue_progress")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("is_completed", true);
      // We need to filter by clues belonging to this event.
      // This query is slightly expensive, but safe.
      // Actually, we can rely on the check done in lines 310-330 if we scoped it out.
      // Re-implementing a quick check:
      // Or simpler: check if 'nextClue' was null AND we just completed a clue?
      // Yes, line 298: "No next clue found".
      // If no next clue found, user finished.

      const raceCompleted = !nextClue; // If there is no next clue, the user has finished.

      return new Response(
        JSON.stringify({
          success: true,
          message: "Clue completed",
          raceCompleted: raceCompleted,
          coins_earned: coinsEarned,
          new_balance: newBalance,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    // --- SKIP CLUE ---
    if (path === "skip-clue") {
      const { clueId } = await req.json();

      const { data: clue, error: clueError } = await supabaseClient
        .from("clues")
        .select("*")
        .eq("id", clueId)
        .single();

      if (clueError) throw clueError;

      const { error: updateError } = await supabaseClient
        .from("user_clue_progress")
        .update({ is_completed: true, completed_at: new Date().toISOString() })
        .eq("user_id", user.id)
        .eq("clue_id", clueId);

      if (updateError) throw updateError;

      const { data: nextClue } = await supabaseClient
        .from("clues")
        .select("id")
        .eq("event_id", clue.event_id)
        .gt("sequence_index", clue.sequence_index)
        .order("sequence_index", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (nextClue) {
        await supabaseClient
          .from("user_clue_progress")
          .update({ is_locked: false })
          .eq("user_id", user.id)
          .eq("clue_id", nextClue.id);
      }

      return new Response(
        JSON.stringify({ success: true, message: "Clue skipped" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // --- CHECK RACE STATUS ---
    if (path === "check-race-status") {
      const { eventId } = await req.json();

      if (!eventId) {
        return new Response(JSON.stringify({ error: "Event ID required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );

      // Get event status
      const { data: event, error: eventError } = await supabaseAdmin
        .from("events")
        .select("status, completed_at, winner_id")
        .eq("id", eventId)
        .single();

      if (eventError || !event) {
        return new Response(JSON.stringify({ error: "Event not found" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Get player's position in leaderboard
      const { data: leaderboard } = await supabaseAdmin.rpc(
        "get_event_leaderboard",
        { target_event_id: eventId },
      );

      let playerPosition = 0;
      if (leaderboard) {
        const playerIndex = leaderboard.findIndex(
          (p: any) => p.user_id === user.id,
        );
        playerPosition = playerIndex >= 0 ? playerIndex + 1 : 0;
      }

      return new Response(
        JSON.stringify({
          isCompleted: event.status === "completed",
          completedAt: event.completed_at,
          winnerId: event.winner_id,
          playerPosition: playerPosition,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // --- SABOTAGE RIVAL ---
    if (path === "sabotage-rival") {
      const { rivalId, eventId } = await req.json();

      // VALIDACIÓN DE SEGURIDAD: Evitar auto-sabotaje
      if (rivalId === user.id) {
        return new Response(
          JSON.stringify({ error: "Cannot sabotage yourself" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      if (!eventId) {
        return new Response(
          JSON.stringify({ error: "Event ID required for sabotage" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      );

      // Verificar monedas en game_players (Session Based)
      const { data: currentPlayer } = await supabaseAdmin
        .from("game_players")
        .select("id, coins")
        .eq("user_id", user.id)
        .eq("event_id", eventId)
        .single();

      if (!currentPlayer || (Number(currentPlayer.coins) || 0) < 50) {
        return new Response(JSON.stringify({ error: "Not enough coins" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Descontar costo (50 monedas)
      await supabaseAdmin
        .from("game_players")
        .update({ coins: Number(currentPlayer.coins) - 50 })
        .eq("id", currentPlayer.id);

      // Aplicar castigo al rival (Freeze Profile? Or Game Player status?)
      // Original logic used profiles.status = 'frozen'.
      // If sabotage is game specific, maybe we should freeze game_player?
      // Prompt says "update lo que logic of reward and sabotage... UPDATE realize sobre game_players"
      // But sabotage effect (freezing) currently is on profile.
      // If we freeze profile, they are frozen in ALL games.
      // For now, I will keep profile freeze logic as is (since prompt focused on coins),
      // OR move freeze to game_players.status if supported.
      // Schema game_players has status text default 'active'.
      // I'll stick to legacy profile freeze unless instructed otherwise, but coins MUST come from game_players.

      const freezeUntil = new Date(Date.now() + 5 * 60 * 1000).toISOString();

      // Update: Freeze global profile logic acts as global penalty
      await supabaseAdmin
        .from("profiles")
        .update({
          status: "frozen",
          frozen_until: freezeUntil,
        })
        .eq("id", rivalId);

      return new Response(
        JSON.stringify({ success: true, message: "Rival sabotaged" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
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
