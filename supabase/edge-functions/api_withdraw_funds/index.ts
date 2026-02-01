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
        // Use Service Role for safe DB operations (balance updates)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Authenticate User properly
        const authToken = req.headers.get('Authorization')
        if (!authToken) throw new Error("Missing Authorization header")

        const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(authToken.replace('Bearer ', ''))

        if (userError || !user) {
            throw new Error("Unauthorized")
        }

        const { amount, bank, dni, phone, cta } = await req.json()

        if (!amount || !bank || !dni || (!phone && !cta)) {
            throw new Error("Missing required fields: amount, bank, dni, and (phone or cta)")
        }

        console.log(`Processing withdrawal request for user ${user.id} of amount ${amount}`)

        // 1. CHECK & DEDUCT BALANCE (Transactional-like)
        const { data: profile, error: profileError } = await supabaseAdmin
            .from('profiles')
            .select('clovers')
            .eq('id', user.id)
            .single()

        if (profileError || !profile) {
            throw new Error("Profile not found")
        }

        if (profile.clovers < amount) {
            throw new Error(`Insufficient funds: Has ${profile.clovers}, needs ${amount}`)
        }

        // Deduct funds immediately
        const { error: deductError } = await supabaseAdmin
            .from('profiles')
            .update({ clovers: profile.clovers - amount })
            .eq('id', user.id)

        if (deductError) throw new Error("Failed to deduct funds")

        // 2. CALL PAGO A PAGO
        const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')!
        const PAGO_PAGO_WITHDRAW_URL = Deno.env.get('PAGO_PAGO_WITHDRAW_URL')!

        const payload = {
            amount: amount,
            bank: bank,
            dni: dni,
            phone: phone,
            cta: cta
            // Add other mandatory fields if any from docs, e.g. bank_account_type if needed
        }

        let apiSuccess = false
        let apiResponseData = null

        try {
            const response = await fetch(PAGO_PAGO_WITHDRAW_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'pago_pago_api': pagoApiKey
                },
                body: JSON.stringify(payload)
            })

            apiResponseData = await response.json()
            apiSuccess = response.ok && apiResponseData.success

        } catch (netError) {
            console.error("Network error calling Pago a Pago:", netError)
            apiSuccess = false
        }

        // 3. HANDLE FAILURE -> REFUND
        if (!apiSuccess) {
            console.error("Withdrawal Failed. Refunding user...", apiResponseData)

            // Fetch fresh balance to be safe regarding concurrency (simple approach)
            const { data: currentProfile } = await supabaseAdmin
                .from('profiles')
                .select('clovers')
                .eq('id', user.id)
                .single()

            if (currentProfile) {
                await supabaseAdmin
                    .from('profiles')
                    .update({ clovers: currentProfile.clovers + amount })
                    .eq('id', user.id)
            }

            throw new Error(apiResponseData?.message || "Withdrawal failed at payment provider. Funds refunded.")
        }

        // 4. LOG SUCCESSFUL TRANSACTION
        await supabaseAdmin.from('payment_transactions').insert({
            user_id: user.id,
            amount: amount,
            type: 'WITHDRAWAL', // Ensure this enum/type exists or usage string
            status: 'COMPLETED',
            provider_data: apiResponseData,
            order_id: apiResponseData.data?.transaction_id || `WD-${Date.now()}`
        })

        return new Response(JSON.stringify({ success: true, data: apiResponseData }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error("Withdrawal flow error:", error)
        return new Response(JSON.stringify({ error: error.message, success: false }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
