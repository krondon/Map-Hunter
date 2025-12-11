# 🎮 Treasure Hunt RPG

**Real Life RPG - Búsqueda del Tesoro**

Un juego de rol en la vida real que combina la búsqueda física de pistas con elementos de videojuego RPG, integración de espectadores remotos y patrocinios.

---

## 📱 Características

### ✅ Implementadas (Diseño)
- **Sistema de Autenticación** - Login y registro con validación
- **Gestión de Pistas** - Sistema de desafíos con múltiples tipos:
  - 📷 Escaneo de QR
  - 📍 Búsqueda por Geolocalización (indicador Frío/Tibio/Caliente)
  - 🎮 Minijuegos
  - 🏪 Interacción con NPCs (La Tiendita)
- **Sistema de Inventario** - Gestión de poderes adquiridos
- **La Tiendita (NPC)** - Compra de poderes especiales:
  - ❄️ Freeze - Congela jugadores
  - 🛡️ Escudo - Protección contra sabotajes
  - ⏱️ Penalización de Tiempo
  - 💡 Pista Extra
  - ⚡ Velocidad
- **Sistema de Progresión RPG**:
  - Experiencia (XP) y Niveles
  - Profesiones: Speedrunner, Warrior, Strategist, Balanced
  - Stats: Velocidad, Fuerza, Inteligencia
- **Ranking en Tiempo Real** - Tabla de clasificación con podio
- **Perfil de Jugador** - Estadísticas y progreso

