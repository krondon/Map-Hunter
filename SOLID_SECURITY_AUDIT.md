# 🔐 Informe de Auditoría SOLID + Seguridad

##  MapHunter RPG - Análisis de Arquitectura y Vulnerabilidades

**Proyecto:** Juego_QR (MapHunte RPG)  
**Fecha:** 2026-01-13  
**Tipo:** Auditoría Combinada (Arquitectura + Seguridad)

---

## 🚨 Matriz de Riesgo Consolidada

| Componente                | Principio SOLID Violado | Vulnerabilidad de Seguridad Asociada                                                                                               |     Riesgo     |
| ------------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | :------------: |
| `admin-actions/index.ts`  | DIP (Acoplamiento)      | **Role check comentado** - Cualquier usuario autenticado puede ejecutar acciones admin (reset-event, approve-request, delete data) | 🔴 **CRÍTICO** |
| `PlayerProvider`          | SRP (God Object)        | Métodos admin (`toggleBanUser`, `deleteUser`) accesibles sin verificación de rol en tiempo de ejecución                            |  🔴 **ALTO**   |
| `PlayerProvider`          | SRP                     | Funciones debug (`debugAddPower`, `debugAddAllPowers`) en código producción - pueden ser invocadas si estado Flutter es manipulado |  🟠 **MEDIO**  |
| `QRScannerScreen`         | SRP                     | Sin sanitización de códigos QR - posible inyección si código malformado llega al backend                                           |  🟠 **MEDIO**  |
| Todos los Providers       | DIP                     | Acceso directo a `Supabase.instance.client` - imposibilita mocking para tests de seguridad                                         |  🟡 **BAJO**   |
| `puzzle_screen.dart`      | SRP (1333 líneas)       | Lógica de minijuegos mezclada con validación - dificulta auditar flujo de puntos                                                   |  🟡 **BAJO**   |
| `admin_login_screen.dart` | -                       | Control de rol solo en cliente (línea 95) - bypassable con manipulación de estado                                                  |  🟠 **MEDIO**  |
| Edge Functions            | ✅ Bien                 | `complete-clue` y `use_power_mechanic` validan en servidor                                                                         |   ✅ **OK**    |
| Secretos                  | ✅ Bien                 | `.env` para API keys, no hardcodeadas                                                                                              |   ✅ **OK**    |

---

## 🔴 Análisis de Impacto: Cómo la Mala Arquitectura Facilita Exploits

### 1. Escalación de Privilegios vía Edge Function

