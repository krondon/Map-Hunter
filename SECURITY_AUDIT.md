# 🕵️‍♂️ Auditoría de Seguridad Integral: Flutter & Supabase

**Proyecto:** MapHunter (Juego_QR)  
**Fecha:** 2026-02-19  
**Postura:** Zero Trust — Todo input es hostil, todo cliente es un atacante potencial.

---

## 1. Topología del Riesgo (Resumen Arquitectónico)

```mermaid
graph TB
    subgraph "Cliente Flutter (Web / Mobile)"
        A[".env cargado via dotenv"] --> B["Supabase.initialize(anonKey)"]
        B --> C["Edge Functions (auth-service, game-api...)"]
        B --> D["RPCs PostgreSQL (place_bets_batch, secure_clover_payment...)"]
        B --> E["Queries directos (profiles, events, bets...)"]
    end

    subgraph "Supabase Backend"
        C --> F["Service Role Key (en Edge Functions)"]
        D --> G["SECURITY DEFINER Functions"]
        E --> H["RLS Policies"]
    end

    style A fill:#ff4444,stroke:#cc0000,color:#fff
    style F fill:#ff8800,stroke:#cc6600,color:#fff
    style G fill:#ffcc00,stroke:#aa8800,color:#000
```

### Puntos ciegos detectados:

1. **Flujo de datos bidireccional sin gateway:** El cliente Flutter invoca directamente tanto Edge Functions como RPCs de PostgreSQL. No existe un API Gateway centralizado que aplique rate-limiting, WAF, o validación unificada.
2. **Conflicto de Políticas RLS y RPCs:** La migración `20260220_security_patches.sql` soluciona correctamente vulnerabilidades en `place_bets_batch` y `resolve_event_bets`. Sin embargo, **no elimina la política RLS pública** creada en `20260218_bets_rls.sql` ("Public can view all bets"), lo que mantiene la tabla `bets` expuesta. Además, vulnerabilidades críticas en pagos (`secure_clover_payment`) persisten.
3. **Secretos en `.env` embebido en el build web:** El archivo `.env` se carga en runtime con `dotenv.load`. En Flutter Web esto se compila en JavaScript y **el contenido del `.env` queda expuesto** en el bundle final.
4. **Duplicidad de endpoints:** `game-api/index.ts` y `admin-actions/index.ts` ambos tienen un endpoint `approve-request`. El primero **NO tiene verificación de admin**.

---

## 2. Vulnerabilidades Críticas (Prioridad 1 — Bloqueantes)

---

### 🔴 VULN-01: Escalación de Privilegios en `game-api/approve-request`

- **📂 Archivo(s) afectado(s):** `supabase/edge-functions/game-api/index.ts` (líneas 227-268)
- **🔍 Lógica Vulnerable:** El endpoint `approve-request` usa `SUPABASE_SERVICE_ROLE_KEY` para aprobar solicitudes y crear jugadores. **No verifica que el usuario autenticado sea admin.** Cualquier usuario autenticado puede aprobar cualquier solicitud de juego.

```typescript
// VULNERABLE (game-api/index.ts:227-267)
if (req.method === "POST" && path === "approve-request") {
  const { requestId } = await req.json();
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", // ← Service Role sin verificar admin
  );
  // ... aprueba la solicitud sin verificar rol
}
```

- **🛡️ Solución:** Eliminar este endpoint en `game-api/index.ts` y usar exclusivamente `admin-actions/index.ts` que sí tiene verificación de admin (línea 38-52). Alternativamente, agregar la misma verificación de admin:

```typescript
// ANTES de usar Service Role:
const { data: profile } = await supabaseClient
  .from("profiles")
  .select("role")
  .eq("id", user.id)
  .single();
if (profile?.role !== "admin") {
  return new Response(JSON.stringify({ error: "Forbidden" }), {
    status: 403,
    headers: corsHeaders,
  });
}
```

---

### 🔴 VULN-02: IDOR en `secure_clover_payment` — Robo de fondos de cualquier usuario

- **📂 Archivo(s) afectado(s):** `supabase/migrations/20260213_secure_clover_payment.sql` (líneas 7-53)
- **🔍 Lógica Vulnerable:** La función acepta `p_user_id` como parámetro y **NO valida** que `p_user_id == auth.uid()`. Además, tiene `GRANT EXECUTE` a `authenticated`, lo que permite que cualquier usuario autenticado invoque esta función directamente vía RPC con el `user_id` de otra persona para **vaciar su wallet**.

