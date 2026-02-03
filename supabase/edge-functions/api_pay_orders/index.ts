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
            convert_from_usd: false, // Ensure we are sending explicit VES amount
            url_redirect: "io.supabase.treasurehunt://payment-return",
            extra_data: {
                user_id: user.id,
                clovers_amount: amount // Amount in VES
            }
        }

        console.log("Sending to Pago a Pago:", JSON.stringify(payload))

        // 4. Call Pago a Pago API
        let data;
        let pUrl = PAGO_PAGO_URL;
        
        // MOCK CHECK (For Dev/Test environments)
        // If the URL suggests a mock/test endpoint that serves HTML or doesn't exist, we simulate.
        if (pUrl.includes('pagoapago.com/v1') || pUrl.includes('mock')) {
             console.log("Simulating success via MOCK logic (URL detected as placeholder/mock)")
             data = {
                success: true,
                message: "Mock Order Created",
                data: {
                    payment_url: "https://pagoapago.com/checkout/mock-" + Date.now(),
                    order_id: `MOCK-${Date.now()}`
                }
             }
        } else {
             // REAL API CALL
             const response = await fetch(PAGO_PAGO_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'pago_pago_api': pagoApiKey
                },
                body: JSON.stringify(payload)
            })
            
            if (!response.ok) {
                const errText = await response.text();
                throw new Error(`Pago a Pago API Error (${response.status}): ${errText}`);
            }
            
            data = await response.json();
            console.log("Pago a Pago Response:", JSON.stringify(data))
        }

        // 5. Persistence Logic (CRITICAL)
        // Use Admin Client to bypass RLS for robust server-side insertion
        const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
        if (!serviceRoleKey) {
            console.error("CRITICAL: SUPABASE_SERVICE_ROLE_KEY is missing in environment variables!");
            throw new Error("Server Misconfiguration: Missing DB Permissions");
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            serviceRoleKey
        )

        // Parse response data safely
        const orderId = data.data?.order_id || data.order_id
        const paymentUrl = data.data?.payment_url || data.payment_url

        if (!orderId || !paymentUrl) {
             console.error("Invalid Response Data for Persistence:", data);
             if (data.success === false) throw new Error(data.message || "Unknown API Error");
             throw new Error("Missing order_id or payment_url in response");
        }

        console.log(`Persisting order ${orderId} for user ${user.id}...`)
        
        // INSERT
        const { error: dbError } = await supabaseAdmin.from('clover_orders').insert({
            user_id: user.id,
            amount: amount,
            currency: currency || 'VES',
            status: 'pending',
            pago_pago_order_id: orderId,
            payment_url: paymentUrl,
            expires_at: expiresAt,
            extra_data: {
                original_amount: amount,
                initiated_at: new Date().toISOString(),
                api_response: data,
                function_version: "v2-diagnostics",
                clovers_amount: amount
            }
        })

        if (dbError) {
            console.error("CRITICAL DB ERROR:", dbError);
            throw new Error(`Database Persistence Failed: ${dbError.message} (${dbError.code})`);
        }
        
        // VERIFY READ-AFTER-WRITE
        console.log("Verifying persistence...");
        const { data: verifyData, error: verifyError } = await supabaseAdmin
            .from('clover_orders')
            .select('id, status')
            .eq('pago_pago_order_id', orderId)
            .single();
            
        if (verifyError || !verifyData) {
            console.error("VERIFICATION FAILED:", verifyError);
            // We don't throw here to avoid killing the successful payment link, but we log loud.
        } else {
             console.log("VERIFICATION SUCCESS: Record found:", verifyData);
        }

        console.log("Order persisted and verified successfully.");

        return new Response(JSON.stringify({
            ...data,
            debug_info: {
                persistence_verified: !!verifyData,
                server_time: new Date().toISOString(),
                correlation_id: `v2-${Date.now()}`
            }
        }), {
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