### 🎨 Diseño Visual
- **Tema Oscuro Premium** con gradientes vibrantes
- **Paleta de Colores**:
  - Púrpura Primario (#6C5CE7)
  - Rosa Secundario (#FF6B9D)
  - Oro Acento (#FFD700)
- **Animaciones Suaves** y transiciones
- **Tipografía Moderna** (Google Fonts: Outfit, Inter)
- **Micro-interacciones** en botones y cards

---

## 🏗️ Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── theme/
│   └── app_theme.dart          # Tema y colores
├── models/
│   ├── player.dart             # Modelo de jugador
│   ├── clue.dart               # Modelo de pista
│   └── power_item.dart         # Modelo de poderes
├── providers/
│   ├── player_provider.dart    # Estado del jugador
│   └── game_provider.dart      # Estado del juego
├── screens/
│   ├── splash_screen.dart      # Pantalla de inicio
│   ├── login_screen.dart       # Login
│   ├── register_screen.dart    # Registro
│   ├── home_screen.dart        # Navegación principal
│   ├── clues_screen.dart       # Lista de pistas
│   ├── inventory_screen.dart   # Inventario
│   ├── leaderboard_screen.dart # Ranking
│   ├── profile_screen.dart     # Perfil
│   ├── qr_scanner_screen.dart  # Escáner QR
│   ├── geolocation_screen.dart # Geolocalización
│   └── shop_screen.dart        # Tiendita
└── widgets/
    ├── progress_header.dart    # Barra de progreso
    ├── clue_card.dart          # Card de pista
    ├── leaderboard_card.dart   # Card de ranking
    ├── stat_card.dart          # Card de estadística
    ├── inventory_item_card.dart # Card de item
    └── shop_item_card.dart     # Card de tienda
```

---

## 🚀 Instalación

### Prerrequisitos
1. **Flutter SDK** (>=3.0.0)
   - Descargar: https://flutter.dev/docs/get-started/install
2. **Android Studio** o **VS Code**
3. **Git**

### Pasos

1. **Instalar Flutter** (si no lo tienes):
   ```bash
   # Verificar instalación
   flutter doctor
   ```

2. **Obtener dependencias**:
   ```bash
   cd C:\Users\natac\Desktop\juego
   flutter pub get
   ```

3. **Ejecutar en emulador o dispositivo**:
   ```bash
   flutter run
   ```

4. **Compilar para Android**:
   ```bash
   flutter build apk --release
   ```

---

## 📦 Dependencias

- **flutter** - Framework principal
- **google_fonts** - Tipografía premium
- **provider** - Gestión de estado
- **qr_code_scanner** - Escaneo de códigos QR
- **qr_flutter** - Generación de códigos QR
- **geolocator** - Geolocalización
- **google_maps_flutter** - Mapas
- **webview_flutter** - Minijuegos en WebView
- **shared_preferences** - Almacenamiento local
- **intl** - Internacionalización

---

## 🎯 Flujo del Juego

### 1️⃣ Registro/Login
El jugador se registra o inicia sesión en la app.

### 2️⃣ Pistas
Recibe pistas secuenciales (debe completar la anterior para desbloquear la siguiente).

### 3️⃣ Tipos de Desafíos

**📷 QR Scan**: Escanear un código QR escondido en una ubicación física.

**📍 Geolocalización**: Dirigirse a coordenadas específicas con indicador de proximidad:
- ❄️ Frío (>300m)
- 🌡️ Tibio (100-300m)
- 🔥 Caliente (50-100m)
- 🎯 Muy Cerca (<50m)

**🏪 NPC Tiendita**: Comprar poderes con las monedas ganadas.

**🎮 Minijuegos**: Resolver desafíos mentales o de habilidad.

### 4️⃣ Recompensas
- **XP** para subir de nivel
- **Monedas** para comprar poderes
- **Stats** (Velocidad, Fuerza, Inteligencia)

### 5️⃣ Poderes y Sabotajes
- Comprar poderes en La Tiendita
- Usar contra otros jugadores
- Estados: Congelado, Con Escudo, etc.

### 6️⃣ Clasificación
Ver el ranking en tiempo real y competir por el primer lugar.

---

## 🔮 Características Futuras (No implementadas)

### Backend
- [ ] Integración con **Supabase** o **PlayFab**
- [ ] Sincronización en tiempo real
- [ ] Sistema de autenticación real
- [ ] Base de datos de jugadores y pistas

### Funcionalidades
- [ ] **App de Administrador** - Validación de jugadores, gestión de eventos
- [ ] **Web para Espectadores** - Visualización en vivo, apuestas
- [ ] **Monetización** - Sistema de pagos para pay-to-win/lose
- [ ] **Notificaciones Push** - Alertas de sabotajes y eventos
- [ ] **Chat en Vivo** - Comunicación entre jugadores
- [ ] **Modo Equipo** - Competencias por equipos según profesión
- [ ] **Patrocinios** - Integración de puntos de venta físicos
- [ ] **Minijuegos Reales** - Desarrollo de minijuegos interactivos

### Mejoras Técnicas
- [ ] Cámara QR real (actualmente simulado)
- [ ] GPS real con mapas interactivos
- [ ] Persistencia de datos local
- [ ] Optimización de rendimiento
- [ ] Tests unitarios y de integración

---

## 🎨 Capturas de Pantalla

*(Ejecuta la app para ver el diseño en acción)*

- **Splash Screen** - Animación de entrada
- **Login/Register** - Diseño premium con gradientes
- **Home** - Navegación con 4 pestañas
- **Pistas** - Cards con estados bloqueado/activo/completado
- **Inventario** - Grid de poderes
- **Ranking** - Podio top 3 + lista
- **Perfil** - Stats RPG del jugador
- **QR Scanner** - Simulación de escaneo
- **Geolocalización** - Indicador de proximidad animado
- **Tiendita** - Shop de poderes

---

## 👨‍💻 Tecnologías

- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **UI/UX**: Material Design + Custom Theme
- **Fonts**: Google Fonts (Outfit, Inter)

---

## 📝 Notas de Desarrollo

### Datos Mock
Actualmente la app usa **datos simulados** para demostración:
- Jugadores ficticios en el ranking
- Pistas predefinidas
- Login sin validación real
- Funciones simuladas (QR, GPS)

### Próximos Pasos
1. **Instalar Flutter** en tu sistema
2. **Ejecutar** `flutter pub get`
3. **Testear** la app en un emulador
4. **Decidir backend** (Supabase recomendado)
5. **Implementar** integración backend
6. **Desarrollar** app de administrador
7. **Crear** web para espectadores

---

## 🤝 Contribución

Este es un proyecto base. Para extenderlo:

1. Clona el repositorio
2. Crea una rama para tu feature
3. Implementa mejoras
4. Haz commit de los cambios
5. Abre un Pull Request

---

## 📄 Licencia

Proyecto personal - Todos los derechos reservados

---

## 📧 Contacto

Para preguntas o colaboraciones, contacta al desarrollador.

---

**¡Que comience la aventura! 🏆🎮📍**