```sql
-- VULNERABLE: Acepta cualquier user_id
CREATE OR REPLACE FUNCTION secure_clover_payment(
  p_user_id UUID,         -- ← No se valida contra auth.uid()
  p_amount INTEGER,
  p_reason TEXT DEFAULT 'clover_payment'
) ... SECURITY DEFINER ...

GRANT EXECUTE ON FUNCTION secure_clover_payment(UUID, INTEGER, TEXT) TO authenticated;
```

- **🛡️ Solución:**

```sql
CREATE OR REPLACE FUNCTION secure_clover_payment(
  p_user_id UUID,
  p_amount INTEGER,
  p_reason TEXT DEFAULT 'clover_payment'
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current INTEGER;
  v_new INTEGER;
BEGIN
  -- [SECURITY PATCH] Validar que solo se deduzca del propio usuario
  -- Excepción: funciones internas SECURITY DEFINER que llaman a esta
  -- nunca exponen auth.uid() (será NULL), así que agregamos un bypass controlado.
  IF auth.uid() IS NOT NULL AND p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Security Violation: Cannot debit another user.';
  END IF;
  -- ... resto igual
```

> [!CAUTION]
> Esta vulnerabilidad permite **robo directo de moneda virtual** de cualquier usuario. Un atacante puede invocar `supabase.rpc('secure_clover_payment', { p_user_id: 'UUID-de-victima', p_amount: 99999, p_reason: 'theft' })`.

---

### 🔴 VULN-03: IDOR en `join_online_paid_event` — Pagar con fondos ajenos

- **📂 Archivo(s) afectado(s):** `supabase/migrations/20260213_approve_and_pay_event_entry.sql` (líneas 165-237)
- **🔍 Lógica Vulnerable:** `join_online_paid_event` acepta `p_user_id` y `p_event_id` como parámetros, llama a `secure_clover_payment(p_user_id, ...)` y crea un `game_player` para `p_user_id`. **No valida `auth.uid()`**. Un atacante puede inscribir a cualquier usuario y cobrarle la entrada.

```sql
CREATE OR REPLACE FUNCTION join_online_paid_event(
  p_user_id UUID,      -- ← Sin validación contra auth.uid()
  p_event_id UUID
) RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
```

- **🛡️ Solución:**

```sql
-- Agregar al inicio del cuerpo de la función:
IF p_user_id != auth.uid() THEN
  RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
END IF;
```

---

### 🔴 VULN-04: Secretos expuestos en la build Web (Flutter + dotenv)

- **📂 Archivo(s) afectado(s):**
  - `.env` (líneas 1-10)
  - `lib/main.dart` (línea 64)
  - `lib/features/social/screens/wallet_screen.dart` (línea 1273)
- **🔍 Lógica Vulnerable:** `flutter_dotenv` carga el archivo `.env` en runtime. En Flutter Web, el `.env` se empaqueta como un asset dentro del bundle JavaScript. **Cualquier usuario puede extraer `SUPABASE_ANON_KEY` y `PAGO_PAGO_API_KEY` inspeccionando el bundle.**

  Además, `.env` línea 10 contiene credenciales de base de datos en texto plano:

  ```
  npx supabase db dump --db-url "postgresql://postgres.hyjelngckvqoanckqwep:euN8QGQBKRqiW.x@aws-0-us-west-2.pooler.supabase.com:6543/postgres" -f schema.sql
  ```

- **🛡️ Solución:**
  1. **Eliminar la línea 10** del `.env` inmediatamente (la contraseña de la BD está expuesta).
  2. **Rotar la contraseña** de la base de datos desde el dashboard de Supabase.
  3. **Mover `PAGO_PAGO_API_KEY`** a las Edge Functions como secreto de Supabase (ya se hace en `api_pay_orders`), y eliminarla del `.env` del cliente.
  4. Para Web: usar `--dart-define` en tiempo de build en lugar de `dotenv`:
     ```bash
     flutter build web --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
     ```

---

### 🔴 VULN-05: Webhook sin autenticación criptográfica

