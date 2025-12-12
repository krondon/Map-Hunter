class GameEvent {
  final String id;
  final String title;
  final String description;
  final String locationName; // Nombre descriptivo (estado/ciudad)
  final double latitude; // Latitud
  final double longitude; // Longitud
  final DateTime date;
  final String createdByAdminId;

  // Nuevas propiedades del evento/competencia:
  final String imageUrl; // URL donde se guarda la imagen del evento
  final String clue; // La pista que lleva al evento
  final int maxParticipants; // Capacidad máxima
  final String pin; // Código de acceso para el usuario

  GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.createdByAdminId,
    required this.imageUrl, // AÑADIDO
    required this.clue, // AÑADIDO
    required this.maxParticipants, // AÑADIDO
    required this.pin, // AÑADIDO
  });

  // Método toMap actualizado para incluir las nuevas propiedades
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'date': date.toIso8601String(),
      'createdByAdminId': createdByAdminId,
      'imageUrl': imageUrl,
      'clue': clue,
      'maxParticipants': maxParticipants,
      'pin': pin,
    };
  }
}
