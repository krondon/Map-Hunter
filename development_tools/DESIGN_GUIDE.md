# 🎨 Guía de Diseño Visual - Map Hunter RPG

## 🎯 Filosofía de Diseño

El diseño de Map Hunter RPG se basa en crear una experiencia **premium, moderna y dinámica** que inspire aventura y competencia.

---

## 🌈 Paleta de Colores

### Colores Principales

```css
/* Púrpura Primario - Misterio y magia */
#6C5CE7

/* Rosa Secundario - Energía y pasión */
#FF6B9D

/* Oro Acento - Premio y logro */
#FFD700
```

### Colores de Fondo

```css
/* Fondo Oscuro Principal */
#0A0E27

/* Fondo de Tarjetas */
#1A1F3A
```

### Colores de Estado

```css
/* Éxito */
#00D9A3

/* Peligro */
#FF4757

/* Advertencia */
#FFB142

/* Info */
#6C5CE7
```

---

## 🎨 Gradientes

### Gradiente Primario (Púrpura → Rosa)
```dart
LinearGradient(
  colors: [Color(0xFF6C5CE7), Color(0xFFFF6B9D)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
**Uso**: Botones principales, headers importantes, elementos destacados

### Gradiente Dorado
```dart
LinearGradient(
  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```
**Uso**: Monedas, recompensas, podio de ranking

### Gradiente de Fondo
```dart
LinearGradient(
  colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
)
```
**Uso**: Fondos de pantallas

---

## 📝 Tipografía

### Fuentes

**Outfit** - Títulos y headings
- Bold (700) para títulos principales
- SemiBold (600) para subtítulos

**Inter** - Cuerpo y UI
- Regular (400) para texto normal
- Medium (500) para labels
- SemiBold (600) para botones

### Jerarquía Tipográfica

```
Display Large:   32px / Bold   - Títulos de pantalla
Display Medium:  28px / Bold   - Títulos de sección
Display Small:   24px / SemiBold - Subtítulos grandes
Headline Medium: 20px / SemiBold - Títulos de cards
Headline Small:  18px / SemiBold - Subtítulos
Body Large:      16px / Regular - Texto principal
Body Medium:     14px / Regular - Texto secundario
Body Small:      12px / Regular - Texto pequeño
```

---

## 🧩 Componentes

### Cards

**Bordes Redondeados**: 12-20px  
**Padding**: 16-20px  
**Elevación**: Sin sombras duras, usar blur suave  
**Bordes**: 2px con opacity 0.3

```dart
Container(
  decoration: BoxDecoration(
    color: AppTheme.cardBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppTheme.primaryPurple.withOpacity(0.3),
      width: 2,
    ),
  ),
)
```

### Botones

**Primarios**: Gradiente púrpura-rosa  
**Secundarios**: Color sólido con opacidad  
**Altura**: 48-56px  
**Border Radius**: 12px  
**Shadow**: Glow suave del color principal

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.primaryGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppTheme.primaryPurple.withOpacity(0.4),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  ),
)
```

### Iconos

**Tamaños**:
- Pequeño: 16px
- Mediano: 24px
- Grande: 32px
- Hero: 60-80px

**Colores**: Degrade según contexto o acento

---

## 🎭 Estados Visuales

### Activo
- Borde brillante
- Gradiente completo
- Sombra visible

### Bloqueado
- Opacidad reducida (0.5)
- Gris en lugar de colores
- Icono de candado 🔒

