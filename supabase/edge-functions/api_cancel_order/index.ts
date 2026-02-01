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

        const {
            data: { user },
        } = await supabaseClient.auth.getUser()

        if (!user) {
            throw new Error("Unauthorized")
        }

        const { order_id } = await req.json()

        // 1. Get API Key
        const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')!
        const PAGO_PAGO_URL = Deno.env.get('PAGO_PAGO_CANCEL_URL')!

        console.log(`Cancelling order ${order_id} via Pago a Pago`)

        // 2. Cancel on Provider
        const response = await fetch(PAGO_PAGO_URL, {
            method: 'PUT', // Documentation specifies PUT
            headers: {
                'Content-Type': 'application/json',
                'pago_pago_api': pagoApiKey
            },
            body: JSON.stringify({ order_id })
        })

        const data = await response.json()

        return new Response(JSON.stringify(data), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
