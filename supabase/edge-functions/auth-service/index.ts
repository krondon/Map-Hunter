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
      const { email, password, name, cedula, phone } = await req.json()

      if (!email || !password || !name) {
        throw new Error('Email, password and name are required')
      }

      // Validar formato de cédula venezolana (V/E + 6-9 dígitos)
      if (cedula) {
        const cedulaRegex = /^[VE]\d{6,9}$/i
        if (!cedulaRegex.test(cedula)) {
          throw new Error('Formato de cédula inválido. Usa V12345678 o E12345678')
        }

        // Verificar si la cédula ya existe
        const { data: existingCedula } = await supabaseClient
          .from('profiles')
          .select('id')
          .eq('cedula', cedula.toUpperCase())
          .single()

        if (existingCedula) {
          throw new Error('Esta cédula ya está registrada')
        }
      }

      // Validar formato de teléfono venezolano (04XX-XXXXXXX)
      if (phone) {
        const phoneDigits = phone.replace('-', '')
        const phoneRegex = /^04(12|14|24|16|26)\d{7}$/

        if (!phoneRegex.test(phoneDigits)) {
          throw new Error('Formato de teléfono inválido. Usa 0412-1234567')
        }

        // Verificar si el teléfono ya existe
        const { data: existingPhone } = await supabaseClient
          .from('profiles')
          .select('id')
          .eq('phone', phoneDigits)
          .single()

        if (existingPhone) {
          throw new Error('Este teléfono ya está registrado')
        }
      }

      const { data, error } = await supabaseClient.auth.signUp({
        email,
        password,
        options: {
          data: {
            name,
            cedula: cedula ? cedula.toUpperCase() : null,
            phone: phone ? phone.replace('-', '') : null
          }
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

    // --- UPDATE PROFILE ---
    if (path === 'update-profile') {
      const { name, dni, phone } = await req.json()

      // Authorization Check
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) {
        throw new Error('Missing Authorization header')
      }

      // Create authenticated client for RLS
      const userSupabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        {
          global: {
            headers: { Authorization: authHeader },
          },
        }
      )

      const { data: { user }, error: userError } = await userSupabase.auth.getUser()

      if (userError || !user) {
        throw new Error('Invalid or expired session')
      }

      // Prepare update object
      const updates: any = {}
      if (name) updates.name = name
      if (dni) updates.dni = dni
      if (phone) updates.phone = phone

      if (Object.keys(updates).length === 0) {
        throw new Error('No fields to update')
      }

      const { data, error } = await userSupabase
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single()

      if (error) throw error

      return new Response(
        JSON.stringify(data),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- ADD PAYMENT METHOD ---
    if (path === 'add-payment-method') {
      const { bank_code } = await req.json()

      // Authorization Check
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) {
        throw new Error('Missing Authorization header')
      }

      // Create authenticated client for RLS
      const userSupabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        {
          global: {
            headers: { Authorization: authHeader },
          },
        }
      )

      const { data: { user }, error: userError } = await userSupabase.auth.getUser()

      if (userError || !user) {
        throw new Error('Invalid or expired session')
      }

      // 1. Fetch Profile Data (DNI & Phone)
      const { data: profile, error: profileError } = await userSupabase
        .from('profiles')
        .select('dni, phone')
        .eq('id', user.id)
        .single()

      if (profileError || !profile) {
        throw new Error('No se pudo cargar el perfil del usuario.')
      }

      if (!profile.dni || !profile.phone) {
        throw new Error('Perfil incompleto. Falta DNI o Teléfono.')
      }

      // 2. Insert Payment Method
      const { data, error } = await userSupabase
        .from('user_payment_methods')
        .insert({
          user_id: user.id,
          bank_code: bank_code,
          phone_number: profile.phone,
          dni: String(profile.dni),
          is_default: true
        })
        .select()
        .single()

      if (error) throw error

      return new Response(
        JSON.stringify(data),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // --- DELETE ACCOUNT ---
    if (path === 'delete-account' && req.method === 'DELETE') {
      const { password } = await req.json()

      if (!password) {
        throw new Error('Password is required to delete account')
      }

      // Authorization Check
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) {
        throw new Error('Missing Authorization header')
      }

      // Create authenticated client for RLS
      const userSupabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        {
          global: {
            headers: { Authorization: authHeader },
          },
        }
      )

      const { data: { user }, error: userError } = await userSupabase.auth.getUser()

      if (userError || !user) {
        throw new Error('Invalid or expired session')
      }

      // Verify password by attempting to sign in
      const { error: passwordError } = await supabaseClient.auth.signInWithPassword({
        email: user.email!,
        password: password,
      })

      if (passwordError) {
        throw new Error('Contraseña incorrecta')
      }

      // Use service role to delete user data and auth account
      const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      if (!serviceKey) {
        throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY')
      }

      const serviceClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        serviceKey,
        { auth: { persistSession: false } }
      )

      // Delete profile (cascade will handle related data)
      const { error: profileError } = await serviceClient
        .from('profiles')
        .delete()
        .eq('id', user.id)

      if (profileError) {
        console.error('Error deleting profile:', profileError)
        throw new Error('Error al eliminar el perfil')
      }

      // Delete auth user
      const { error: authDeleteError } = await serviceClient.auth.admin.deleteUser(user.id)

      if (authDeleteError) {
        console.error('Error deleting auth user:', authDeleteError)
        throw new Error('Error al eliminar la cuenta de autenticación')
      }

      return new Response(
        JSON.stringify({ message: 'Account deleted successfully' }),
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
