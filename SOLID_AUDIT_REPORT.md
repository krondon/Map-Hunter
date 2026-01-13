# 📊 Informe de Auditoría SOLID - Treasure Hunt RPG

**Proyecto:** Juego_QR (Treasure Hunt RPG)  
**Fecha de Auditoría:** 2026-01-13  
**Arquitecto Revisor:** Auditoría Técnica Automatizada  
**Framework:** Flutter/Dart con Supabase Backend

---

## 🎯 Tablero de Control - Resumen Ejecutivo

| Principio                     | Puntuación | Estado                    |
| ----------------------------- | :--------: | ------------------------- |
| **S** - Single Responsibility |    3/10    | 🔴 Violación Sistemática  |
| **O** - Open/Closed           |    6/10    | 🟡 Cumplimiento Parcial   |
| **L** - Liskov Substitution   |    7/10    | 🟢 Cumplimiento Aceptable |
| **I** - Interface Segregation |    7/10    | 🟢 Cumplimiento Aceptable |
| **D** - Dependency Inversion  |    3/10    | 🔴 Violación Sistemática  |

**Puntuación Global: 5.2/10** ⚠️ _Requiere refactorización prioritaria_

---

## 📋 Análisis Detallado por Principio

---

## 🔴 S - Single Responsibility Principle (SRP)

### Evaluación: **VIOLACIÓN SISTEMÁTICA** (3/10)

> _"Una clase debe tener una, y solo una, razón para cambiar."_

### Evidencias de Violación

#### 1. `PlayerProvider` - El "God Object" del proyecto

**Archivo:** [player_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/auth/providers/player_provider.dart)  
**Líneas:** 964 | **Métodos:** 32+

Este provider combina **al menos 8 responsabilidades distintas**:

| Responsabilidad            | Ejemplos de Métodos                        |
| -------------------------- | ------------------------------------------ |
| Autenticación              | `login()`, `register()`, `logout()`        |
| Gestión de Perfil          | `_fetchProfile()`, `refreshProfile()`      |
| Sistema de Inventario      | `fetchInventory()`, `purchaseItem()`       |
| Sistema de Poderes         | `usePower()`, `_decrementPowerBySlug()`    |
| Gestión de Vidas           | `loseLife()`, `resetLives()`               |
| Administración de Usuarios | `toggleBanUser()`, `deleteUser()`          |
| Suscripciones Real-time    | `_subscribeToProfile()`, `_startPolling()` |
| Funciones de Debug         | `debugAddPower()`, `debugToggleStatus()`   |

```dart
// Estado Actual (Líneas 285-410) - Método usePower con 125+ líneas
Future<PowerUseResult> usePower({
    required String powerSlug,
    required String targetGamePlayerId,
    required PowerEffectProvider effectProvider,
    GameProvider? gameProvider,
    bool allowReturnForward = true,
  }) async {
    // ...125+ líneas combinando:
    // - Validación de parámetros
    // - Lógica de negocio (reflejo, escudo, robo)
    // - Acceso a base de datos
    // - Actualización de estado UI
    // - Manejo de errores
}
```

#### 2. `puzzle_screen.dart` - Archivo Monolítico

**Archivo:** [puzzle_screen.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/screens/puzzle_screen.dart)  
**Líneas:** 1333 | **Clases integradas:** 10+

Un solo archivo contiene:

- `PuzzleScreen` (Widget principal)
- `CodeBreakerWidget` (Líneas 444-632)
- `ImageTriviaWidget` (Líneas 634-757)
- `WordScrambleWidget` (Líneas 759-890+)
- Funciones globales `showClueSelector`, `showSkipDialog`
- Helper `_buildMinigameScaffold`

#### 3. `GameProvider` - Múltiples Dominios

**Archivo:** [game_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/providers/game_provider.dart)  
**Líneas:** 539 | **Métodos:** 26

Combina:

- Estado del juego (pistas, vidas)
- Leaderboard (fetch, subscribe, update)
- Suscripciones real-time
- Lógica de victoria
- Acceso directo a DB

### Impacto en el Proyecto