- **📂 Archivo(s) afectado(s):** `supabase/edge-functions/pago-a-pago-webhook/index.ts` (líneas 17-31)
- **🔍 Lógica Vulnerable:** La validación del webhook se basa **únicamente en headers HTTP** (`x-webhook-source` y `user-agent`), los cuales son triviales de falsificar. Un atacante puede enviar payloads `payment.completed` para acreditar tréboles sin pago real.

```typescript
// VULNERABLE: Headers son triviales de falsificar
const isValidSource = webhookSource === "pagoapago-payment-processor";
const isValidAgent =
  userAgent && userAgent.includes("PagoAPago-Webhook-Dispatcher");
```

- **🛡️ Solución:** Implementar verificación HMAC con un secreto compartido:

```typescript
import { hmac } from "https://deno.land/x/hmac@v2.0.1/mod.ts";

const WEBHOOK_SECRET = Deno.env.get("PAGO_PAGO_WEBHOOK_SECRET") ?? "";
const signature = req.headers.get("x-signature");
const rawBody = await req.text();
const expectedSignature = hmac(
  "sha256",
  WEBHOOK_SECRET,
  rawBody,
  "utf8",
  "hex",
);

if (signature !== expectedSignature) {
  return new Response(JSON.stringify({ error: "Invalid signature" }), {
    status: 401,
  });
}
const body = JSON.parse(rawBody);
```

---

### 🔴 VULN-06: Race Condition en `sabotage-rival` + Coin Deduction no atómica

- **📂 Archivo(s) afectado(s):** `supabase/edge-functions/game-api/index.ts` (líneas 271-313)
- **🔍 Lógica Vulnerable:** La deducción de monedas usa un patrón `read-then-write` no atómico: `SELECT coins → UPDATE coins = coins - 50`. Si se envían múltiples requests simultáneos, el usuario puede sabotear muchas veces con el mismo saldo (TOCTOU race condition).

```typescript
// VULNERABLE: Race condition
const { data: userProfile } = await supabaseAdmin
  .from("profiles")
  .select("coins")
  .eq("id", user.id)
  .single();

if (!userProfile || userProfile.coins < 50) {
  return error;
}

// Otra request puede pasar el check antes de este update
await supabaseAdmin
  .from("profiles")
  .update({ coins: userProfile.coins - 50 }) // ← No atómico
  .eq("id", user.id);
```

- **🛡️ Solución:** Usar una función RPC atómica con `SELECT ... FOR UPDATE`:

```sql
CREATE OR REPLACE FUNCTION sabotage_rival(p_rival_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_coins INTEGER;
BEGIN
  IF p_rival_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot sabotage yourself');
  END IF;

  SELECT coins INTO v_coins FROM profiles WHERE id = auth.uid() FOR UPDATE;
  IF v_coins < 50 THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient coins');
  END IF;

  UPDATE profiles SET coins = coins - 50 WHERE id = auth.uid();
  UPDATE profiles SET status = 'frozen', frozen_until = NOW() + interval '5 minutes'
    WHERE id = p_rival_id;

  RETURN json_build_object('success', true);
END; $$;
```

---

## 3. Vulnerabilidades Medias y Buenas Prácticas (Prioridad 2)

---

### 🟡 VULN-07: CORS Wildcard `*` en todas las Edge Functions

- **📂 Archivo(s) afectado(s):** Todas las Edge Functions en `supabase/edge-functions/*/index.ts`
- **🔍 Problema:** `Access-Control-Allow-Origin: *` permite que cualquier dominio malicioso invoque las APIs desde un navegador.
- **🛡️ Solución:** Restringir a dominios conocidos:

```typescript
const ALLOWED_ORIGINS = [
  'https://tu-dominio.com',
  'http://localhost:3000', // solo dev
];
const origin = req.headers.get('origin') ?? '';
const corsOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
const corsHeaders = { 'Access-Control-Allow-Origin': corsOrigin, ... };
```

---

### 🟡 VULN-08: Race Condition en `AdminService._addToWallet`

- **📂 Archivo(s) afectado(s):** `lib/features/admin/services/admin_service.dart` (líneas 200-213)
- **🔍 Problema:** Patrón `read-then-write` no atómico en Dart. Si se invoca múltiples veces concurrentemente, puede causar pérdida o duplicación de fondos. Aunque esto se ejecuta del lado admin, sigue siendo una violación de integridad.