**Archivo:** [admin-actions/index.ts](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/supabase/functions/admin-actions/index.ts#L37-L40)

```typescript
// ⚠️ CRÍTICO: Check de admin COMENTADO
// Check if user is admin (simplified check for now)
// In production, check a 'role' column in profiles or use RLS
// const { data: profile } = await supabaseClient.from('profiles').select('role').eq('id', user.id).single()
// if (profile.role !== 'admin') throw new Error('Forbidden')
```

**Vector de Ataque:**

1. Usuario normal se autentica en la app móvil
2. Obtiene `access_token` de Supabase Auth
3. Llama directamente a Edge Function:

```bash
curl -X POST "https://[PROJECT].supabase.co/functions/v1/admin-actions/reset-event" \
  -H "Authorization: Bearer [USER_ACCESS_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{"eventId": "[TARGET_EVENT_ID]"}'
```

4. **Resultado:** Evento reseteado, todos los jugadores pierden progreso

**Por qué SRP/DIP lo empeoró:**

- `PlayerProvider` siendo "God Object" oculta la falta de validación entre capas
- Sin abstracción de repositorio, no hay punto único donde verificar roles
- Desarrollador asumió que "solo la UI web llama a estas funciones"

---

### 2. Manipulación de Estado Flutter para Acciones Admin

**Archivo:** [player_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/auth/providers/player_provider.dart#L792-L818)

```dart
// ❌ Sin verificación de rol antes de llamar RPC
Future<void> toggleBanUser(String userId, bool ban) async {
  try {
    await _supabase.rpc('toggle_ban', params: { ... });
    // ...
  }
}

Future<void> deleteUser(String userId) async {
  try {
    await _supabase.rpc('delete_user', params: { ... });
    // ...
  }
}
```

**Vector de Ataque (Avanzado):**

1. Atacante decompila APK o manipula estado en runtime
2. Modifica `_currentPlayer.role = 'admin'` en memoria
3. Navega a UI admin (que solo verifica rol en cliente)
4. Llama a `toggleBanUser()` o `deleteUser()`

**Mitigación Actual:**

- Los RPCs `toggle_ban` y `delete_user` **DEBEN** tener validación en PostgreSQL
- Verificar si funciones SQL tienen `SECURITY DEFINER` con check de rol

---

### 3. Códigos QR Sin Sanitización

**Archivo:** [qr_scanner_screen.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/screens/qr_scanner_screen.dart#L25-L40)

```dart
void _onDetect(BarcodeCapture capture) {
  for (final barcode in barcodes) {
    if (barcode.rawValue != null) {
      final code = barcode.rawValue!;  // ❌ Sin sanitización
      Navigator.pop(context, code);     // Pasa directo al caller
    }
  }
}
```

**Riesgo:**

- Si código QR contiene caracteres especiales SQL/noSQL
- Y el backend no sanitiza antes de queries
- Posible inyección (aunque Edge Functions usan cliente Supabase que parameteriza)

**Impacto Real:** BAJO (Supabase client previene SQLi) pero viola defensa en profundidad.

---

## 🛡️ Guía de Remediación

### 🔴 PRIORIDAD 1: Habilitar Check de Rol en Edge Function Admin

**Archivo:** `supabase/functions/admin-actions/index.ts`

```diff
+ // --- VALIDACIÓN DE ROL ADMIN ---
+ const { data: profile, error: profileError } = await supabaseClient
+   .from('profiles')
+   .select('role')
+   .eq('id', user.id)
+   .single();
+
+ if (profileError || profile?.role !== 'admin') {
+   return new Response(
+     JSON.stringify({ error: 'Forbidden: Admin role required' }),
+     { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
+   );
+ }
+ // --- FIN VALIDACIÓN ---

  const url = new URL(req.url);
  const path = url.pathname.split("/").pop();
```

**Ubicación:** Después de línea 35, antes de línea 42.

---

### 🔴 PRIORIDAD 2: Validación de Rol en Funciones SQL

**Archivo:** Migración SQL para Supabase

```sql
-- Función toggle_ban con validación de rol
CREATE OR REPLACE FUNCTION toggle_ban(user_id UUID, new_status TEXT)
RETURNS VOID AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- Obtener rol del usuario que llama
  SELECT role INTO caller_role FROM profiles WHERE id = auth.uid();

  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RAISE EXCEPTION 'Forbidden: Admin role required';
  END IF;

  -- Ejecutar acción
  UPDATE profiles SET status = new_status WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función delete_user con validación
CREATE OR REPLACE FUNCTION delete_user(user_id UUID)
RETURNS VOID AS $$
DECLARE
  caller_role TEXT;
BEGIN
  SELECT role INTO caller_role FROM profiles WHERE id = auth.uid();

  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RAISE EXCEPTION 'Forbidden: Admin role required';
  END IF;

  -- Soft delete o hard delete según preferencia
  UPDATE profiles SET status = 'deleted' WHERE id = user_id;
  -- O: DELETE FROM profiles WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### 🟠 PRIORIDAD 3: Eliminar/Proteger Funciones Debug en Producción

**Archivo:** [player_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/auth/providers/player_provider.dart#L821-L893)

```dart
// ═══════════════════════════════════════════════════════════════
// PROPUESTA: Mover a archivo separado y compilar condicionalmente
// ═══════════════════════════════════════════════════════════════

// Nuevo archivo: lib/debug/debug_player_extensions.dart
import 'package:flutter/foundation.dart';

extension DebugPlayerExtensions on PlayerProvider {
  /// Solo disponible en modo debug
  Future<void> debugAddPower(String powerSlug) async {
    if (!kDebugMode) {
      throw UnsupportedError('Debug methods not available in release');
    }
    // ... implementación
  }

  Future<void> debugToggleStatus(String status) async {
    if (!kDebugMode) {
      throw UnsupportedError('Debug methods not available in release');
    }
    // ... implementación
  }
}

// ═══════════════════════════════════════════════════════════════
// ALTERNATIVA: Compilación condicional con dart defines
// ═══════════════════════════════════════════════════════════════
// En pubspec.yaml o build:
// flutter build apk --dart-define=ENABLE_DEBUG_FEATURES=false
```

---

### 🟠 PRIORIDAD 4: Sanitización de Input QR

**Archivo:** `qr_scanner_screen.dart`

```dart
// Nuevo archivo: lib/core/utils/input_sanitizer.dart
class InputSanitizer {
  static const int maxQRLength = 256;

  /// Sanitiza código QR removiendo caracteres peligrosos
  static String sanitizeQRCode(String rawCode) {
    // 1. Limitar longitud
    if (rawCode.length > maxQRLength) {
      rawCode = rawCode.substring(0, maxQRLength);
    }

    // 2. Solo permitir caracteres alfanuméricos y algunos símbolos seguros
    final sanitized = rawCode.replaceAll(
      RegExp(r'[^a-zA-Z0-9\-_:.,]'),
      '',
    );

    // 3. Prevenir inyección de protocolos
    if (sanitized.toLowerCase().startsWith('javascript:') ||
        sanitized.toLowerCase().startsWith('data:')) {
      return '';
    }

    return sanitized;
  }
}

// ═══════════════════════════════════════════════════════════════
// Uso en QRScannerScreen
// ═══════════════════════════════════════════════════════════════
void _onDetect(BarcodeCapture capture) {
  for (final barcode in barcodes) {
    if (barcode.rawValue != null) {
      final rawCode = barcode.rawValue!;
      final code = InputSanitizer.sanitizeQRCode(rawCode); // ✅ Sanitizado

      if (code.isEmpty) {
        // QR inválido, mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código QR inválido')),
        );
        return;
      }

      Navigator.pop(context, code);
    }
  }
}
```

---

### 🟡 PRIORIDAD 5: Refactorizar PlayerProvider (Largo Plazo)

**Objetivo:** Separar responsabilidades para auditoría más clara

```dart
// ═══════════════════════════════════════════════════════════════
// ARQUITECTURA PROPUESTA
// ═══════════════════════════════════════════════════════════════

// 1. Interfaz para repositorio de usuarios (DIP)
abstract class IUserRepository {
  Future<Player?> fetchProfile(String userId);
  Future<void> updateProfile(String userId, Map<String, dynamic> data);
}

// 2. Servicio de autenticación separado
class AuthService {
  final IUserRepository _userRepo;
  final SupabaseClient _auth;

  AuthService(this._userRepo, this._auth);

  Future<Player?> login(String email, String password) async { ... }
  Future<void> logout() async { ... }
}

// 3. Servicio de administración CON validación de rol
class AdminService {
  final IUserRepository _userRepo;
  final SupabaseClient _client;

  AdminService(this._userRepo, this._client);

  Future<void> banUser(String adminId, String targetId, bool ban) async {
    // ✅ Validar rol en cliente como primera línea de defensa
    final admin = await _userRepo.fetchProfile(adminId);
    if (admin?.role != 'admin') {
      throw UnauthorizedError('Requiere rol admin');
    }

    // Backend también valida (defensa en profundidad)
    await _client.rpc('toggle_ban', params: { ... });
  }
}

// 4. PlayerProvider simplificado (solo coordinación UI)
class PlayerProvider extends ChangeNotifier {
  final AuthService _authService;
  final InventoryService _inventoryService;
  final AdminService _adminService; // Solo inyectado en contexto admin

  // Métodos solo delegan a servicios
}
```

---

## 📊 Resumen de Hallazgos por Categoría

### Secretos y Credenciales ✅

- **Estado:** OK
- `.env` usado correctamente para `SUPABASE_URL` y `SUPABASE_ANON_KEY`
- No se encontraron credenciales hardcodeadas en código

### Validación Server-Side ✅

- **Estado:** OK (parcial)
- `complete-clue`: Valida respuestas y progreso en Edge Function
- `use_power_mechanic`: RPC valida lógica de poderes
- **Pendiente:** Validación de rol en funciones admin

### Control de Acceso 🔴

- **Estado:** CRÍTICO
- Edge Function `admin-actions` sin validación de rol
- RPCs `toggle_ban`, `delete_user` requieren auditoría

### Sanitización de Input 🟠

- **Estado:** MEJORABLE
- QR codes pasan sin filtrar
- Formularios de minijuegos no sanitizan (aunque backend parameteriza queries)

### Arquitectura y Testeabilidad 🟡

- **Estado:** PREOCUPANTE
- Sin abstracción de repositorio = sin mocking para tests de seguridad
- God Objects dificultan auditoría de flujos de datos

---

## ✅ Lo Que Está Bien

1. **Lógica crítica de juego en backend:**
   - Completar pistas, ganar XP, usar poderes → Edge Functions
2. **Supabase Auth** correctamente integrado:
   - Tokens JWT manejados por SDK
   - Sesiones persistentes
3. **RLS implícito** en algunas tablas:
   - `user_clue_progress` filtrado por `user_id`
4. **kDebugMode** para botones de desarrollo:
   - Compilación release los excluye de UI

---

## 📋 Checklist de Remediación

- [ ] 🔴 **Habilitar check de rol** en `admin-actions/index.ts`
- [ ] 🔴 **Auditar funciones SQL** `toggle_ban`, `delete_user`
- [ ] 🟠 **Eliminar métodos debug** de producción o protegerlos
- [ ] 🟠 **Implementar sanitización** de códigos QR
- [ ] 🟠 **Añadir verificación de rol** en cliente como defensa adicional
- [ ] 🟡 **Refactorizar PlayerProvider** siguiendo SRP
- [ ] 🟡 **Crear capa de abstracción** para Supabase (DIP)
- [ ] 🟡 **Implementar tests de seguridad** con repositorios mockeados

---

## 🔗 Referencias de Archivos Clave

| Archivo                                                                                                                            | Líneas Críticas  | Issue                   |
| ---------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------- |
| [admin-actions/index.ts](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/supabase/functions/admin-actions/index.ts)           | 37-40            | Role check comentado    |
| [player_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/auth/providers/player_provider.dart)      | 792-818, 821-893 | Admin + Debug methods   |
| [admin_login_screen.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/admin/screens/admin_login_screen.dart) | 86-103           | Client-only role check  |
| [qr_scanner_screen.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/screens/qr_scanner_screen.dart)    | 25-40            | No sanitization         |
| [game-play/index.ts](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/supabase/functions/game-play/index.ts)                   | 138-380          | ✅ Server validation OK |

---

_Informe generado como parte de auditoría combinada de arquitectura y seguridad._
