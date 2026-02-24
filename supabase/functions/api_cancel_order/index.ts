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

        // 1. Get order details to retrieve external ID
        const { data: order, error: fetchError } = await supabaseClient
            .from('clover_orders')
            .select('pago_pago_order_id, status')
            .eq('id', order_id)
            .single()

        if (fetchError || !order) {
            console.error("Error fetching order:", fetchError)
            throw new Error("Orden no encontrada")
        }

        if (order.status !== 'pending') {
             throw new Error(`No se puede cancelar una orden con estado: ${order.status}`)
        }

        const externalId = order.pago_pago_order_id
        if (!externalId) {
             throw new Error("ID de orden externa no encontrado")
        }

        // 2. Get API Key & Config
        const pagoApiKey = Deno.env.get('PAGO_PAGO_API_KEY')!
        const PAGO_PAGO_URL = Deno.env.get('PAGO_PAGO_CANCEL_URL') || "https://pagoapago.com/api/v1/cancel" // Fallback or strict env

        console.log(`Cancelling order ${order_id} (External: ${externalId}) via Pago a Pago`)

        // 3. Cancel on Provider
        const response = await fetch(PAGO_PAGO_URL, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'pago_pago_api': pagoApiKey
            },
            body: JSON.stringify({ order_id: externalId }) // Send External ID
        })

        const data = await response.json()

        // 3. Update Local DB Status to 'cancelled'
        if (response.ok) {
            const { error: updateError } = await supabaseClient
                .from('clover_orders')
                .update({ 
                    status: 'cancelled',
                    updated_at: new Date().toISOString(),
                    extra_data: { 
                        cancelled_at: new Date().toISOString(),
                        cancellation_response: data 
                    }
                })
                .eq('id', order_id)

            if (updateError) {
                console.error("Failed to update order status locally:", updateError)
                // We still return success because the payment gateway cancelled it.
            } else {
                console.log(`Order ${order_id} marked as cancelled in DB.`)
            }
        }

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