```dart
// VULNERABLE: Read-then-write
Future<void> _addToWallet(String userId, int amount) async {
  final res = await _supabase.from('profiles').select('clovers').eq('id', userId).single();
  final int current = res['clovers'] ?? 0;
  await _supabase.from('profiles').update({'clovers': current + amount}).eq('id', userId);
}
```

- **🛡️ Solución:** Usar una RPC atómica:

```sql
-- Ya existe secure_clover_payment para deducir; crear una para acreditar:
CREATE OR REPLACE FUNCTION credit_clovers(p_user_id UUID, p_amount INTEGER, p_reason TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin(auth.uid()) THEN RAISE EXCEPTION 'Admin required'; END IF;
  UPDATE profiles SET clovers = clovers + p_amount WHERE id = p_user_id;
  INSERT INTO wallet_ledger (user_id, amount, description) VALUES (p_user_id, p_amount, p_reason);
  RETURN json_build_object('success', true);
END; $$;
```

---

### 🟡 VULN-09: `PAGO_PAGO_API_KEY` cargada en el cliente (Mobile)

- **📂 Archivo(s) afectado(s):** `lib/features/social/screens/wallet_screen.dart` (línea 1273)
- **🔍 Problema:** La función `_processWithdrawal` lee la API key del `.env` del cliente y la envía directamente al endpoint externo. En mobile, esto es descompilable con herramientas como `jadx`/`flutter_decompiler`.

```dart
final apiKey = dotenv.env['PAGO_PAGO_API_KEY'] ?? '';
final service = PagoAPagoService(apiKey: apiKey);
```

- **🛡️ Solución:** Toda comunicación con la pasarela de pagos debe pasar por Edge Functions del servidor. El flujo `_processWithdrawalWithPlan` (línea 1315) ya hace esto correctamente. **Eliminar `_processWithdrawal` y `PAGO_PAGO_API_KEY` del `.env` del cliente.**

---

### 🟡 VULN-10: Funciones `SECURITY DEFINER` sin `SET search_path`

- **📂 Archivo(s) afectado(s):** Múltiples migraciones:
  - `20260213_secure_clover_payment.sql`
  - `20260213_approve_and_pay_event_entry.sql` (ambas funciones)
  - `20260211_create_distribute_prizes_rpc.sql`
  - `20260212_fix_race_completion_trigger.sql`
  - `20260209120000_move_coins_to_game_players.sql`
  - `20260218_betting_system.sql` (ambas funciones)
  - `20260218_betting_rules_and_payouts.sql`
  - `20260219_*.sql` (varias)
- **🔍 Problema:** Las funciones `SECURITY DEFINER` sin `SET search_path = public` son vulnerables a ataques de **search_path hijacking**. Un atacante podría crear un schema malicioso y hacer que la función resuelva tablas allí en lugar de en `public`.
- **🛡️ Solución:** Agregar `SET search_path = public` a todas las funciones `SECURITY DEFINER`. Ejemplo:

```sql
CREATE OR REPLACE FUNCTION secure_clover_payment(...)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- ← Agregar esta línea
AS $$ ... $$;
```

---

### 🟡 VULN-11: `flutter_secure_storage` en Flutter Web usa `localStorage`

- **📂 Archivo(s) afectado(s):** `lib/core/storage/secure_local_storage.dart`
- **🔍 Problema de plataforma Web:** `flutter_secure_storage` en Web **no tiene API nativa segura** equivalente a Keychain/Keystore. En la web, realiza fallback a `localStorage`, que es vulnerable a XSS. Si un atacante logra inyectar JS, puede leer el token de sesión de Supabase.
- **🛡️ Solución (Plataforma Web):**
  1. Configurar `FlutterSecureStorage` con `WebOptions` para usar `sessionStorage` (no persiste tras cerrar pestaña):
     ```dart
     final _storage = const FlutterSecureStorage(
       webOptions: WebOptions(dbName: 'app_secure', publicKey: 'app_key'),
     );
     ```
  2. Implementar Content Security Policy (CSP) estricta en `web/index.html`:
     ```html
     <meta
       http-equiv="Content-Security-Policy"
       content="default-src 'self'; script-src 'self'; connect-src 'self' https://hyjelngckvqoanckqwep.supabase.co"
     />
     ```
  3. Activar `httpOnly` cookies si migran a un backend personalizado futuro.