| Aspecto            | Consecuencia                                                           |
| ------------------ | ---------------------------------------------------------------------- |
| **Mantenibilidad** | Cambios en una funcionalidad afectan potencialmente todas las demás    |
| **Testeabilidad**  | Imposible hacer unit tests aislados; requiere mockear el mundo entero  |
| **Escalabilidad**  | Añadir nuevas características aumenta el acoplamiento exponencialmente |
| **Debugging**      | Dificultad para aislar bugs cuando todo está interconectado            |

### Plan de Refactorización

**Objetivo:** Dividir `PlayerProvider` en servicios cohesivos

```dart
// ═══════════════════════════════════════════════════════════════
// PROPUESTA REFACTORIZADA
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// 1. Servicio de Autenticación (auth_service.dart)
// ─────────────────────────────────────────────────────────────────
abstract class IAuthService {
  Future<Player?> login(String email, String password);
  Future<Player?> register(String name, String email, String password);
  Future<void> logout();
  Stream<Player?> get authStateChanges;
}

class SupabaseAuthService implements IAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  @override
  Future<Player?> login(String email, String password) async {
    // Solo lógica de autenticación
  }
}

// ─────────────────────────────────────────────────────────────────
// 2. Repositorio de Inventario (inventory_repository.dart)
// ─────────────────────────────────────────────────────────────────
abstract class IInventoryRepository {
  Future<List<InventoryItem>> fetchInventory(String userId, String eventId);
  Future<void> purchaseItem(String itemId, String eventId, int cost);
  Future<void> consumeItem(String itemId);
}

class InventoryRepository implements IInventoryRepository {
  final SupabaseClient _client;

  InventoryRepository(this._client);

  @override
  Future<List<InventoryItem>> fetchInventory(String userId, String eventId) async {
    // Solo lógica de inventario
  }
}

// ─────────────────────────────────────────────────────────────────
// 3. Servicio de Poderes (power_service.dart)
// ─────────────────────────────────────────────────────────────────
abstract class IPowerService {
  Future<PowerUseResult> usePower({
    required String powerSlug,
    required String targetPlayerId,
  });
}

// ─────────────────────────────────────────────────────────────────
// 4. Provider Simplificado (player_provider.dart refactorizado)
// ─────────────────────────────────────────────────────────────────
class PlayerProvider extends ChangeNotifier {
  final IAuthService _authService;
  final IInventoryRepository _inventoryRepo;
  final IPowerService _powerService;

  PlayerProvider({
    required IAuthService authService,
    required IInventoryRepository inventoryRepo,
    required IPowerService powerService,
  }) : _authService = authService,
       _inventoryRepo = inventoryRepo,
       _powerService = powerService;

  // Solo coordinación y estado UI
  Player? _currentPlayer;
  Player? get currentPlayer => _currentPlayer;

  Future<void> login(String email, String password) async {
    _currentPlayer = await _authService.login(email, password);
    notifyListeners();
  }
}
```

---

## 🟡 O - Open/Closed Principle (OCP)

### Evaluación: **CUMPLIMIENTO PARCIAL** (6/10)

> _"Las entidades de software deben estar abiertas para extensión, pero cerradas para modificación."_

### Evidencias Positivas ✅

#### Minijuegos con Patrón Extensible

**Directorio:** `lib/features/game/widgets/minigames/`

La arquitectura de minijuegos **sigue correctamente OCP**:

```
minigames/
├── block_fill_minigame.dart
├── find_difference_minigame.dart
├── flags_minigame.dart
├── hangman_minigame.dart
├── minesweeper_minigame.dart
├── sliding_puzzle_minigame.dart
├── snake_minigame.dart
├── tetris_minigame.dart
└── tic_tac_toe_minigame.dart
```

