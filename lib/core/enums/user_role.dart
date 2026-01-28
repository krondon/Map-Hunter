/// User role enum for access control.
/// 
/// Defines the different roles a user can have in the system,
/// enabling the Spectator Mode and guest access patterns.
library;

/// User roles for access control and feature toggling.
enum UserRole {
  /// Active player who can participate in games.
  player,
  
  /// Observer who can watch but not interact with the game.
  spectator,
  
  /// Unauthenticated or limited access user.
  guest;

  /// Check if this role can modify game state.
  bool get canPlay => this == UserRole.player;

  /// Check if this role can view game state.
  bool get canView => this == UserRole.player || this == UserRole.spectator;

  /// Check if this role requires authentication.
  bool get requiresAuth => this != UserRole.guest;

  /// Display name for UI purposes.
  String get displayName {
    switch (this) {
      case UserRole.player:
        return 'Jugador';
      case UserRole.spectator:
        return 'Espectador';
      case UserRole.guest:
        return 'Invitado';
    }
  }
}