---

### 🟡 VULN-12: Política RLS contradictoria en tabla `bets`

- **📂 Archivo(s) afectado(s):**
  - `supabase/migrations/20260218_bets_rls.sql` (líneas 12-16)
  - `supabase/migrations/20260220_security_patches.sql` (líneas 207-222)
- **🔍 Problema:** Existen **dos migraciones contradictorias** para la misma tabla:
  - `20260218_bets_rls.sql`: crea `"Public can view all bets"` con `USING (true)` — **ABIERTO a todos.**
  - `20260220_security_patches.sql`: crea `"Users can view their own bets"` con `USING (auth.uid() = user_id)`.

  Si ambas políticas coexisten, PostgreSQL las evalúa con **OR**, lo que significa que la política pública (`USING (true)`) **anula completamente** la restricción por usuario. Cualquier persona puede ver las apuestas de todos los usuarios.

- **🛡️ Solución:**

```sql
-- Eliminar la política pública
DROP POLICY IF EXISTS "Public can view all bets" ON public.bets;

-- El pot total se calcula a través de la VIEW event_pools (ya existe)
-- No se necesita acceso público a los registros individuales de bets
```

---

### 🟡 VULN-13: `event_pools` VIEW otorga acceso a `anon`

- **📂 Archivo(s) afectado(s):** `supabase/migrations/20260220_security_patches.sql` (líneas 239-240)
- **🔍 Problema:** `GRANT SELECT ON public.event_pools TO anon` permite que solicitudes sin autenticación consulten los montos totales de apuestas. Esto es una fuga de información financiera a visitantes anónimos.
- **🛡️ Solución:**

```sql
REVOKE SELECT ON public.event_pools FROM anon;
-- Mantener solo: GRANT SELECT ON public.event_pools TO authenticated;
```

---

## 4. Análisis de Políticas RLS (Supabase)

### Tablas con RLS habilitado (confirmado en `schema.sql`):

| Tabla                  | RLS | Evaluación                                                       |
| ---------------------- | --- | ---------------------------------------------------------------- |
| `profiles`             | ✅  | OK — Policies estándar                                           |
| `events`               | ✅  | OK                                                               |
| `game_players`         | ✅  | OK                                                               |
| `game_requests`        | ✅  | OK                                                               |
| `bets`                 | ✅  | ⚠️ **Conflicto** — Dos políticas contradictorias (ver VULN-12)   |
| `wallet_ledger`        | ✅  | OK — Verificar que solo el usuario propietario lea sus registros |
| `clover_orders`        | ✅  | OK                                                               |
| `admin_audit_logs`     | ✅  | OK — Solo admins                                                 |
| `active_powers`        | ✅  | OK                                                               |
| `player_powers`        | ✅  | OK                                                               |
| `user_payment_methods` | ✅  | OK — Datos sensibles protegidos                                  |
| `prize_distributions`  | ✅  | OK                                                               |

### Tablas potencialmente sin RLS o con políticas demasiado permisivas:

| Tabla                         | Riesgo                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------- |
| `player_inventory`            | No se encontró `ENABLE ROW LEVEL SECURITY` en migraciones — verificar en schema |
| `player_completed_challenges` | Similar — verificar                                                             |
| `transactions`                | Similar — verificar                                                             |

### Funciones SECURITY DEFINER sin `SET search_path`:

| Función                          | Migración  | search_path |
| -------------------------------- | ---------- | ----------- |
| `secure_clover_payment`          | `20260213` | ❌ Falta    |
| `approve_and_pay_event_entry`    | `20260213` | ❌ Falta    |
| `join_online_paid_event`         | `20260213` | ❌ Falta    |
| `distribute_event_prizes`        | `20260211` | ❌ Falta    |
| `place_bets_batch` (original)    | `20260218` | ❌ Falta    |
| `resolve_event_bets` (original)  | `20260218` | ❌ Falta    |
| `place_bets_batch` (parcheado)   | `20260220` | ✅ OK       |
| `resolve_event_bets` (parcheado) | `20260220` | ✅ OK       |
| `is_admin`                       | `20260220` | ✅ OK       |
| `use_power_mechanic`             | `20260207` | ✅ OK       |

---

