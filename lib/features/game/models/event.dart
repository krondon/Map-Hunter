import 'package:latlong2/latlong.dart';

class GameEvent {
  final String id;
  final String title;
  final String description; // Esta sería la "pista para solucionar el puzzle"
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime date;
  final String createdByAdminId;
  final String imageUrl;
  final String clue;        // <--- CAMBIO: Ahora es obligatorio (Pista de victoria)
  final int maxParticipants;
  final String pin;

  GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.createdByAdminId,
    required this.clue,     // <--- CAMBIO: Ahora es 'required'
    this.imageUrl = '',
    this.maxParticipants = 0,
    this.pin = '',
  });

  LatLng get location => LatLng(latitude, longitude);
}