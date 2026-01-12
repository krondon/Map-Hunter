# 🎮 Treasure Hunt RPG (Juego QR)

**Real Life RPG - Búsqueda del Tesoro Interactiva**

Juego de rol en la vida real ("Real World RPG") que combina búsqueda de pistas físicas mediante QR, minijuegos móviles y sabotajes entre jugadores en tiempo real, gestionado por un panel de administración centralizado.

---

## 🚀 Estado Actual (v2.0)

**¡Backend & Admin Activos!**
El proyecto ha evolucionado para incluir una integración completa con **Supabase** y un panel de administración robusto.

### ✅ Nuevas Funcionalidades Clave
1.  **Tiendas Configurables (Admin Panel)**
    *   Creación de tiendas personalizadas para cada evento.
    *   **Precios Dinámicos:** El admin define el costo específico de cada poder/vida por tienda.
    *   **Control de Stock:** Selección de qué items vende cada tienda (Ej: Tienda solo de Vidas, Tienda de Sabotajes).
    *   **Persistencia Visual:** La app móvil refleja automáticamente los precios y productos configurados.

2.  **Sistema de Entrada QR Real**
    *   **Validación de Acceso:** Para entrar a una tienda en la app, el jugador debe escanear un QR físico real.
    *   **Scanner Integrado:** Botón "Escanear con Cámara" implementado nativamente (MobileScanner v6+).
    *   **Seguridad:** Validación contra códigos generados por el Admin (`store:nombre_tienda`).

3.  **Sistema Anti-Lag & Baneos (Optimizado)**
    *   **Stream en Tiempo Real:** Detección instantánea de baneos/bloqueos vía WebSockets.
    *   **Polling Inteligente:** Verificación ultraligera cada 10 segundos como respaldo (bajo consumo de datos).
    *   **Expulsión Inmediata:** Si un jugador es baneado, la app cierra sesión y redirige al login desde cualquier pantalla.

4.  **Gestión de Imágenes**
    *   Bucket de almacenamiento: `events-images`.
    *   Soporte para subida de logos de tiendas y banners de eventos.

---

## 📱 Características para Jugadores

*   **Login/Registro** validado con Supabase Auth.
*   **Inventario Real:** Sincronizado con base de datos.
*   **Ranking en Vivo:** Tabla de posiciones global y por evento.
*   **Sabotajes:**
    *   ❄️ **Pantalla Congelada**: Ciegas al rival por 15s.
    *   🛡️ **Escudo**: Protección temporal.
    *   ↩️ **Devolución**: Rebota ataques enemigos.
    *   👻 **Invisibilidad**: Desaparece del radar (Planned).
*   **Geolocalización:** Indicadores Frío/Caliente para encontrar pistas.

---

## 🛠️ Panel de Administrador

Herramienta poderosa para los organizadores del evento (`features/admin`):
*   **Crear Competencias:** Configurar nombre, descripción y fechas.
*   **Gestión de Usuarios:** Banear/Desbanear jugadores al instante.
*   **Editor de Tiendas:** Interfaz visual para subir logo, nombre, descripción y configurar inventario y precios.
*   **Generador de QR:** Exportar QRs de pistas y tiendas para imprimir.

---

## 🏗️ Estructura Técnica

```
lib/
├── core/                   # Utilidades y configuración
├── features/
│   ├── admin/              # PANEL ADMIN (Nuevo)
│   │   ├── screens/        # Gestión de eventos, usuarios, tiendas
│   │   └── widgets/        # Diálogos de edición
│   ├── auth/               # Autenticación y PlayerProvider
│   ├── game/               # Lógica del juego (QR, Pistas)
│   └── mall/               # TIENDAS (Módulos de compra)
│       ├── models/         # MallStore, PowerItem
│       ├── providers/      # StoreProvider (Lógica de negocio)
│       └── screens/        # StoreDetail, MallScreen
├── services/               # Supabase Services
└── main.dart               # Entry Point
```

### Tecnologías
*   **Flutter 3.x**
*   **Supabase** (PostgreSQL, Auth, Storage, Edge Functions)
*   **Provider** (State Management)
*   **Mobile Scanner** (QR Camera)
*   **Geolocator**

---

## 📝 Notas para el Equipo

> **Importante:**
> Al crear o editar tiendas en el Admin, asegúrense de seleccionar productos. Si no seleccionan ninguno, la tienda aparecerá vacía para el usuario.
>
> **Testing:**
> Para probar la entrada a tiendas sin imprimir el QR, pueden usar el botón "Simular (Pruebas)" oculto debajo del botón de la cámara, o escanear el QR desde la pantalla del Admin.

---

**¡Que comience la aventura! 🏆🎮**