## 5. Resumen de Riesgos por Plataforma

### 🌐 Web-Specific

| Riesgo                                                               | Severidad  | Archivo                                      |
| -------------------------------------------------------------------- | ---------- | -------------------------------------------- |
| `.env` embebido en bundle JS (anon_key, API keys expuestas)          | 🔴 Crítico | `.env`, `lib/main.dart:64`                   |
| `flutter_secure_storage` cae a `localStorage` (XSS → robo de sesión) | 🟡 Medio   | `lib/core/storage/secure_local_storage.dart` |
| Sin CSP en `web/index.html`                                          | 🟡 Medio   | `web/index.html`                             |
| CORS `*` permite cross-origin abuse                                  | 🟡 Medio   | Todas las Edge Functions                     |

### 📱 Mobile-Specific

| Riesgo                                                         | Severidad | Archivo                                               |
| -------------------------------------------------------------- | --------- | ----------------------------------------------------- |
| `PAGO_PAGO_API_KEY` descompilable en APK/IPA                   | 🟡 Medio  | `lib/features/social/screens/wallet_screen.dart:1273` |
| OneSignal App ID hardcoded (no es secreto, pero facilita spam) | 🟢 Info   | `lib/main.dart:79`                                    |
| Sin ofuscación configurada (`--obfuscate --split-debug-info`)  | 🟡 Medio  | Build config                                          |

### 🔄 Cross-Platform (Backend)

| Riesgo                                                  | Severidad  | Archivo                                                   |
| ------------------------------------------------------- | ---------- | --------------------------------------------------------- |
| Escalación de privilegios en `game-api/approve-request` | 🔴 Crítico | `edge-functions/game-api/index.ts:227`                    |
| IDOR en `secure_clover_payment` (robo de fondos)        | 🔴 Crítico | `migrations/20260213_secure_clover_payment.sql:7`         |
| IDOR en `join_online_paid_event`                        | 🔴 Crítico | `migrations/20260213_approve_and_pay_event_entry.sql:165` |
| Webhook sin HMAC (falsificación de pagos)               | 🔴 Crítico | `edge-functions/pago-a-pago-webhook/index.ts:17`          |
| Race condition en `sabotage-rival`                      | 🔴 Crítico | `edge-functions/game-api/index.ts:271`                    |
| Credenciales DB en `.env` línea 10                      | 🔴 Crítico | `.env:10`                                                 |
| Políticas RLS contradictorias en `bets`                 | 🟡 Medio   | Migraciones `20260218` + `20260220`                       |
| SECURITY DEFINER sin search_path (6 funciones)          | 🟡 Medio   | Múltiples migraciones                                     |

---

## 6. Plan de Acción Priorizado

| #   | Acción                                                       | Impacto | Esfuerzo |
| --- | ------------------------------------------------------------ | ------- | -------- |
| 1   | Eliminar credenciales DB de `.env` línea 10 + rotar password | 🔴      | 5 min    |
| 2   | Agregar `auth.uid()` check a `secure_clover_payment`         | 🔴      | 15 min   |
| 3   | Agregar `auth.uid()` check a `join_online_paid_event`        | 🔴      | 10 min   |
| 4   | Eliminar endpoint `approve-request` de `game-api/index.ts`   | 🔴      | 5 min    |
| 5   | Implementar HMAC en webhook de pagos                         | 🔴      | 30 min   |
| 6   | Migrar `sabotage-rival` a RPC atómico                        | 🔴      | 30 min   |
| 7   | Eliminar política RLS `"Public can view all bets"`           | 🟡      | 5 min    |
| 8   | Agregar `SET search_path` a 6 funciones SECURITY DEFINER     | 🟡      | 20 min   |
| 9   | Eliminar `PAGO_PAGO_API_KEY` del `.env` del cliente          | 🟡      | 10 min   |
| 10  | Restringir CORS a dominios permitidos                        | 🟡      | 15 min   |
| 11  | Revocar `GRANT SELECT ON event_pools FROM anon`              | 🟡      | 2 min    |
| 12  | Usar `--dart-define` para Web en lugar de `dotenv`           | 🟡      | 30 min   |
| 13  | Agregar CSP a `web/index.html`                               | 🟡      | 10 min   |
| 14  | Configurar `--obfuscate` en build de release mobile          | 🟢      | 5 min    |
