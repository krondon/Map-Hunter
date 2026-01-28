# Mapa de Responsabilidades y Reporte SRP

## 1. Identificación de "Clases Dios" (SRP Violations)

Se han detectado archivos que concentran excesivas responsabilidades, violando el Principio de Responsabilidad Única.

### A. `CluesScreen.dart` (Capa de Presentación)

- **Diagnóstico**: Actúa como un "God Widget". No solo se encarga de pintar la lista de pistas, sino que orquesta todo el flujo del juego.
- **Violaciones**:
  - **Lógica de Navegación**: Decide a qué pantalla ir según el `ClueType` (`_handleClueAction`). Esto acopla la vista con todos los posibles destinos (Minijuegos, QR, Tiendas, Mapa).
  - **Lógica de Estado/Polling**: Maneja `checkRaceStatus`, `startLeaderboardUpdates` y listeners de `GameProvider` directamente en el `initState`.
  - **Reglas de Negocio Visuales**: Decide si una pista está bloqueada visualmente basada en índices (`isFuture`, `isPast`).
  - **Manejo de Diálogos**: Define y muestra `_showCompletedClueDialog` y `_showUnlockClueDialog` internamente.

### B. `EventCreationController.dart` (Capa de Lógica)

- **Diagnóstico**: Controlador híbrido que mezcla Gestión de Estado de Formulario con Lógica de UI Directa.
- **Violaciones**:
  - **Dependencia de UI**: Importa y usa `flutter/material.dart` y `BuildContext`. Dispara `showDialog` (`addPendingStore`) y `ScaffoldMessenger` (`submitForm`) directamente.
  - **Validación + Negocio**: Maneja la validación de campos (`checkFormValidity`) Y la construcción de objetos complejos (`GameEvent`, `MallStore`) Y la orquestación de llamadas a Providers.
  - **Conocimiento de Infraestructura**: Usa `ImagePicker` (I/O) directamente.

### C. `Clue.dart` (Capa de Datos - Modelo Monolítico)

- **Diagnóstico**: **NO se encontró la jerarquía esperada (PhysicalClue vs OnlineClue).** Es una clase única que abarca todos los campos posibles de todos los tipos de pistas.
- **Violaciones**:
  - **Violación de OCP (Open/Closed)**: Usa un `enum ClueType` y `switch` statements (`typeIcon`, `typeName`) para definir comportamientos. Agregar un nuevo tipo implica modificar esta clase.
  - **Baja Cohesión General**: Un objeto `Clue` de tipo `minigame` tiene campos `latitude/longitude` nulos/vacíos, y uno de tipo `geolocation` tiene `minigameUrl` vacío.
  - **Fuga de Lógica**: `fromJson` contiene validación de rutas de archivos (`contains('C:/')`), lo cual es lógica de sanitización, no de modelo.

### D. `ScenariosScreen.dart` (Capa de Presentación)

- **Diagnóstico**: Vista con fugas de transformación de datos.
- **Violaciones**:
  - **Model Projection en Build**: Realiza un `map()` dentro del método `build()` para transformar `GameEvent` a `Scenario`. Esto debería ocurrir en el Controller o en un ViewModel.
  - **Responsabilidades Mezcladas**: Gestiona el estado de carga, la transformación de datos y la navegación de Logout (`showDialog`).

---

## 2. Análisis de Cohesión

| Componente                  | Nivel de Cohesión   | Análisis                                                                                                                                                                                                                     |
| :-------------------------- | :------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **EventCreationController** | **Baja**            | Mezcla lógica de presentación (Snackbars, Dialogs) con lógica de negocio (creación de entidades). Los métodos no operan sobre un estado único y coherente, sino sobre fragmentos disjuntos (Stores, UI feedback, Form data). |
| **EventService**            | **Media-Alta**      | Se centra en la persistencia con Supabase. Sin embargo, contiene lógica de determinación de MIME types (`image/jpeg`, etc.) que pertenece a un _FileService_ o _MediaHelper_.                                                |
| **Clue (Modelo)**           | **Baja**            | Al no ser polimórfico, agrupa datos dispares. Métodos como `typeIcon` dependen del tipo, lo que indica que el comportamiento debería estar delegado.                                                                         |
| **ScenariosController**     | **Alta (Aparente)** | Delega la lógica de selección, pero la transformación de datos pesada se quedó en la Vista (`ScenariosScreen`), dejando al controlador anémico.                                                                              |

---

## 3. Plan de Desacoplamiento (3 Acciones Concretas)

Para remediar la situación y preparar el código para una arquitectura limpia real:

### Acción 1: Refactorización a Polimorfismo Real (Clue Hierarchy)

**Objetivo**: Eliminar la "Clase Monolito" `Clue`.

- **Implementación**:
  1.  Convertir `Clue` en `abstract class BaseClue`.
  2.  Crear subclases `PhysicalClue`, `OnlineClue`, `MinigameClue`.
  3.  Mover la lógica de `typeIcon`, `typeName` y las validaciones específicas a cada subclase.
  4.  Implementar un `ClueFactory` para el `fromJson`.

### Acción 2: Purificación de Controladores (Controller Sanitization)

**Objetivo**: Sacar la UI (`BuildContext`) de `EventCreationController`.

- **Implementación**:
  1.  **Patrón Listener/Stream**: El Controller debe emitir estados (`Success`, `Error`, `Loading`) o usar streams.
  2.  **UI Reactor**: La Vista (`EventCreationScreen`) escucha estos estados y ES ELLA quien muestra el SnackBar o navega.
  3.  **Dialog Service**: Abstraer la confirmación y selección de tiendas. El controller solicita "Input de Tienda", y un servicio (o interfaz implementada por la vista) maneja el `showDialog` y devuelve el resultado.

### Acción 3: Estrategia de Navegación Centralizada (Navigation Strategy)

**Objetivo**: Limpiar `CluesScreen`.

- **Implementación**:
  1.  Crear `ClueNavigationService` o `GameFlowCoordinator`.
  2.  Extraer el método `_handleClueAction`.
  3.  En lugar de `switch (type)`, usar Polimorfismo si es posible (e.g., `clue.executeAction(context)`) O un mapa de manejadores en el coordinador.
  4.  Mover la lógica de "Check Race Status" y "Polling" a un `GameSessionManager` invisible para la UI, que solo notifique cuando se debe cambiar de pantalla.
