import '../models/player.dart';

extension PlayerX on Player {
  /// Devuelve true si este jugador tiene más progreso que [other]
  bool isAheadOf(Player other) {
    if (this.totalXP != other.totalXP) {
      return this.totalXP > other.totalXP;
    }
    // Si tienen mismo XP/Pistas, desempatar por quién llegó primero (si tuviéramos timestamp)
    // Por ahora igual.
    return false;
  }

  /// Progreso normalizado entre 0.0 y 1.0
  double getNormalizedProgress(int totalClues) {
    if (totalClues <= 0) return 0.0;
    return (this.totalXP / totalClues).clamp(0.0, 1.0);
  }
}
