import 'package:flutter/material.dart';

enum PowerType {
  buff,   // Beneficio propio (Escudo, Vida)
  debuff, // Ataque al rival (Congelar, Pantalla negra)
  utility, // Utilidad (Pista, Radar)
  blind, // Específico para pantalla negra
  freeze, // Específico para congelar
  shield, // Específico para escudo
  timePenalty, // Específico para penalización
  hint, // Específico para pista
  speedBoost // Específico para velocidad
}

class PowerItem {
  final String id;
  final String name;
  final String description;
  final PowerType type;
  final int cost;
  final String icon;
  final Color color;
  final int durationMinutes;

  const PowerItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.cost,
    required this.icon,
    this.color = Colors.blue,
    this.durationMinutes = 0,
  });

  // ESTA ES LA LISTA MAESTRA QUE DEBE COINCIDIR CON LA BASE DE DATOS
  static List<PowerItem> getShopItems() {
    return [
      // --- OFENSIVOS ---
      const PowerItem(
        id: 'freeze', // ID EXACTO DE LA BD
        name: 'Congelar',
        description: 'Congela a un jugador por 2 minutos',
        type: PowerType.freeze,
        cost: 50,
        icon: '❄️',
        color: Colors.cyan,
        durationMinutes: 2,
      ),
      const PowerItem(
        id: 'black_screen', // ID EXACTO DE LA BD
        name: 'Pantalla Negra',
        description: 'Ciega al rival temporalmente',
        type: PowerType.blind,
        cost: 100,
        icon: '🕶️',
        color: Colors.black87,
        durationMinutes: 0, 
      ),
      const PowerItem(
        id: 'slow_motion',
        name: 'Cámara Lenta',
        description: 'Ralentiza al oponente',
        type: PowerType.debuff,
        cost: 80,
        icon: '🐢',
        color: Colors.orange,
        durationMinutes: 2,
      ),
      const PowerItem(
        id: 'time_penalty',
        name: 'Penalización',
        description: 'Resta tiempo al oponente',
        type: PowerType.timePenalty,
        cost: 60,
        icon: '⏱️',
        color: Colors.redAccent,
        durationMinutes: 3,
      ),

      // --- DEFENSIVOS ---
      const PowerItem(
        id: 'shield', // ID EXACTO DE LA BD
        name: 'Escudo',
        description: 'Protección contra ataques',
        type: PowerType.shield,
        cost: 75,
        icon: '🛡️',
        color: Colors.indigo,
        durationMinutes: 5,
      ),
      const PowerItem(
        id: 'speed_boost',
        name: 'Velocidad',
        description: 'Aumenta tu velocidad',
        type: PowerType.speedBoost,
        cost: 40,
        icon: '⚡',
        color: Colors.yellow,
        durationMinutes: 3,
      ),
      const PowerItem(
        id: 'energy_drink',
        name: 'Bebida Energética',
        description: 'Recupera energía',
        type: PowerType.buff,
        cost: 20,
        icon: '🥤',
        color: Colors.green,
      ),
      
      // --- UTILIDAD ---
      const PowerItem(
        id: 'hint',
        name: 'Pista Extra',
        description: 'Revela información clave',
        type: PowerType.hint,
        cost: 30,
        icon: '💡',
        color: Colors.amber,
      ),
      // --- IMPORTANTE: Agregamos este por si acaso quedó basura vieja en la BD ---
      const PowerItem(
        id: 'return', 
        name: 'Devolución',
        description: 'Devuelve el ataque',
        type: PowerType.utility,
        cost: 60,
        icon: '↩️',
        color: Colors.purple,
      ),
    ];
  }
}