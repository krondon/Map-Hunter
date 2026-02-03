import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Manejo de solicitudes OPTIONS para CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Validación de Seguridad Adaptativa
        // Documentación dice 'x-webhook-source', pero los logs muestran que no llega.
        // Logs muestran 'user-agent': 'PagoAPago-Webhook-Dispatcher/1.0'
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

        // Inicializamos Supabase con Service Role Key para saltar RLS
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
            // Retornamos 200 para evitar reintentos de la pasarela en payloads mal formados
            return new Response(JSON.stringify({ error: "Missing order_id" }), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 2. Mapeo de Eventos (Switch Logic)
        let newStatus = 'pending'

        switch (event) {
            case 'payment.completed':
            case 'payment.paid':
                newStatus = 'success'
                break
            case 'payment.failed':
            case 'payment.error':
                newStatus = 'error'
                break
            case 'payment.cancelled':
                newStatus = 'cancelled'
                break
            case 'payment.expired':
                newStatus = 'expired'
                break
            default:
                console.warn(`Unknown event type: ${event}`)
                newStatus = 'unknown' // Opcional: mantener el estado anterior o marcar como desconocido
        }

        // 3. Persistencia en clover_orders
        if (newStatus !== 'unknown' && newStatus !== 'pending') {
            console.log(`Updating order ${orderId} to status: ${newStatus}`)
            
            // data.transaction_id -> columna transaction_id (si existe en payload)
            // data.reference -> columna bank_reference (si existe en payload)
            
            const updateData: any = {
                status: newStatus,
                updated_at: new Date().toISOString(),
                extra_data: data.extra_data,
            }

            if (data.transaction_id) {
                updateData.transaction_id = data.transaction_id
            }
            if (data.reference) {
                updateData.bank_reference = data.reference
            }

            // Actualizamos la tabla clover_orders usando el pago_pago_order_id
            // Usamos select() para verificar si realmente se actualizó alguna fila
            const { data: updatedRows, error: updateError } = await supabaseClient
                .from('clover_orders')
                .update(updateData)
                .eq('pago_pago_order_id', orderId)
                .select()

            if (updateError) {
                console.error(`Failed to update DB for order ${orderId}:`, updateError)
            } else if (!updatedRows || updatedRows.length === 0) {
                console.error(`CRITICAL: Order ${orderId} NOT FOUND in clover_orders. Update failed silently (0 rows affected).`)
            } else {
                console.log(`Order ${orderId} successfully updated. Rows affected: ${updatedRows.length}`)
            }
        }

        // 4. Protocolo de Respuesta
        // Responder siempre con 200 OK para confirmar recepción
        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })

    } catch (error) {
        // Manejo de errores global
        console.error("Critical Webhook Error:", error)
        
        // Retornamos 200 OK incluso en error crítico para evitar bucle de reintentos
        // según buenas prácticas de webhooks si el error es interno nuestro.
        return new Response(JSON.stringify({ error: "Internal Server Error handled" }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    }
})