El enum [PuzzleType](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/models/clue.dart#L157-L214) define los tipos:

```dart
enum PuzzleType {
  slidingPuzzle,
  ticTacToe,
  hangman,
  tetris,
  findDifference,
  flags,
  minesweeper,
  snake,
  blockFill;

  String get label { /* ... */ }
  bool get isAutoValidation { /* ... */ }
  String get defaultQuestion { /* ... */ }
}
```

### Evidencias de Violación ⚠️

#### Switch Gigante en PuzzleScreen

**Archivo:** [puzzle_screen.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/screens/puzzle_screen.dart#L247-L281)

```dart
// Estado Actual - Violación OCP
switch (widget.clue.puzzleType) {
  case PuzzleType.slidingPuzzle:
    gameWidget = SlidingPuzzleWrapper(clue: widget.clue, onFinish: _finishLegally);
    break;
  case PuzzleType.ticTacToe:
    gameWidget = TicTacToeWrapper(clue: widget.clue, onFinish: _finishLegally);
    break;
  case PuzzleType.hangman:
    gameWidget = HangmanWrapper(clue: widget.clue, onFinish: _finishLegally);
    break;
  // ... 6 casos más
}
```

**Problema:** Añadir un nuevo minijuego requiere:

1. Modificar `PuzzleType` enum
2. Modificar el switch en `puzzle_screen.dart`
3. Crear el widget wrapper

### Plan de Refactorización

```dart
// ═══════════════════════════════════════════════════════════════
// PROPUESTA: Factory Pattern + Registry
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// 1. Interfaz base para minijuegos
// ─────────────────────────────────────────────────────────────────
abstract class MinigameWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onFinish;

  const MinigameWidget({
    required this.clue,
    required this.onFinish,
    super.key,
  });
}

// ─────────────────────────────────────────────────────────────────
// 2. Registry de minijuegos (minigame_registry.dart)
// ─────────────────────────────────────────────────────────────────
class MinigameRegistry {
  static final Map<PuzzleType, MinigameFactory> _factories = {
    PuzzleType.slidingPuzzle: (clue, onFinish) =>
        SlidingPuzzleWrapper(clue: clue, onFinish: onFinish),
    PuzzleType.ticTacToe: (clue, onFinish) =>
        TicTacToeWrapper(clue: clue, onFinish: onFinish),
    // ... otros
  };

  // Permite registrar nuevos minijuegos sin modificar código existente
  static void register(PuzzleType type, MinigameFactory factory) {
    _factories[type] = factory;
  }

  static Widget create(Clue clue, VoidCallback onFinish) {
    final factory = _factories[clue.puzzleType];
    if (factory == null) {
      throw UnimplementedError('Minigame ${clue.puzzleType} not registered');
    }
    return factory(clue, onFinish);
  }
}

typedef MinigameFactory = Widget Function(Clue clue, VoidCallback onFinish);

// ─────────────────────────────────────────────────────────────────
// 3. Uso en PuzzleScreen refactorizado
// ─────────────────────────────────────────────────────────────────
// En lugar del switch:
Widget gameWidget = MinigameRegistry.create(widget.clue, _finishLegally);
```

---

## 🟢 L - Liskov Substitution Principle (LSP)

### Evaluación: **CUMPLIMIENTO ACEPTABLE** (7/10)

> _"Los objetos de una superclase deben poder ser reemplazados por objetos de sus subclases sin alterar el programa."_

### Evidencias Positivas ✅

#### Modelo Player con Status Polimórfico

**Archivo:** [player.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/shared/models/player.dart#L80-L99)

```dart
static PlayerStatus _parseStatus(String? status) {
  switch (status) {
    case 'frozen': return PlayerStatus.frozen;
    case 'blinded': return PlayerStatus.blinded;
    case 'slowed': return PlayerStatus.slowed;
    case 'shielded': return PlayerStatus.shielded;
    case 'banned': return PlayerStatus.banned;
    case 'pending': return PlayerStatus.pending;
    case 'invisible': return PlayerStatus.invisible;
    default: return PlayerStatus.active;
  }
}
```

Los getters derivados (`isFrozen`, `isBlinded`, `isSlowed`) mantienen comportamiento consistente:

```dart
bool get isFrozen =>
    status == PlayerStatus.frozen &&
    (frozenUntil == null || DateTime.now().toUtc().isBefore(frozenUntil!.toUtc()));
```

#### Minigames como Widgets Intercambiables

Todos los minijuegos extienden `StatefulWidget` y aceptan los mismos parámetros base (`clue`, `onFinish`), permitiendo sustitución sin afectar el flujo padre.

### Área de Mejora ⚠️

**No existe una interfaz formal** para los minijuegos. El cumplimiento es por convención, no por contrato.

### Impacto

| Aspecto        | Evaluación                              |
| -------------- | --------------------------------------- |
| Mantenibilidad | ✅ Bien: Los modelos son consistentes   |
| Extensibilidad | ⚠️ Riesgo medio: Sin contratos formales |
| Testeabilidad  | ✅ Bien: Enums permiten mocking fácil   |

---

## 🟢 I - Interface Segregation Principle (ISP)

### Evaluación: **CUMPLIMIENTO ACEPTABLE** (7/10)

> _"Ningún cliente debe ser forzado a depender de interfaces que no usa."_

### Evidencias Positivas ✅

#### Providers Especializados

El proyecto separa providers por dominio:

| Provider               | Responsabilidad Principal  |
| ---------------------- | -------------------------- |
| `GameProvider`         | Estado del juego y pistas  |
| `EventProvider`        | Gestión de eventos (admin) |
| `StoreProvider`        | Tiendas del mall           |
| `ConnectivityProvider` | Estado de conexión         |
| `PowerEffectProvider`  | Efectos de poderes activos |

```dart
// main.dart - Líneas 65-75
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => PlayerProvider()),
    ChangeNotifierProvider(create: (_) => EventProvider()),
    ChangeNotifierProvider(create: (_) => GameRequestProvider()),
    ChangeNotifierProvider(create: (_) => GameProvider()),
    Provider(create: (_) => PenaltyService()),
    ChangeNotifierProvider(create: (_) => StoreProvider()),
    ChangeNotifierProvider(create: (_) => PowerEffectProvider()),
    ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
  ],
```

### Área de Mejora ⚠️

**`PlayerProvider`** viola ISP al combinar múltiples interfaces:

```dart
// Un widget de Login solo necesita:
// - login()
// - register()

// Pero recibe acceso a:
// - toggleBanUser()
// - deleteUser()
// - usePower()
// - fetchAllPlayers()
// - debugAddPower()
// (... 25+ métodos más)
```

### Plan de Refactorización

```dart
// ═══════════════════════════════════════════════════════════════
// PROPUESTA: Interfaces Segregadas
// ═══════════════════════════════════════════════════════════════

// Solo lo que necesita LoginScreen
abstract class IAuthProvider {
  Future<void> login(String email, String password);
  Future<void> register(String name, String email, String password);
  bool get isLoading;
  String? get errorMessage;
  Player? get currentPlayer;
}

// Solo lo que necesita el AdminPanel
abstract class IAdminProvider {
  Future<List<Player>> fetchAllPlayers();
  Future<void> toggleBanUser(String userId, bool ban);
  Future<void> deleteUser(String userId);
}

// PlayerProvider implementa múltiples interfaces
class PlayerProvider extends ChangeNotifier
    implements IAuthProvider, IAdminProvider, IInventoryProvider {
  // ...
}
```

---

## 🔴 D - Dependency Inversion Principle (DIP)

### Evaluación: **VIOLACIÓN SISTEMÁTICA** (3/10)

> _"Los módulos de alto nivel no deben depender de módulos de bajo nivel. Ambos deben depender de abstracciones."_

### Evidencias de Violación

#### 1. Acoplamiento Directo a Supabase

Prácticamente **todos los providers y servicios** acceden directamente a `Supabase.instance.client`:

**PenaltyService** ([penalty_service.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/game/services/penalty_service.dart#L3-L4)):

```dart
class PenaltyService {
  final SupabaseClient _supabase = Supabase.instance.client; // ❌ Dependencia concreta
```

**StoreProvider** ([store_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/mall/providers/store_provider.dart#L6-L7)):

```dart
class StoreProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client; // ❌ Dependencia concreta
```

**PlayerProvider** ([player_provider.dart](file:///c:/Users/Andres/Desktop/TUNEL/Morna/Juego_QR/lib/features/auth/providers/player_provider.dart)):

```dart
// Acceso directo a _supabase múltiples veces en el archivo
```

#### 2. Sin Abstracción de Repositorio

No existe una capa de repositorio abstracta. Los providers hacen queries SQL directamente:

```dart
// Estado Actual - StoreProvider.fetchStores()
final response = await _supabase
    .from('mall_stores')
    .select()
    .eq('event_id', eventId)
    .order('created_at');
```

### Impacto Crítico

| Aspecto            | Consecuencia                                                        |
| ------------------ | ------------------------------------------------------------------- |
| **Testing**        | ❌ Imposible hacer unit tests sin conexión a Supabase real          |
| **Migración**      | ❌ Cambiar backend (ej: Firebase) requiere reescribir cada provider |
| **Offline**        | ❌ No hay capa de caché o fallback                                  |
| **Mantenibilidad** | ❌ Cambios en esquema DB afectan múltiples archivos                 |

### Plan de Refactorización

```dart
// ═══════════════════════════════════════════════════════════════
// PROPUESTA: Patrón Repository con Inyección de Dependencias
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// 1. Interfaz de Cliente de Base de Datos
// ─────────────────────────────────────────────────────────────────
abstract class IDatabaseClient {
  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic>? filters,
    String? orderBy,
  });

  Future<void> insert(String table, Map<String, dynamic> data);
  Future<void> update(String table, Map<String, dynamic> data, String id);
  Future<void> delete(String table, String id);

  Future<T> rpc<T>(String function, Map<String, dynamic> params);
}

// ─────────────────────────────────────────────────────────────────
// 2. Implementación Supabase
// ─────────────────────────────────────────────────────────────────
class SupabaseDatabaseClient implements IDatabaseClient {
  final SupabaseClient _client;

  SupabaseDatabaseClient(this._client);

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic>? filters,
    String? orderBy,
  }) async {
    var query = _client.from(table).select();
    filters?.forEach((key, value) => query = query.eq(key, value));
    if (orderBy != null) query = query.order(orderBy);
    return await query;
  }

  // ... otros métodos
}

// ─────────────────────────────────────────────────────────────────
// 3. Repositorio Abstracto
// ─────────────────────────────────────────────────────────────────
abstract class IStoreRepository {
  Future<List<MallStore>> fetchStores(String eventId);
  Future<void> createStore(MallStore store, String? imageUrl);
  Future<void> updateStore(MallStore store, String? newImageUrl);
  Future<void> deleteStore(String storeId);
}

class StoreRepository implements IStoreRepository {
  final IDatabaseClient _db;

  StoreRepository(this._db);

  @override
  Future<List<MallStore>> fetchStores(String eventId) async {
    final data = await _db.select(
      'mall_stores',
      filters: {'event_id': eventId},
      orderBy: 'created_at',
    );
    return data.map((e) => MallStore.fromMap(e)).toList();
  }
}

// ─────────────────────────────────────────────────────────────────
// 4. Provider Desacoplado
// ─────────────────────────────────────────────────────────────────
class StoreProvider extends ChangeNotifier {
  final IStoreRepository _repository; // ✅ Depende de abstracción

  StoreProvider(this._repository);

  Future<void> fetchStores(String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _stores = await _repository.fetchStores(eventId);
    } catch (e) {
      _errorMessage = 'Error cargando tiendas';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// 5. Configuración con Inyección de Dependencias (main.dart)
// ─────────────────────────────────────────────────────────────────
void main() async {
  // Configurar dependencias
  final dbClient = SupabaseDatabaseClient(Supabase.instance.client);
  final storeRepo = StoreRepository(dbClient);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StoreProvider(storeRepo), // ✅ Inyección
        ),
      ],
      child: MyApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// 6. Mock para Testing
// ─────────────────────────────────────────────────────────────────
class MockStoreRepository implements IStoreRepository {
  List<MallStore> mockStores = [];

  @override
  Future<List<MallStore>> fetchStores(String eventId) async {
    return mockStores; // ✅ Testeable sin Supabase
  }
  // ...
}
```

---

## 📈 Resumen de Acciones Prioritarias

### 🔴 Prioridad Alta (Impacto Crítico)

| #   | Acción                                              | Archivos Afectados                         | Esfuerzo |
| --- | --------------------------------------------------- | ------------------------------------------ | -------- |
| 1   | **Dividir `PlayerProvider`** en servicios cohesivos | `player_provider.dart` + 5 nuevos archivos | Alto     |
| 2   | **Crear capa de abstracción** para Supabase         | Todos los providers/services               | Alto     |
| 3   | **Extraer widgets** de `puzzle_screen.dart`         | `puzzle_screen.dart` → 4+ archivos         | Medio    |

### 🟡 Prioridad Media (Mejora de Calidad)

| #   | Acción                                          | Archivos Afectados                                   | Esfuerzo |
| --- | ----------------------------------------------- | ---------------------------------------------------- | -------- |
| 4   | Implementar **Factory Pattern** para minijuegos | `puzzle_screen.dart`, nuevo `minigame_registry.dart` | Bajo     |
| 5   | **Definir interfaces** formales para providers  | Nuevos archivos en `core/interfaces/`                | Medio    |
| 6   | **Separar** `GameProvider` (estado vs. datos)   | `game_provider.dart` + nuevos repos                  | Medio    |

### 🟢 Prioridad Baja (Mejora Continua)

| #   | Acción                                   | Archivos Afectados         | Esfuerzo |
| --- | ---------------------------------------- | -------------------------- | -------- |
| 7   | Crear **abstract class** para minijuegos | `widgets/minigames/*.dart` | Bajo     |
| 8   | Implementar **unit tests** con mocks     | Nuevo directorio `test/`   | Medio    |

---

## 📊 Métricas de Complejidad Detectadas

| Archivo                      | Líneas | Complejidad | Recomendación             |
| ---------------------------- | :----: | :---------: | ------------------------- |
| `player_provider.dart`       |  964   | 🔴 Muy Alta | Dividir en 5+ archivos    |
| `puzzle_screen.dart`         |  1333  | 🔴 Muy Alta | Extraer widgets           |
| `game_request_screen.dart`   |  799   |   🟠 Alta   | Extraer lógica a provider |
| `power_effect_provider.dart` |  529   |   🟠 Alta   | Separar efectos por tipo  |
| `game_provider.dart`         |  539   |   🟠 Alta   | Separar leaderboard       |
| `hangman_minigame.dart`      |  528   |  🟡 Media   | Aceptable                 |

---

## ✅ Buenas Prácticas Detectadas

A pesar de las violaciones, el proyecto tiene aspectos positivos:

1. ✅ **Estructura de directorios por features** (`features/admin`, `features/game`, etc.)
2. ✅ **Modelos inmutables** con `copyWith` pattern en `Clue`
3. ✅ **Enums con comportamiento** (`PuzzleType.label`, `PuzzleType.isAutoValidation`)
4. ✅ **Separación de minijuegos** en archivos individuales
5. ✅ **Uso de Provider** para gestión de estado (patrón recomendado por Flutter)

---

## 📝 Conclusión

El proyecto **Treasure Hunt RPG** presenta una arquitectura funcional pero con deuda técnica significativa en lo referente a los principios SOLID. Las violaciones más críticas se encuentran en:

1. **SRP** (3/10): Providers "God Object" que combinan demasiadas responsabilidades
2. **DIP** (3/10): Acoplamiento directo a Supabase sin abstracción

La refactorización recomendada seguiría este orden:

1. Crear capa de abstracción de datos (Repository Pattern)
2. Dividir `PlayerProvider` en servicios especializados
3. Extraer widgets de `puzzle_screen.dart`
4. Implementar Factory Pattern para minijuegos

**Tiempo estimado de refactorización:** 2-3 sprints (asumiendo sprints de 2 semanas)

---

_Informe generado como parte de auditoría técnica de arquitectura de software._
