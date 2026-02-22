import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseHTML } from "https://esm.sh/linkedom@0.16.8"; 

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── Configuration ───────────────────────────────────────────────────────────
const BCV_URL = "https://www.bcv.org.ve/";

// DEFINICIÓN DE PROXIES CON REGLAS DE CODIFICACIÓN ESPECÍFICAS
const PROXIES = [
  {
    name: "corsproxy.io",
    base: "https://corsproxy.io/?",
    encode: false // Este proxy prefiere la URL cruda
  },
  {
    name: "allorigins",
    base: "https://api.allorigins.win/raw?url=",
    encode: true // Este requiere encodeURIComponent
  },
  {
    name: "thingproxy",
    base: "https://thingproxy.freeboard.io/fetch/",
    encode: false
  },
  {
    name: "codetabs",
    base: "https://api.codetabs.com/v1/proxy?quest=",
    encode: true
  }
];

const MAX_GLOBAL_RETRIES = 2; 
const FETCH_TIMEOUT_MS = 20000;
const MIN_VALID_RATE = 1.0;
const MAX_VALID_RATE = 1000.0;

// ─── Helpers ─────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Intenta descargar el HTML probando múltiples proxies con su formato específico.
 */
async function fetchBcvHtmlWithFallback(): Promise<string> {
  let lastError: Error | null = null;
  const controller = new AbortController();
  // Un solo timeout largo para todo el intento es mejor que timeouts cortos individuales
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS * 2);

  try {
    for (const proxy of PROXIES) {
      try {
        // Construcción Inteligente de la URL
        const targetUrl = proxy.encode 
          ? `${proxy.base}${encodeURIComponent(BCV_URL)}`
          : `${proxy.base}${BCV_URL}`;
        
        console.log(`[update-rate] Trying Proxy: ${proxy.name}...`);

        const response = await fetch(targetUrl, {
          signal: controller.signal,
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache"
          },
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status} ${response.statusText}`);
        }

        const text = await response.text();
        
        // Validación de contenido: Si es muy corto, probablemente es un error del proxy
        if (!text || text.length < 500) {
           throw new Error("Response too short (likely proxy error page)");
        }

        // Validación específica: Debe contener "Banco Central de Venezuela" o "Dólar"
        if (!text.includes("Banco Central") && !text.includes("Dólar") && !text.includes("dolar")) {
           throw new Error("Content does not look like BCV page");
        }
        
        console.log(`[update-rate] ✅ Proxy Success: ${proxy.name}`);
        clearTimeout(timeoutId);
        return text; 

      } catch (error) {
        console.warn(`[update-rate] ⚠️ Proxy Failed (${proxy.name}): ${error.message}`);
        lastError = error;
        // Continuamos al siguiente proxy
      }
    }
  } finally {
    clearTimeout(timeoutId);
  }

  throw new Error(`All proxies failed. Last error: ${lastError?.message}`);
}

function parseUsdRate(html: string): number {
  const { document } = parseHTML(html);
  if (!document) throw new Error("Failed to parse HTML document");

  // Estrategias de Selectores (Ordenadas por probabilidad)
  
  // 1. Selector ID Directo (Más común en BCV)
  const dolarElement = document.querySelector("#dolar");
  if (dolarElement) {
    const rate = extractRateFromText(dolarElement.textContent);
    if (rate) return rate;
  }

  // 2. Búsqueda semántica en etiquetas Strong (donde suelen poner el texto)
  const strongTags = document.querySelectorAll("strong");
  for (const strong of strongTags) {
    const text = strong.textContent || "";
    // Buscamos patrones como "USD" o "Dólar"
    if (text.includes("USD") || text.includes("Dólar") || text.includes("Bs")) {
       // A veces el número está dentro del mismo strong
       let rate = extractRateFromText(text);
       if (rate) return rate;

       // A veces está en el padre o el siguiente hermano
       if (strong.parentElement) {
         rate = extractRateFromText(strong.parentElement.textContent);
         if (rate) return rate;
       }
    }
  }

  // 3. Fallback: Buscar en todo el body por el patrón numérico cerca de la palabra USD
  // Esto es costoso pero útil si cambian el DOM
  const bodyText = document.body.textContent || "";
  const usdIndex = bodyText.indexOf("USD");
  if (usdIndex !== -1) {
    // Tomamos un fragmento de texto alrededor de "USD"
    const snippet = bodyText.substring(usdIndex, usdIndex + 50);
    const rate = extractRateFromText(snippet);
    if (rate) return rate;
  }

  throw new Error("Could not find USD exchange rate in BCV page DOM.");
}

function extractRateFromText(text: string | null): number | null {
  if (!text) return null;
  // Limpiamos basura pero dejamos comas y puntos
  const cleaned = text.replace(/[^\d,.]/g, " ").trim();
  
  // Buscamos tokens que parezcan números
  const tokens = cleaned.split(/\s+/);
  
  for (const token of tokens) {
    // Debe tener al menos una coma o punto y ser mayor a 3 chars
    if (token.length > 3 && (token.includes(",") || token.includes("."))) {
      let numStr = token;
      
      // Lógica de Venezuela: El separador decimal suele ser coma (,)
      // Si tiene punto (.) suele ser miles.
      // Ejemplo: 54,1234 o 1.234,56
      
      if (numStr.includes(",") && numStr.includes(".")) {
         // Formato mixto: 1.234,56 -> Quitamos punto, cambiamos coma
         if (numStr.lastIndexOf(",") > numStr.lastIndexOf(".")) {
            numStr = numStr.replace(/\./g, "").replace(",", ".");
         } else {
            // Formato gringo: 1,234.56 -> Quitamos coma
            numStr = numStr.replace(/,/g, "");
         }
      } else if (numStr.includes(",")) {
         // Solo coma: Asumimos decimal (54,23)
         numStr = numStr.replace(",", ".");
      }
      
      const val = parseFloat(numStr);
      if (!isNaN(val) && val > 0 && val < 10000) { // Sanity check básico
        return val;
      }
    }
  }
  return null;
}

function validateRate(rate: number): void {
  if (isNaN(rate)) throw new Error("Parsed rate is NaN");
  if (rate <= 0) throw new Error(`Rate must be positive, got: ${rate}`);
  if (rate < MIN_VALID_RATE || rate > MAX_VALID_RATE) {
    throw new Error(`Rate ${rate} is outside valid range [${MIN_VALID_RATE}, ${MAX_VALID_RATE}]`);
  }
}

// ─── Main Handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const startTime = Date.now();
  let lastError: Error | null = null;

  // ── Global Retry Loop ──
  for (let attempt = 1; attempt <= MAX_GLOBAL_RETRIES; attempt++) {
    try {
      console.log(`[update-rate] Global Attempt ${attempt}/${MAX_GLOBAL_RETRIES}...`);

      const html = await fetchBcvHtmlWithFallback();
      const newRate = parseUsdRate(html);
      
      console.log(`[update-rate] Parsed rate: ${newRate}`);
      validateRate(newRate);

      // GET OLD RATE
      const { data: currentConfig } = await supabaseAdmin
        .from("app_config")
        .select("value")
        .eq("key", "bcv_exchange_rate")
        .maybeSingle();

      const oldRate = currentConfig ? parseFloat(currentConfig.value) : null;

      // UPDATE – use update().eq() instead of upsert() to avoid any
      // conflict resolution issues. The row is always seeded by migration.
      const { error: updateError } = await supabaseAdmin
        .from("app_config")
        .update({
          value: newRate,
          updated_at: new Date().toISOString(),
          updated_by: null,
        })
        .eq("key", "bcv_exchange_rate");

      if (updateError) throw new Error(updateError.message);

      // AUDIT
      await supabaseAdmin.from("exchange_rate_history").insert({
        rate: newRate,
        previous_rate: oldRate,
        source: "bcv_scraper_smart_proxy",
        scraped_at: new Date().toISOString(),
      });

      const elapsed = Date.now() - startTime;
      return new Response(
        JSON.stringify({
          success: true,
          old_rate: oldRate,
          new_rate: newRate,
          elapsed_ms: elapsed
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );

    } catch (error) {
      lastError = error;
      console.error(`[update-rate] Attempt ${attempt} failed: ${error.message}`);
      if (attempt < MAX_GLOBAL_RETRIES) await sleep(2000);
    }
  }

  // FAILURE
  const elapsed = Date.now() - startTime;
  const errorMsg = lastError?.message ?? "Unknown error";
  
  await supabaseAdmin.from("exchange_rate_history").insert({
      rate: null,
      previous_rate: null,
      source: "bcv_error",
      error_message: errorMsg,
      scraped_at: new Date().toISOString(),
  });

  return new Response(
    JSON.stringify({ success: false, error: errorMsg }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 502 }
  );
});