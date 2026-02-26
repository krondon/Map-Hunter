// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    // Manejo de solicitudes OPTIONS para CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Validación de Seguridad Adaptativa
        const webhookSource = req.headers.get('x-webhook-source')
        const userAgent = req.headers.get('user-agent')

        console.log("Headers received:", JSON.stringify(Object.fromEntries(req.headers.entries())))

        const isValidSource = (webhookSource === 'pagoapago-payment-processor')
        const isValidAgent = (userAgent && userAgent.includes('PagoAPago-Webhook-Dispatcher'))

        if (!isValidSource && !isValidAgent) {
            console.error(`[SECURITY ALERT] Invalid Request. Source: ${webhookSource}, Agent: ${userAgent}`)
            return new Response(JSON.stringify({ error: "Unauthorized source/agent" }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Inicializamos Supabase con Service Role Key para saltar RLS y poder leer/escribir clover_orders
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const body = await req.json()
        console.log("Webhook payload received:", JSON.stringify(body))

        const { event, data } = body
        const orderId = data?.order_id

        if (!orderId) {
            console.warn("Payload missing order_id, cannot process.")
            return new Response(JSON.stringify({ error: "Missing order_id" }), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 2. Mapeo de Eventos (Switch Logic)
        let newStatus = 'pending'
        let failureReason = null

        switch (event) {
            case 'payment.completed':
            case 'payment.paid':
                newStatus = 'success'
                break
            case 'payment.failed':
            case 'payment.error':
                newStatus = 'error'
                if (data.error_message) {
                    failureReason = data.error_message
                } else if (data.message) {
                    failureReason = data.message
                }
                break
            case 'payment.cancelled':
                newStatus = 'cancelled'
                break
            case 'payment.expired':
                newStatus = 'expired'
                break
            default:
                console.warn(`Unknown event type: ${event}`)
                newStatus = 'unknown'
        }

        // 3. Persistencia en clover_orders
        // Se ejecuta para cualquier estado conocido excepto 'unknown' y 'pending' (si no cambia nada)
        // Ojo: 'pending' podría ser útil si queremos actualizar metadata, pero por ahora nos centramos en cambios de estado.
        if (newStatus !== 'unknown') {
            console.log(`Processing update for order ${orderId}. New Status: ${newStatus}`)

            // Paso A: Obtener la orden existente para preservar extra_data
            const { data: existingOrder, error: fetchError } = await supabaseClient
                .from('clover_orders')
                .select('id, status, extra_data')
                .eq('pago_pago_order_id', orderId)
                .single()

            if (fetchError) {
                console.error(`Error fetching existing order ${orderId}:`, fetchError)
                // Si no existe, no podemos actualizar. Retornamos 200 para no bloquear la pasarela.
                // A menos que sea un error de conexión, pero asumiremos que si no lo encuentra es grave.
            } else if (existingOrder) {
                // Paso B: Preparar updateData
                // Preservamos el existingOrder.extra_data y hacemos merge con lo nuevo
                let finalExtraData = existingOrder.extra_data || {}

                // Si el payload trae new extra_data, lo mezclamos (prioridad al payload o al existente? 
                // Usualmente el payload trae menos datos en error. Mejor mergeamos con cuidado).
                if (data.extra_data) {
                    finalExtraData = { ...finalExtraData, ...data.extra_data }
                }

                // Inyectar failure_reason si existe
                if (failureReason) {
                    finalExtraData.failure_reason = failureReason
                }

                // Inject entire payload snapshot for debugging trace (optional but useful)
                finalExtraData.last_webhook_event = {
                    event: event,
                    received_at: new Date().toISOString(),
                    payload_subset: { ...data, extra_data: 'omitted_recursion' }
                }

                const updateData: any = {
                    status: newStatus,
                    updated_at: new Date().toISOString(),
                    extra_data: finalExtraData,
                }

                if (data.transaction_id) {
                    updateData.transaction_id = data.transaction_id
                }
                if (data.reference) {
                    updateData.bank_reference = data.reference
                }

                // Paso C: Update
                const { data: updatedRows, error: updateError } = await supabaseClient
                    .from('clover_orders')
                    .update(updateData)
                    .eq('pago_pago_order_id', orderId)
                    .select()

                if (updateError) {
                    console.error(`Failed to update DB for order ${orderId}:`, updateError)
                } else {
                    console.log(`Order ${orderId} successfully updated to ${newStatus}.`)
                }
            } else {
                console.warn(`Order ${orderId} not found in DB. Skipping update.`)
            }
        }

        // 4. Protocolo de Respuesta
        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        console.error("Critical Webhook Error:", error)
        return new Response(JSON.stringify({ error: "Internal Server Error handled" }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200, // Always 200 to acknowledge receipt
        })
    }
})
