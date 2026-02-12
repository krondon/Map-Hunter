import 'package:flutter/material.dart';

class StoryMoment {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  StoryMoment({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

class StoryData {
  static final List<StoryMoment> moments = [
    StoryMoment(
      title: 'Trébol Dorado 1',
      subtitle: 'Fragmentos de Memoria',
      description:
          'El mapa de tu reino está corrupto en la base de datos del futuro. Deberás reconstruirlo pieza por pieza para calibrar tu brújula temporal.',
      icon: Icons.extension,
      gradient: [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 2',
      subtitle: 'El Código de Acceso',
      description:
          'La terminal de seguridad no reconoce tu lenguaje antiguo. Deberás descifrar las palabras clave antes de que el sistema te bloquee permanentemente.',
      icon: Icons.lock_open,
      gradient: [const Color(0xFF06B6D4), const Color(0xFF10B981)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 3',
      subtitle: 'Archivos Históricos',
      description:
          'Para confirmar tu procedencia, el ordenador central te pondrá a prueba sobre los símbolos de los reinos que dejaron de existir hace siglos.',
      icon: Icons.history_edu,
      gradient: [const Color(0xFF10B981), const Color(0xFF84CC16)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 4',
      subtitle: 'Campo de Desechos Nanobot',
      description:
          'El camino hacia la zona de carga está plagado de peligros ocultos. Deberás avanzar con extrema precaución para no activar las defensas automáticas.',
      icon: Icons.warning_amber,
      gradient: [const Color(0xFF84CC16), const Color(0xFFF59E0B)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 5',
      subtitle: 'Sobrecarga de Datos',
      description:
          'Los circuitos de la ciudad están al límite. Deberás navegar por el flujo de información sin tocar las paredes de datos o el sistema colapsará.',
      icon: Icons.cable,
      gradient: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 6',
      subtitle: 'Restauración de Legado',
      description:
          'Una imagen de tu castillo está fragmentada por el tiempo. Deberás restaurarla completamente para anclar tu mente al pasado.',
      icon: Icons.palette,
      gradient: [const Color(0xFFEF4444), const Color(0xFFEC4899)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 7',
      subtitle: 'Falla en la Simulación',
      description:
          'El futuro está intentando engañarte con una copia falsa de tu realidad. Deberás encontrar las anomalías en la matriz para romper el encantamiento.',
      icon: Icons.visibility,
      gradient: [const Color(0xFFEC4899), const Color(0xFFD946EF)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 8',
      subtitle: 'Sincronización de Núcleo',
      description:
          'Un último ajuste de sistemas antes de la gran apertura del portal. Cada segundo cuenta.',
      icon: Icons.settings_suggest,
      gradient: [const Color(0xFFD946EF), const Color(0xFF8B5CF6)],
    ),
    StoryMoment(
      title: 'Trébol Dorado 9',
      subtitle: 'El Salto de Fe',
      description:
          'La realidad se está desmoronando mientras el portal se abre. Deberás estabilizar la brecha cuántica con precisión perfecta para permitir tu regreso a Asthoria.',
      icon: Icons.flash_on,
      gradient: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
    ),
  ];
}
