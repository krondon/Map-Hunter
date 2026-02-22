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

    // --- GET CLUES ---
    // Fetch clues and join with user progress
    // We might need eventId in query params if we want to support multiple events active
    // For now, let's assume the client sends ?eventId=... or we fetch all active progresses.
    // But the previous logic was fetching all clues. 
    // Let's stick to the previous logic but improved: fetch clues for the event the user is playing.
    // How do we know which event? 
    // We can look at user_clue_progress to see which clues they have.
    // Or pass eventId as param. Let's pass eventId as param for better filtering.
    
    const url = new URL(req.url)
    const eventId = url.searchParams.get('eventId')

    let query = supabaseClient
      .from('clues')
      .select('*')
      .order('sequence_index', { ascending: true })
    
    if (eventId) {
      query = query.eq('event_id', eventId)
    }

    const { data: clues, error: cluesError } = await query

    if (cluesError) throw cluesError

    // Use Admin client to fetch progress to ensure we see all records regardless of RLS quirks
    // and to debug if RLS was the issue.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: progress, error: progressError } = await supabaseAdmin
      .from('user_clue_progress')
      .select('*')
      .eq('user_id', user.id)

    if (progressError) throw progressError

    console.log(`[game-data] User: ${user.id}`)
    console.log(`[game-data] Found ${progress.length} progress records (Admin Client)`)
    if (progress.length > 0) {
        console.log(`[game-data] Sample progress: ClueID=${progress[0].clue_id}, Locked=${progress[0].is_locked}, Completed=${progress[0].is_completed}`)
        if (progress.length > 1) {
             console.log(`[game-data] Sample progress 2: ClueID=${progress[1].clue_id}, Locked=${progress[1].is_locked}, Completed=${progress[1].is_completed}`)
        }
    }

    // Merge progress into clues
    const cluesWithProgress = clues.map((clue: any) => {
      // Use String conversion for ID comparison to handle potential BigInt/Number/String mismatches
      const p = progress.find((p: any) => String(p.clue_id) === String(clue.id))
      
      const isLocked = p ? p.is_locked : true
      const isCompleted = p ? p.is_completed : false
      
      // console.log(`[game-data] Clue ${clue.id}: isLocked=${isLocked}, isCompleted=${isCompleted}`)
      
      return {
        ...clue,
        isLocked: isLocked, // Default locked if no progress
        isCompleted: isCompleted,
      }
    })

    return new Response(
      JSON.stringify(cluesWithProgress),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
