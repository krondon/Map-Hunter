import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const url = new URL(req.url)
    const path = url.pathname.split('/').pop()

    // --- GET CLUES (WITH PROGRESS) ---
    if (path === 'get-clues') {
      const { eventId } = await req.json()

      // 1. Traer todas las pistas del evento
      const { data: clues, error: cluesError } = await supabaseClient
        .from('clues')
        .select('*')
        .eq('event_id', eventId)
        .order('sequence_index', { ascending: true })

      if (cluesError) throw cluesError
      if (!clues || clues.length === 0) return new Response(JSON.stringify([]), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

      // 2. Traer el progreso real del usuario para este evento
      const clueIds = clues.map(c => c.id)
      const { data: progressData } = await supabaseClient
        .from('user_clue_progress')
        .select('clue_id, is_completed, is_locked')
        .eq('user_id', user.id)
        .in('clue_id', clueIds)

      // Process clues sequentially to enforce game logic (Mario Kart Style)
      const processedClues = []
      let previousClueCompleted = true // First clue is always unlocked

      for (const clue of clues) {
        // Fix: Ensure strict string comparison for BigInt IDs
        const progress = progressData?.find(p => String(p.clue_id) === String(clue.id))

        let isCompleted = progress?.is_completed ?? false
        let isLocked = !previousClueCompleted

        // Integrity Check: A clue cannot be completed if it is locked (i.e., if previous wasn't completed)
        // This fixes cases where DB might have inconsistent state
        if (isLocked) {
          isCompleted = false
        }

        processedClues.push({
          ...clue,
          is_completed: isCompleted,
          isCompleted: isCompleted, // Frontend expects camelCase
          is_locked: isLocked
        })

        // Update for next iteration
        previousClueCompleted = isCompleted
      }

      return new Response(JSON.stringify(processedClues), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // --- GET LEADERBOARD ---
    if (path === 'get-leaderboard') {
      const { eventId } = await req.json()

      if (!eventId) {
        return new Response(
          JSON.stringify({ error: 'Event ID is required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { data: leaderboard, error } = await supabaseClient
        .rpc('get_event_leaderboard', { target_event_id: eventId })

      if (error) {
        console.error('Error fetching leaderboard:', error)
        throw error
      }

      // Map to match Flutter Player model
      const mappedLeaderboard = leaderboard.map((entry: any) => ({
        id: entry.user_id,
        name: entry.name,
        avatarUrl: entry.avatar_url,
        level: entry.level,
        totalXP: entry.total_xp,
        score: entry.score
      }))

      return new Response(
        JSON.stringify(mappedLeaderboard),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- START GAME ---
    if (path === 'start-game') {
      const { eventId } = await req.json()
      if (!eventId) throw new Error('eventId is required')

      const { error } = await supabaseClient.rpc('initialize_game_for_user', {
        target_user_id: user.id,
        target_event_id: eventId
      })
      if (error) throw error

      return new Response(
        JSON.stringify({ message: 'Game started' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- COMPLETE CLUE ---
    if (path === 'complete-clue') {
      const { clueId, answer } = await req.json();
      console.log(`[complete-clue] Processing clueId: ${clueId}`);

      // 1. Usar ADMIN para poder leer la pista aunque el usuario no tenga permiso aún
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );

      const { data: clue, error: clueError } = await supabaseAdmin
        .from('clues')
        .select('*')
        .eq('id', clueId)
        .single();

      if (clueError || !clue) {
        console.error('[complete-clue] Clue not found:', clueError);
        throw new Error('Clue not found');
      }

      if (clue.riddle_answer && answer && clue.riddle_answer.toLowerCase() !== answer.toLowerCase()) {
        return new Response(JSON.stringify({ error: 'Incorrect answer' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      }

      // 1.5 Check if already completed to avoid overwriting timestamp and double counting
      const { data: existingProgress } = await supabaseAdmin
        .from('user_clue_progress')
        .select('is_completed')
        .eq('user_id', user.id)
        .eq('clue_id', clueId)
        .maybeSingle();

      if (!existingProgress?.is_completed) {
        // 2. Marcar pista actual como completada
        const { error: updateError } = await supabaseAdmin
          .from('user_clue_progress')
          .upsert({
            user_id: user.id,
            clue_id: clueId,
            is_completed: true,
            is_locked: false,
            completed_at: new Date().toISOString()
          }, { onConflict: 'user_id, clue_id' })

        if (updateError) {
          console.error('[complete-clue] Error updating current clue:', updateError)
          throw updateError
        }

        // 2.5 Update game_players stats (completed_clues_count)
        const { data: gamePlayer } = await supabaseAdmin
          .from('game_players')
          .select('id, completed_clues_count')
          .eq('user_id', user.id)
          .eq('event_id', clue.event_id)
          .maybeSingle();

        if (gamePlayer) {
          await supabaseAdmin
            .from('game_players')
            .update({
              completed_clues_count: (gamePlayer.completed_clues_count || 0) + 1
            })
            .eq('id', gamePlayer.id);
        }
      } else {
        console.log('[complete-clue] Clue already completed, skipping stats update.');
      }

      console.log(`[complete-clue] Current clue completed. Sequence Index: ${clue.sequence_index}`);

      // 3. DESBLOQUEAR SIGUIENTE PISTA (Usamos supabaseAdmin aquí es CLAVE)
      const { data: nextClue, error: nextClueQueryError } = await supabaseAdmin
        .from('clues')
        .select('id, sequence_index')
        .eq('event_id', clue.event_id)
        .gt('sequence_index', clue.sequence_index)
        .order('sequence_index', { ascending: true })
        .limit(1)
        .maybeSingle()

      if (nextClueQueryError) {
        console.error('[complete-clue] Error finding next clue:', nextClueQueryError);
      }

      if (nextClue) {
        console.log(`[complete-clue] Found next clue ID: ${nextClue.id}, Sequence: ${nextClue.sequence_index}`);

        // Primero verificamos si ya existe progreso para la siguiente pista para no sobrescribir is_completed si ya lo estaba
        const { data: existingNextProgress } = await supabaseAdmin
          .from('user_clue_progress')
          .select('is_completed')
          .eq('user_id', user.id)
          .eq('clue_id', nextClue.id)
          .maybeSingle();

        const isNextCompleted = existingNextProgress?.is_completed ?? false;

        const { error: nextClueError } = await supabaseAdmin
          .from('user_clue_progress')
          .upsert({
            user_id: user.id,
            clue_id: nextClue.id,
            is_locked: false,
            is_completed: isNextCompleted // Mantenemos el estado completado si ya lo estaba
          }, { onConflict: 'user_id, clue_id' })

        if (nextClueError) {
          console.error('[complete-clue] Error unlocking next clue:', nextClueError)
        } else {
          console.log(`[complete-clue] Next clue unlocked successfully.`);
        }
      } else {
        console.log('[complete-clue] No next clue found - User may have completed all clues!');

        // 3.5. CHECK IF USER COMPLETED ALL CLUES AND MARK RACE AS COMPLETED
        // Get total clues for this event
        const { data: allClues } = await supabaseAdmin
          .from('clues')
          .select('id')
          .eq('event_id', clue.event_id);

        if (allClues) {
          const totalClues = allClues.length;

          // Count how many clues this user has completed
          const clueIds = allClues.map(c => c.id);
          const { data: userProgress } = await supabaseAdmin
            .from('user_clue_progress')
            .select('clue_id')
            .eq('user_id', user.id)
            .eq('is_completed', true)
            .in('clue_id', clueIds);

          const completedCount = userProgress?.length || 0;

          console.log(`[complete-clue] User completed ${completedCount}/${totalClues} clues`);

          // If user completed ALL clues, check if race needs to be marked complete
          if (completedCount === totalClues) {
            // Check current event status
            const { data: event } = await supabaseAdmin
              .from('events')
              .select('status, winner_id')
              .eq('id', clue.event_id)
              .single();

            // If race is not yet completed, this player wins!
            if (event && event.status !== 'completed') {
              console.log(`[complete-clue] 🏆 First player to finish! Marking race as completed.`);

              await supabaseAdmin
                .from('events')
                .update({
                  status: 'completed',
                  completed_at: new Date().toISOString(),
                  winner_id: user.id
                })
                .eq('id', clue.event_id);
            }
          }
        }
      }

      // 4. Premios (Corregido: total_coins)
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single()

      if (profile) {
        // Calculamos XP total sumando la recompensa
        const currentTotalXp = Number(profile.total_xp) || Number(profile.experience) || 0
        const rewardXp = Number(clue.xp_reward) || 0
        const newTotalXp = currentTotalXp + rewardXp
        const currentCoins = Math.max(Number(profile.coins) || 0, Number(profile.total_coins) || 0)
        const newCoins = currentCoins + (Number(clue.coin_reward) || 0)

        // Calculamos nivel y residuo (newPartialXp)
        let calculatedLevel = 1
        let tempXp = newTotalXp

        while (true) {
          const xpNeededForNext = calculatedLevel * 100
          if (tempXp >= xpNeededForNext) {
            tempXp -= xpNeededForNext
            calculatedLevel++
          } else {
            break
          }
        }

        const newPartialXp = tempXp // El residuo que llena la barra de 0 a 100

        // Profesión dinámica
        let newProfession = profile.profession || 'Novice'
        const standardRanks = ['Novice', 'Apprentice', 'Explorer', 'Master', 'Legend']
        if (standardRanks.includes(newProfession)) {
          if (calculatedLevel < 5) newProfession = 'Novice'
          else if (calculatedLevel < 10) newProfession = 'Apprentice'
          else if (calculatedLevel < 20) newProfession = 'Explorer'
          else if (calculatedLevel < 50) newProfession = 'Master'
          else newProfession = 'Legend'
        }

        console.log(`[complete-clue] New Coins: ${newCoins}, New Total XP: ${newTotalXp}`)

        // Actualizamos la DB con ambos campos para mantener consistencia
        const { error: rewardError } = await supabaseAdmin
          .from('profiles')
          .update({
            experience: newPartialXp, // Barra de progreso
            total_xp: newTotalXp,    // Estadísticas
            level: calculatedLevel,
            coins: newCoins,
            total_coins: newCoins,   // <--- SYNC BOTH COLUMNS
            profession: newProfession
          })
          .eq('id', user.id)

        if (rewardError) console.error('[complete-clue] Reward Error:', rewardError)
      }

      // 5. Check if race was completed and return that info
      const { data: finalEvent } = await supabaseAdmin
        .from('events')
        .select('status')
        .eq('id', clue.event_id)
        .single();

      const raceCompleted = finalEvent?.status === 'completed';

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Clue completed',
          raceCompleted: raceCompleted
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    // --- SKIP CLUE ---
    if (path === 'skip-clue') {
      const { clueId } = await req.json()

      const { data: clue, error: clueError } = await supabaseClient
        .from('clues')
        .select('*')
        .eq('id', clueId)
        .single()

      if (clueError) throw clueError

      const { error: updateError } = await supabaseClient
        .from('user_clue_progress')
        .update({ is_completed: true, completed_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('clue_id', clueId)

      if (updateError) throw updateError

      const { data: nextClue } = await supabaseClient
        .from('clues')
        .select('id')
        .eq('event_id', clue.event_id)
        .gt('sequence_index', clue.sequence_index)
        .order('sequence_index', { ascending: true })
        .limit(1)
        .maybeSingle()

      if (nextClue) {
        await supabaseClient
          .from('user_clue_progress')
          .update({ is_locked: false })
          .eq('user_id', user.id)
          .eq('clue_id', nextClue.id)
      }

      return new Response(
        JSON.stringify({ success: true, message: 'Clue skipped' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- CHECK RACE STATUS ---
    if (path === 'check-race-status') {
      const { eventId } = await req.json();

      if (!eventId) {
        return new Response(
          JSON.stringify({ error: 'Event ID required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );

      // Get event status
      const { data: event, error: eventError } = await supabaseAdmin
        .from('events')
        .select('status, completed_at, winner_id')
        .eq('id', eventId)
        .single();

      if (eventError || !event) {
        return new Response(
          JSON.stringify({ error: 'Event not found' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Get player's position in leaderboard
      const { data: leaderboard } = await supabaseAdmin
        .rpc('get_event_leaderboard', { target_event_id: eventId });

      let playerPosition = 0;
      if (leaderboard) {
        const playerIndex = leaderboard.findIndex((p: any) => p.user_id === user.id);
        playerPosition = playerIndex >= 0 ? playerIndex + 1 : 0;
      }

      return new Response(
        JSON.stringify({
          isCompleted: event.status === 'completed',
          completedAt: event.completed_at,
          winnerId: event.winner_id,
          playerPosition: playerPosition
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- SABOTAGE RIVAL ---
    if (path === 'sabotage-rival') {
      const { rivalId } = await req.json()

      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      const { data: userProfile } = await supabaseAdmin
        .from('profiles')
        .select('coins')
        .eq('id', user.id)
        .single()

      if (!userProfile || userProfile.coins < 50) {
        return new Response(
          JSON.stringify({ error: 'Not enough coins' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      await supabaseAdmin
        .from('profiles')
        .update({ coins: userProfile.coins - 50 })
        .eq('id', user.id)

      const freezeUntil = new Date(Date.now() + 5 * 60 * 1000).toISOString()
      await supabaseAdmin
        .from('profiles')
        .update({
          status: 'frozen',
          frozen_until: freezeUntil
        })
        .eq('id', rivalId)

      return new Response(
        JSON.stringify({ success: true, message: 'Rival sabotaged' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Not Found' }),
      { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
