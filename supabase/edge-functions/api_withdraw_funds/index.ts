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

        // Sanitize Data
        const cleanDni = dni.replace(/\D/g, ''); // Remove 'V', 'E', '-' etc. return only numbers
        const cleanPhone = phone ? phone.replace(/\D/g, '') : null;

        console.log(`Sending Withdrawal: DNI=${cleanDni} (Raw: ${dni}), Phone=${cleanPhone}, Bank=${bank}, Amount=${amount}`)

        const payload = {
            amount: amount,
            bank: bank,
            dni: cleanDni,
            phone: cleanPhone,
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

                // Log Refund in Wallet Ledger
                const { error: refundLedgerError } = await supabaseAdmin.from('wallet_ledger').insert({
                    user_id: user.id,
                    amount: amount, // Positive for refund
                    description: "Reembolso por fallo en retiro",
                    order_id: null,
                    metadata: apiResponseData
                })
                
                if (refundLedgerError) {
                    console.error("CRITICAL: Failed to log refund in wallet_ledger:", refundLedgerError)
                }
            }

            const failureMsg = apiResponseData?.message ?? 
                             JSON.stringify(apiResponseData) ?? 
                             "Withdrawal failed at payment provider (No detail).";
            throw new Error(`Withdrawal failed: ${failureMsg}. Funds refunded.`)
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

        // 5. LOG IN WALLET LEDGER
        const referenceInfo = apiResponseData.data?.details?.external_reference || apiResponseData.data?.reference || 'N/A';
        const transactionId = apiResponseData.data?.transaction_id;
        
        // Ensure we don't pass a text ID if the DB expects UUID for order_id. 
        // We'll store the transaction ID in the description/metadata to be safe.
        const { error: ledgerError } = await supabaseAdmin.from('wallet_ledger').insert({
            user_id: user.id,
            amount: -amount, // Negative for withdrawal
            description: `Retiro de Fondos - Ref: ${referenceInfo} (ID: ${transactionId})`,
            order_id: null, // Safest option without knowing schema. Metadata has the details.
            metadata: apiResponseData
        })

        if (ledgerError) {
            console.error("CRITICAL: Failed to log withdrawal in wallet_ledger:", ledgerError)
            // Optional: return warning or part of the error? 
            // For now, we just log it so we don't fail the client response since the money is already moved.
            return new Response(JSON.stringify({ 
                success: true, 
                data: apiResponseData,
                warning: "Transaction completed but ledger update failed. Contact support."
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200, // Still 200 because money was moved
            })
        }

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
