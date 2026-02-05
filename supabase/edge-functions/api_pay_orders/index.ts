import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, pago_pago_api",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client for user authentication
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      },
    );

    // 1. AUTHENTICATE USER
    const {
      data: { user },
    } = await supabaseClient.auth.getUser();

    if (!user) {
      throw new Error("Unauthorized");
    }

    // 2. PARSE REQUEST - Only plan_id is accepted (SECURITY: no amount from client)
    const { plan_id } = await req.json();

    if (!plan_id) {
      throw new Error("Missing plan_id parameter");
    }

    console.log(
      `[api_pay_orders] Processing payment for user ${user.id}, plan_id: ${plan_id}`,
    );

    // 3. INITIALIZE ADMIN CLIENT (for bypassing RLS)
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      console.error("CRITICAL: SUPABASE_SERVICE_ROLE_KEY is missing!");
      throw new Error("Server Misconfiguration: Missing DB Permissions");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey,
    );

    // 4. VALIDATE PLAN FROM DATABASE (Server-Side Truth)
    const { data: plan, error: planError } = await supabaseAdmin
      .from("clover_plans")
      .select("id, name, clovers_quantity, price_usd, is_active")
      .eq("id", plan_id)
      .single();

    if (planError) {
      console.error("Plan fetch error:", planError);
      throw new Error(`Plan inválido: ${planError.message}`);
    }

    if (!plan) {
      throw new Error("Plan no encontrado");
    }

    if (!plan.is_active) {
      throw new Error("El plan seleccionado no está disponible");
    }

    // CRITICAL: Use price from DATABASE, not from client
    const amount = plan.price_usd;
    const cloversQuantity = plan.clovers_quantity;
    const currency = "USD"; // Always USD

    console.log(
      `[api_pay_orders] Plan validated: ${plan.name}, Price: $${amount} USD, Clovers: ${cloversQuantity}`,
    );

    // 5. FETCH USER PROFILE DATA (for payment gateway)
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("email, phone, dni")
      .eq("id", user.id)
      .single();

    if (profileError || !profile) {
      throw new Error("Perfil de usuario incompleto");
    }

    const { email, phone, dni } = profile;

    if (!email || !phone || !dni) {
      throw new Error("Perfil incompleto. Verifique email, teléfono y DNI.");
    }

    // 6. GET PAGO A PAGO API KEY
    const pagoApiKey = Deno.env.get("PAGO_PAGO_API_KEY");
    if (!pagoApiKey) {
      throw new Error("Server Misconfiguration: Missing PAGO_PAGO_API_KEY");
    }

    const PAGO_PAGO_URL = Deno.env.get("PAGO_PAGO_API_URL")!;

    // Calculate expiration (30 minutes)
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();

    // 7. PREPARE PAYLOAD FOR PAYMENT GATEWAY
    const payload = {
      amount: amount,
      currency: currency, // USD
      motive: `Compra de ${cloversQuantity} Tréboles - Plan ${plan.name}`,
      email: email,
      phone: phone,
      dni: dni,
      type_order: "EXTERNAL",
      expires_at: expiresAt,
      alias: `PLAN-${plan.name.toUpperCase()}-${user.id.substring(0, 8)}-${Date.now()}`,
      convert_from_usd: false,
      url_redirect: "io.supabase.treasurehunt://payment-return",
      extra_data: {
        user_id: user.id,
        plan_id: plan.id,
        plan_name: plan.name,
        clovers_amount: cloversQuantity,
        price_usd: amount,
      },
    };

    console.log(
      "[api_pay_orders] Sending to Pago a Pago:",
      JSON.stringify(payload),
    );

    // 8. CALL PAYMENT GATEWAY
    let data;

    // MOCK CHECK (For Dev/Test environments)
    if (
      PAGO_PAGO_URL.includes("pagoapago.com/v1") ||
      PAGO_PAGO_URL.includes("mock")
    ) {
      console.log("Simulating success via MOCK logic");
      data = {
        success: true,
        message: "Mock Order Created",
        data: {
          payment_url: "https://pagoapago.com/checkout/mock-" + Date.now(),
          order_id: `MOCK-${Date.now()}`,
        },
      };
    } else {
      // REAL API CALL
      const response = await fetch(PAGO_PAGO_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          pago_pago_api: pagoApiKey,
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errText = await response.text();
        throw new Error(
          `Pago a Pago API Error (${response.status}): ${errText}`,
        );
      }

      data = await response.json();
      console.log(
        "[api_pay_orders] Pago a Pago Response:",
        JSON.stringify(data),
      );
    }

    // 9. PARSE RESPONSE
    const orderId = data.data?.order_id || data.order_id;
    const paymentUrl = data.data?.payment_url || data.payment_url;

    if (!orderId || !paymentUrl) {
      console.error("Invalid Response Data:", data);
      if (data.success === false)
        throw new Error(data.message || "Unknown API Error");
      throw new Error("Missing order_id or payment_url in response");
    }

    // 10. PERSIST ORDER TO DATABASE
    console.log(`[api_pay_orders] Persisting order ${orderId}...`);

    const { error: dbError } = await supabaseAdmin
      .from("clover_orders")
      .insert({
        user_id: user.id,
        plan_id: plan.id, // NEW: Link to plan
        amount: amount,
        currency: currency,
        status: "pending",
        pago_pago_order_id: orderId,
        payment_url: paymentUrl,
        expires_at: expiresAt,
        extra_data: {
          plan_name: plan.name,
          clovers_amount: cloversQuantity,
          price_usd: amount,
          initiated_at: new Date().toISOString(),
          api_response: data,
          function_version: "v3-plans",
        },
      });

    if (dbError) {
      console.error("CRITICAL DB ERROR:", dbError);
      throw new Error(`Database Persistence Failed: ${dbError.message}`);
    }

    // 11. VERIFY PERSISTENCE
    const { data: verifyData, error: verifyError } = await supabaseAdmin
      .from("clover_orders")
      .select("id, status")
      .eq("pago_pago_order_id", orderId)
      .single();

    if (verifyError || !verifyData) {
      console.error("VERIFICATION FAILED:", verifyError);
    } else {
      console.log("VERIFICATION SUCCESS:", verifyData);
    }

    console.log("[api_pay_orders] Order persisted successfully.");

    // 12. RETURN SUCCESS RESPONSE
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          order_id: orderId,
          payment_url: paymentUrl,
          plan: {
            id: plan.id,
            name: plan.name,
            clovers: cloversQuantity,
            price_usd: amount,
          },
        },
        debug_info: {
          persistence_verified: !!verifyData,
          server_time: new Date().toISOString(),
          correlation_id: `v3-${Date.now()}`,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    console.error("[api_pay_orders] Error:", error);
    return new Response(
      JSON.stringify({
        error: error.message,
        success: false,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      },
    );
  }
});
