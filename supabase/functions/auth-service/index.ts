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
    // Initialize Supabase client
    // We use the ANON key because these are public endpoints (login/register)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    const url = new URL(req.url)
    const path = url.pathname.split('/').pop()

    // --- LOGIN ---
    if (path === 'login') {
      const { email, password } = await req.json()

      if (!email || !password) {
        throw new Error('Email and password are required')
      }

      const { data, error } = await supabaseClient.auth.signInWithPassword({
        email,
        password,
      })

      if (error) throw error

      // Check if user is banned
      if (data?.user?.id) {
        const { data: profile, error: profileError } = await supabaseClient
          .from('profiles')
          .select('status')
          .eq('id', data.user.id)
          .single()

        if (profileError) {
          console.error('Error checking profile status:', profileError)
          // Optional: throw error or proceed? Better to proceed if check fails strictly, but for security maybe proceed?
          // Let's assume if we can't check, we let them in (fail open) OR fail closed. 
          // Given it's a game, fail open might be safer for UX if DB is glitchy, but for bans, usually fail closed?
          // Actually, if simply select fails, it's weird. Let's just log.
        }

        if (profile && profile.status === 'banned') {
          // Sign out explicitly so the session isn't valid despite just being created
          await supabaseClient.auth.signOut()
          throw new Error('Tu cuenta ha sido suspendida permanentemente.')
        }
      }

      return new Response(
        JSON.stringify(data),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- REGISTER ---
    if (path === 'register') {
      const { email, password, name } = await req.json()

      if (!email || !password || !name) {
        throw new Error('Email, password and name are required')
      }

      const { data, error } = await supabaseClient.auth.signUp({
        email,
        password,
        options: {
          data: { name }
        }
      })

      if (error) throw error

      // // Ensure the user starts with 100 coins.
      // // We use the Service Role key to bypass RLS and safely upsert the profile.
      // if (data?.user?.id) {
      //   const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      //   if (!serviceKey) {
      //     throw new Error(
      //       'Missing SUPABASE_SERVICE_ROLE_KEY. Set it in Supabase Edge Function secrets to initialize profile coins.'
      //     )
      //   }

      //   const serviceClient = createClient(
      //     Deno.env.get('SUPABASE_URL') ?? '',
      //     serviceKey,
      //     { auth: { persistSession: false } }
      //   )

      //   const { error: profileError } = await serviceClient
      //     .from('profiles')
      //     .upsert(
      //       {
      //         id: data.user.id,
      //         email,
      //         name,
      //         role: 'user',
      //         total_coins: 100,
      //         coins: 100,
      //       },
      //       { onConflict: 'id' }
      //     )

      //   if (profileError) throw profileError
      // }

      return new Response(
        JSON.stringify(data),
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