### Completado
- Verde éxito (#00D9A3)
- Icono de check ✓
- Borde verde

### Hover/Pressed
- Escala 0.95
- Opacidad 0.8
- Duración: 150ms

---

## ✨ Animaciones

### Transiciones
- **Duración estándar**: 200-300ms
- **Curva**: easeInOut, easeOut
- **Escalado**: 0.95 - 1.0

### Efectos Especiales

**Pulse (Geolocalización)**
```dart
AnimationController(
  duration: Duration(milliseconds: 1000),
  vsync: this,
)..repeat(reverse: true);
```

**Fade In (Splash)**
```dart
Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(parent: controller, curve: Curves.easeIn),
);
```

**Scale (Splash Logo)**
```dart
Tween<double>(begin: 0.5, end: 1.0).animate(
  CurvedAnimation(parent: controller, curve: Curves.elasticOut),
);
```

---

## 📐 Espaciado

### Sistema de 8pt Grid

```
XS:  4px
S:   8px
M:   12px
L:   16px
XL:  20px
2XL: 24px
3XL: 32px
4XL: 40px
```

### Márgenes de Pantalla
- Móvil: 16-20px horizontales
- Tablet: 24-32px horizontales

---

## 🎯 Elementos Específicos

### Barra de Progreso
- Altura: 8-12px
- Border Radius: 10px
- Fondo: cardBg con opacidad
- Fill: Gradiente o color sólido

### Avatares
- Tamaño estándar: 40-60px
- Borde: 2-3px gradiente o color acento
- Shadow: Glow suave

### Badges/Tags
- Padding: 6-12px horizontal, 4-8px vertical
- Border Radius: 20px (pill shape)
- Fondo: Semi-transparente o gradiente

### Modal/Dialog
- Fondo: cardBg
- Border Radius: 20px
- Padding: 24px
- Botones: Full width en móvil

---

## 📱 Responsive Design

### Breakpoints
- Móvil: < 600px
- Tablet: 600px - 900px
- Desktop: > 900px

### Adaptaciones
- Grid 2 columnas en móvil
- Grid 3-4 columnas en tablet
- Padding aumenta progresivamente

---

## 🌟 Efectos Especiales

### Glassmorphism (Opcional)
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.2),
    ),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: ...,
  ),
)
```

### Glow Effects
```dart
BoxShadow(
  color: color.withOpacity(0.4),
  blurRadius: 20,
  spreadRadius: 2,
)
```

### Shimmer (Loading)
```dart
// Para estados de carga futuros
LinearGradient(
  colors: [
    Colors.white.withOpacity(0.1),
    Colors.white.withOpacity(0.3),
    Colors.white.withOpacity(0.1),
  ],
)
```

---

## 🎮 Elementos de Juego

### Indicadores de Progreso
- **XP Bar**: Rosa/Púrpura con fill animado
- **Quest Progress**: Contador + Barra

### Monedas y Recompensas
- **Icon**: 💰 o medallón dorado
- **Color**: Gradiente dorado
- **Animación**: Scale bounce al obtener

### Power Items
- **Background**: Gradiente específico por tipo
- **Icon**: Emoji grande centrado
- **Badge**: Contador en esquina si stackable

### Estados del Jugador
- **Congelado**: Overlay azul con cristales de hielo
- **Con Escudo**: Borde dorado brillante
- **Boost**: Partículas o glow animado

---

## 📊 Visualización de Datos

### Ranking
- **Top 3**: Podio con alturas diferentes
- **Colores**: Oro, Plata, Bronce
- **Resto**: Lista con numeración

### Stats del Jugador
- **Cards Pequeños**: Grid 2x3
- **Icon + Valor + Label**
- **Color por stat**: Azul (speed), Rojo (strength), Púrpura (intelligence)

---

## 🔍 Iconografía

### Emojis y Unicode
Usado para dar personalidad:
- 📍 Ubicación
- 📷 QR
- 🎮 Minijuego
- 🏪 Tienda
- ⚡ Velocidad
- 🛡️ Escudo
- ❄️ Freeze
- 🔥 Caliente
- 💡 Pista

### Material Icons
Para UI estándar:
- Navigation
- Actions
- Status
- Media

---

## ✅ Checklist de Diseño

Al crear nuevas pantallas, asegúrate de:

- [ ] Usar el gradiente de fondo oscuro
- [ ] Aplicar border radius consistente (12-20px)
- [ ] Incluir spacing del sistema 8pt
- [ ] Usar tipografía correcta (Outfit/Inter)
- [ ] Añadir micro-animaciones en interacciones
- [ ] Aplicar estados visuales (hover, pressed, disabled)
- [ ] Mantener contraste adecuado (texto blanco/gris sobre oscuro)
- [ ] Usar iconos consistentes
- [ ] Aplicar shadows/glows sutiles
- [ ] Testear en diferentes tamaños de pantalla

---

**¡Diseña con pasión y crea experiencias WOW! 🎨✨**
