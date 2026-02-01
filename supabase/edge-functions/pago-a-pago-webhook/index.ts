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
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 1. Validate Source
        const webhookSource = req.headers.get('x-webhook-source')
        if (webhookSource !== 'pagoapago-payment-processor') {
            console.error("Invalid Webhook Source:", webhookSource)
            return new Response("Unauthorized", { status: 401 })
        }

        const body = await req.json()
        console.log("Webhook received:", JSON.stringify(body))

        // Extract event and data based on documentation/screenshots
        const event = body.event
        const data = body.data || {}
        const extraData = data.extra_data || {}

        // Safe extraction variables
        const orderId = data.order_id
        const userId = extraData.user_id
        // Map event to a status string for our DB
        let status = 'PENDING'

        if (event === 'payment.completed' || event === 'payment.paid') {
            status = 'PAID'
        } else if (event === 'payment.failed' || event === 'payment.error') {
            status = 'FAILED'
        } else if (event === 'payment.cancelled') {
            status = 'CANCELLED'
        } else if (event === 'payment.expired') {
            status = 'EXPIRED'
        } else {
            status = event || 'UNKNOWN'
        }

        if (!orderId) {
            throw new Error("Invalid payload: Missing order_id")
        }

        console.log(`Processing Event: ${event}, Order: ${orderId}, Status: ${status}, User: ${userId}`)

        // Verificar si ya existe la transacción
        const { data: existingTx } = await supabaseClient
            .from('payment_transactions')
            .select('*')
            .eq('order_id', orderId)
            .single()

        // Si no existe, crearla (o actualizar si ya existe)
        if (!existingTx) {
            if (userId) {
                await supabaseClient.from('payment_transactions').insert({
                    order_id: orderId,
                    user_id: userId,
                    status: status,
                    amount: data.amount || 0,
                    currency: data.currency || 'VES',
                    provider_data: body
                })
            } else {
                console.error("No userId found in webhook extra_data")
            }
        } else {
            await supabaseClient.from('payment_transactions').update({
                status: status,
                updated_at: new Date().toISOString(),
                provider_data: body // Guardar último payload
            }).eq('order_id', orderId)
        }

        // Si el estado es COMPLETADO/PAGADO, dar los tréboles
        if (status === 'PAID') {
            if (userId) {
                // Obtener el monto para calcular tréboles (1:1 con USD, no con VES)
                // Usamos 'clovers_amount' de extra_data si existe (lo enviamos desde api_pay_orders)
                const cloversAmount = extraData.clovers_amount ? Number(extraData.clovers_amount) : 0
                const fallbackAmount = data.amount || 0

                const cloversToAdd = Math.floor(cloversAmount > 0 ? cloversAmount : Number(fallbackAmount))

                console.log(`Crediting clovers: Source=${cloversAmount > 0 ? 'extra_data(USD)' : 'fallback(VES)'}, Amount=${cloversToAdd}`)

                if (cloversToAdd > 0) {
                    // Usar RPC o player_stats si existe, o actualizar profiles directamente
                    // Como clovers está en profiles:
                    const { data: profile } = await supabaseClient
                        .from('profiles')
                        .select('clovers')
                        .eq('id', userId)
                        .single()

                    const currentClovers = profile?.clovers || 0

                    await supabaseClient.from('profiles').update({
                        clovers: currentClovers + cloversToAdd
                    }).eq('id', userId)

                    console.log(`Added ${cloversToAdd} clovers to user ${userId}`)
                }
            }
        }

        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error("Webhook error:", error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
