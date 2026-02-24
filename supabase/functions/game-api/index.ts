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
    const path = url.pathname.split('/').pop() // Get the last part of the path

    // --- GET CLUES ---
    if (req.method === 'GET' && path === 'clues') {
      // Fetch clues and join with user progress
      const { data: clues, error: cluesError } = await supabaseClient
        .from('clues')
        .select('*')
        .order('sequence_index', { ascending: true })

      if (cluesError) throw cluesError

      const { data: progress, error: progressError } = await supabaseClient
        .from('user_clue_progress')
        .select('*')
        .eq('user_id', user.id)

      if (progressError) throw progressError

      // Merge progress into clues
      const cluesWithProgress = clues.map((clue: any) => {
        const p = progress.find((p: any) => p.clue_id === clue.id)
        // Strip riddle_answer before sending to client
        const { riddle_answer, ...safeClue } = clue;
        return {
          ...safeClue,
          isLocked: p ? p.is_locked : true, // Default locked if no progress
          isCompleted: p ? p.is_completed : false,
        }
      })

      return new Response(
        JSON.stringify(cluesWithProgress),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- START GAME ---
    if (req.method === 'POST' && path === 'start-game') {
      // We need eventId to start game now
      const { eventId } = await req.json()
      
      if (!eventId) {
         return new Response(
          JSON.stringify({ error: 'eventId is required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

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
    if (req.method === 'POST' && path === 'complete-clue') {
      const { clueId, answer } = await req.json()

      // 1. Verify answer (optional, if we want to validate on server)
      const { data: clue, error: clueError } = await supabaseClient
        .from('clues')
        .select('*')
        .eq('id', clueId)
        .single()

      if (clueError) throw clueError

      // Simple answer check (case insensitive)
      if (clue.riddle_answer && answer && clue.riddle_answer.toLowerCase() !== answer.toLowerCase()) {
         return new Response(
          JSON.stringify({ error: 'Incorrect answer' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // 2. Update progress
      const { error: updateError } = await supabaseClient
        .from('user_clue_progress')
        .update({ is_completed: true, completed_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('clue_id', clueId)

      if (updateError) throw updateError

      // 3. Unlock next clue
      // Find next clue by sequence_index in the same event
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

      // 4. Award Rewards (XP and Coins)
      // We use RPCs or direct update if RLS allows. 
      // Assuming we have a 'profiles' table and we can update it or use an RPC.
      // Let's use a direct update for now, assuming RLS allows user to update own profile or we use service role.
      // Actually, for rewards, it's safer to use an RPC or Service Role to prevent cheating.
      // But here we are using the user's client. 
      // Let's use the Service Role client for awarding rewards to be safe.
      
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('experience, coins, level')
        .eq('id', user.id)
        .single()
      
      if (profile) {
        const newXp = (profile.experience || 0) + (clue.xp_reward || 0)
        const newCoins = (profile.coins || 0) + (clue.coin_reward || 0)
        // Simple level up logic (e.g. every 1000 XP)
        const newLevel = Math.floor(newXp / 1000) + 1

        await supabaseAdmin
          .from('profiles')
          .update({ 
            experience: newXp, 
            coins: newCoins, 
            level: newLevel,
            total_xp: newXp // Assuming total_xp is same as experience for now
          })
          .eq('id', user.id)
      }

      return new Response(
        JSON.stringify({ success: true, message: 'Clue completed' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- SKIP CLUE ---
    if (req.method === 'POST' && path === 'skip-clue') {
      const { clueId } = await req.json()
      
      // 1. Get clue to find next one
      const { data: clue, error: clueError } = await supabaseClient
        .from('clues')
        .select('*')
        .eq('id', clueId)
        .single()

      if (clueError) throw clueError

      // 2. Update progress (completed, no rewards)
      const { error: updateError } = await supabaseClient
        .from('user_clue_progress')
        .update({ is_completed: true, completed_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('clue_id', clueId)

      if (updateError) throw updateError

      // 3. Unlock next clue
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

    // --- ADMIN: APPROVE REQUEST ---
    if (req.method === 'POST' && path === 'approve-request') {
      // Check if user is admin (implementation depends on how admins are stored)
      // For now, we'll skip strict admin check or assume RLS handles it, 
      // but since we are using Service Role for the transaction, we should check here.
      // Let's assume a simple check: email contains 'admin' or specific ID.
      // In production, check a 'role' column in profiles.
      
      const { data: profile } = await supabaseClient
  .from("profiles")
  .select("role")
  .eq("id", user.id)
  .single();
      if (profile?.role !== "admin") {
        return new Response(JSON.stringify({ error: "Forbidden" }), {
          status: 403,
          headers: corsHeaders,
        });
      }

      const { requestId } = await req.json()
      
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // 1. Get request
      const { data: request, error: reqError } = await supabaseAdmin
        .from('game_requests')
        .select('*')
        .eq('id', requestId)
        .single()

      if (reqError) throw reqError

      // 2. Update status
      await supabaseAdmin
        .from('game_requests')
        .update({ status: 'approved' })
        .eq('id', requestId)

      // 3. Add to participants
      await supabaseAdmin
        .from('event_participants')
        .insert({
          user_id: request.user_id,
          event_id: request.event_id
        })

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- SABOTAGE RIVAL ---
    if (req.method === 'POST' && path === 'sabotage-rival') {
      const { rivalId } = await req.json()
      
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // 1. Check if user has enough coins
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

      // 2. Deduct coins
      await supabaseAdmin
        .from('profiles')
        .update({ coins: userProfile.coins - 50 })
        .eq('id', user.id)

      // 3. Apply effect to rival (e.g. freeze for 5 mins)
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
