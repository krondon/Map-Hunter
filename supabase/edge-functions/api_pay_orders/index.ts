import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, pago_pago_api',
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

        // 1. Authenticate user
        const {
            data: { user },
        } = await supabaseClient.auth.getUser()

        if (!user) {
            throw new Error("Unauthorized")
        }

        const { amount, currency, phone, motive, dni, email } = await req.json()

        console.log(`Processing payment request for user ${user.id}: ${amount} ${currency}`)

        // 2. Get Pago a Pago API Key
        const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')
        if (!pagoApiKey) {
            throw new Error("Server Misconfiguration: Missing PAGO_PAGO_API_KEY")
        }

        // 3. Prepare Payload for Pago a Pago
        const PAGO_PAGO_URL = Deno.env.get('PAGO_PAGO_API_URL')!

        // Debug API Key (Safety Check)
        console.log(`[DEBUG] API Key Check: Length=${pagoApiKey.length}, StartsWith=${pagoApiKey.substring(0, 4)}***`)

        // Calculate expiration (e.g., 30 minutes from now)
        const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString()

        const payload = {
            amount: amount,
            currency: currency || 'VES',
            motive: motive || "Recharge Wallet",
            email: email || user.email,
            phone: phone,
            dni: dni,
            type_order: "EXTERNAL",
            expires_at: expiresAt,
            alias: `RECHARGE-${user.id.substring(0, 8)}-${Date.now()}`,
            convert_from_usd: true, // Assuming input amount is in USD (Treboles)
            url_redirect: "io.supabase.treasurehunt://payment-return",
            extra_data: {
                user_id: user.id,
                clovers_amount: amount // Pass original Tréboles amount to webhook
            }
        }

        console.log("Sending to Pago a Pago:", JSON.stringify(payload))

        // 4. Call Pago a Pago API
        const response = await fetch(PAGO_PAGO_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'pago_pago_api': pagoApiKey // Custom header required by provider
            },
            body: JSON.stringify(payload)
        })

        const data = await response.json()
        console.log("Pago a Pago Response:", JSON.stringify(data))

        // 5. Return result to Client
        // MOCK RESPONSE IF API FAILS (FOR DEV ONLY - REMOVE IN PROD)
        if (!response.ok && PAGO_PAGO_URL.includes('pagoapago.com/v1')) {
            console.log("Simulating success for development since API URL is likely placeholder")
            return new Response(JSON.stringify({
                success: true,
                message: "Mock Order Created",
                data: {
                    payment_url: "https://pagoapago.com/checkout/mock-12345",
                    order_id: `MOCK-${Date.now()}`
                }
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        if (!response.ok) {
            throw new Error(`Pago a Pago API Error: ${JSON.stringify(data)}`)
        }

        return new Response(JSON.stringify(data), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error("Error processing payment:", error)
        return new Response(JSON.stringify({ error: error.message, success: false }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
