import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Manejo de CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Usamos las variables de entorno internas de Supabase
        // IMPORTANTE: No mapeamos la autorización del cliente (global: headers)
        // para permitir que servicios externos como Google Docs vean el PDF
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Descargar el PDF desde el bucket privado/público
        const { data, error } = await supabaseAdmin
            .storage
            .from('documents')
            .download('Terminos_y_Condiciones_Maphunter.pdf')

        if (error) {
            console.error('Error downloading PDF:', error)
            return new Response(
                JSON.stringify({ error: 'No se pudo encontrar el documento.' }),
                { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Retornamos el PDF directamente como un stream
        // Esto oculta la URL original de Supabase Storage
        return new Response(data, {
            headers: {
                ...corsHeaders,
                'Content-Type': 'application/pdf',
                'Content-Disposition': 'inline; filename="terminos.pdf"',
            },
        })

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
