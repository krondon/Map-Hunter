class Scenario {
  final String id;
  final String name;
  final String description;
  final String location;
  final String imageUrl;
  final String state;
  final int maxPlayers;
  final String starterClue;
  final String secretCode; // The code they need to find
  final double? latitude;
  final double? longitude;
  final DateTime? date;
  final bool isCompleted; // Nueva propiedad
  final String type;
  final int entryFee;
  final int currentParticipants;
  final String status;
  final int pot;

  const Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.imageUrl,
    required this.state,
    required this.maxPlayers,
    required this.starterClue,
    required this.secretCode,
    this.latitude,
    this.longitude,
    this.date,
    this.isCompleted = false,
    this.type = 'on_site',
    this.entryFee = 0,
    this.currentParticipants = 0,
    this.status = 'pending',
    this.pot = 0,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      imageUrl: json['image_url'] as String,
      state: json['state'] as String,
      maxPlayers: json['max_players'] as int,
      starterClue: json['starter_clue'] as String,
      secretCode: json['secret_code'] as String,
      latitude: (json['latitude'] is num?) ? (json['latitude'] as num?)?.toDouble() : null,
      longitude: (json['longitude'] is num?) ? (json['longitude'] as num?)?.toDouble() : null,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      isCompleted: json['is_completed'] ?? false,
      type: json['type'] ?? 'on_site',
      entryFee: json['entry_fee'] ?? 0,
      currentParticipants: (json['current_participants'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'pending',
      pot: (json['pot'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'image_url': imageUrl,
      'state': state,
      'max_players': maxPlayers,
      'starter_clue': starterClue,
      'secret_code': secretCode,
      'latitude': latitude,
      'longitude': longitude,
      'date': date?.toIso8601String(),
      'is_completed': isCompleted,
      'type': type,
      'entry_fee': entryFee,
      'current_participants': currentParticipants,
      'status': status,
      'pot': pot,
    };
  }
}
