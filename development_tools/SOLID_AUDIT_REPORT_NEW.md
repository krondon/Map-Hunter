# Reporte de Auditoría SOLID: Juego_QR

**Fecha:** 24 de Enero, 2026
**Auditor:** GitHub Copilot (Gemini 3 Pro)

## 1. Puntuación General: 45/100

El proyecto es funcional y hace uso de tecnologías modernas (Flutter + Supabase), pero la arquitectura interna muestra signos severos de "Spaghetti Code" encapsulado en clases Provider. El código es rígido, difícil de testear y propenso a errores en cascada (ripple effects) al realizar cambios. No sigue una arquitectura limpia real, sino una estructura de directorios que simula serlo.

---

## 2. Tabla de Violaciones

| Archivo | Principio Violado | Explicación Breve | Severidad |
| :--- | :--- | :--- | :--- |
| `player_provider.dart` | **SRP** (Single Resp.) | Es una "God Class" (782 líneas). Gestiona Auth, Perfil, Inventario, Compra, Bans y Lógica de Juego. Mezcla UI state con Business Logic y API calls. | **ALTA** |
| `game_provider.dart` | **SRP** | Gestiona Pistas, Vidas, Ranking Realtime, Estado de UI y Lógica de Carrera. Demasiadas responsabilidades disjuntas. | **MEDIA** |
| `power_effect_provider.dart` | **OCP** (Open/Closed) | Uso de cadenas condicionales rígidas (`if slug == 'freeze'`) para detectar tipos de ataque. Agregar un poder requiere editar lógica central. | **ALTA** |
| `clues_screen.dart` | **ISP** (Interface Seg.) | El widget escucha (`Context.watch` implícito en `build`) a `GameProvider` completo. Se re-renderiza por cambios en ranking o vidas, aunque no los muestre. | **MEDIA** |
| `shop_screen.dart` | **DIP** (Dep. Inversion) | Accede directamente a `Supabase.instance.client` en `_fetchPowerConfigs`, saltándose el Servicio y el Provider. | **ALTA** |
| `player_provider.dart` | **DIP** | Depende de clases concretas (`AuthService`, `InventoryService`) inyectadas, en lugar de abstracciones (`IAuthService`). | **BAJA** (Técnica) |
| `player_provider.dart` | **OCP** | Método `purchaseItem` tiene un `if (itemId == 'extra_life')` hardcodeado ("Magic String"), violando la extensibilidad de items. | **MEDIA** |
| `game_request_screen.dart` | **DIP** | Lógica de base de datos directa en UI (`Supabase.instance.client`). | **ALTA** |

---

## 3. Top 3 Refactorizaciones Prioritarias

Estas acciones te darán el mayor retorno de inversión en estabilidad y mantenibilidad:

### 1. Desacoplar el Sistema de Poderes (Fix OCP)
**Problema:** `PowerEffectProvider` y `PlayerProvider` tienen harcodeados los slugs de los poderes. Si creas un poder nuevo, romperás el juego si olvidas agregarlo a los 4 `if/switch` existentes.
**Solución:**
*   Crear una interfaz `PowerStrategy` con métodos como `execute()`, `onDefense()`, `isOffensive`.
*   Crear clases concretas: `FreezePower`, `ShieldPower`, `LifeStealPower`.
*   Usar un `PowerFactory` que devuelva la estrategia basada en el slug.
*   El Provider solo llama a `powerStrategy.execute()`.

### 2. Dividir `PlayerProvider` (Fix SRP)
**Problema:** Si edito la lógica de Baneo, puedo romper el Inventario porque comparten el mismo objeto de estado.
**Solución:** Separar en:
*   `AuhtProvider`: Solo sesión (User ID, Token).
*   `UserProfileProvider`: Datos del perfil (Nombre, Avatar) y Estado (Banned/Active).
*   `InventoryProvider`: Solo manejo de items y compras.
*   `PlayerProvider` (existente): Se queda solo como fachada o coordinador si es necesario, o se elimina delegando a los anteriores.

### 3. Centralizar Acceso a Datos (Fix DIP)
**Problema:** La UI (`ShopScreen`, `GameRequestScreen`) está haciendo consultas SQL/Supabase. Si cambia el nombre de una tabla, tendrás que buscar en toda la carpeta `features`.
**Solución:**
*   Mover TODAS las llamadas de `Supabase.instance.client` que están en Widgets hacia los Servicios correspondientes (`PowerService`, `GameService`).
*   Que los Widgets solo llamen a métodos del Provider, y el Provider al Servicio. Nada de `Supabase` en la UI.
