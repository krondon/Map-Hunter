class PowerItem {
  final String id;
  final String name;
  final String description;
  final PowerType type;
  final int cost;
  final String icon;
  final int durationMinutes;
  
  PowerItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.cost,
    required this.icon,
    this.durationMinutes = 2,
  });
  
  static List<PowerItem> getShopItems() {
    return [
      PowerItem(
        id: 'freeze',
        name: 'Freeze',
        description: 'Congela a un jugador por 2 minutos',
        type: PowerType.freeze,
        cost: 50,
        icon: '❄️',
        durationMinutes: 2,
      ),
      PowerItem(
        id: 'shield',
        name: 'Escudo',
        description: 'Te protege de sabotajes por 5 minutos',
        type: PowerType.shield,
        cost: 75,
        icon: '🛡️',
        durationMinutes: 5,
      ),
      PowerItem(
        id: 'time_penalty',
        name: 'Penalización',
        description: 'Resta 3 minutos a otro jugador',
        type: PowerType.timePenalty,
        cost: 60,
        icon: '⏱️',
        durationMinutes: 3,
      ),
      PowerItem(
        id: 'hint',
        name: 'Pista Extra',
        description: 'Revela información adicional',
        type: PowerType.hint,
        cost: 30,
        icon: '💡',
      ),
      PowerItem(
        id: 'speed_boost',
        name: 'Velocidad',
        description: 'Aumenta tu velocidad por 3 minutos',
        type: PowerType.speedBoost,
        cost: 40,
        icon: '⚡',
        durationMinutes: 3,
      ),
    ];
  }
}

enum PowerType {
  freeze,
  shield,
  timePenalty,
  hint,
  speedBoost,
  buff,
  debuff,
}
