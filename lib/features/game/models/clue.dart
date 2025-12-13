enum ClueType {
  qrScan,
  geolocation,
  minigame,
  npcInteraction,
}

class Clue {
  final String id;
  final String title;
  final String description;
  final String hint;
  final ClueType type;
  final double? latitude;
  final double? longitude;
  final String? qrCode;
  final String? minigameUrl;
  final int xpReward;
  final int coinReward;
  bool isCompleted;
  bool isLocked;
  
  // Nuevos campos para acertijos
  final String? riddleQuestion;
  final String? riddleAnswer;
  final PuzzleType puzzleType; // Nuevo campo

  Clue({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.type,
    this.latitude,
    this.longitude,
    this.qrCode,
    this.minigameUrl,
    this.xpReward = 50,
    this.coinReward = 10,
    this.isCompleted = false,
    this.isLocked = true,
    this.riddleQuestion,
    this.riddleAnswer,
    this.puzzleType = PuzzleType.riddle, // Por defecto es acertijo
  });
  
  String get typeIcon {
    switch (type) {
      case ClueType.qrScan:
        return '📷';
      case ClueType.geolocation:
        return '📍';
      case ClueType.minigame:
        return '🎮';
      case ClueType.npcInteraction:
        return '🏪';
    }
  }
  
  String get typeName {
    switch (type) {
      case ClueType.qrScan:
        return 'Escanear QR';
      case ClueType.geolocation:
        return 'Ubicación';
      case ClueType.minigame:
        return 'Minijuego';
      case ClueType.npcInteraction:
        return 'Tiendita';
    }
  }

  factory Clue.fromJson(Map<String, dynamic> json) {
    return Clue(
      id: json['id'].toString(), // Handle int or string
      title: json['title'],
      description: json['description'] ?? '',
      hint: json['hint'] ?? '',
      type: ClueType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ClueType.qrScan,
      ),
      latitude: json['latitude'],
      longitude: json['longitude'],
      qrCode: json['qr_code'],
      minigameUrl: json['minigame_url'],
      xpReward: json['xp_reward'] ?? 0,
      coinReward: json['coin_reward'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      isLocked: json['isLocked'] ?? true,
      riddleQuestion: json['riddle_question'],
      riddleAnswer: json['riddle_answer'],
      puzzleType: json['puzzle_type'] != null 
        ? PuzzleType.values.firstWhere(
            (e) => e.toString().split('.').last == json['puzzle_type'],
            orElse: () => PuzzleType.riddle,
          )
        : PuzzleType.riddle,
    );
  }
}

enum PuzzleType {
  riddle,       // Acertijo de texto
  codeBreaker,  // Código numérico (ej: 1811)
  imageTrivia,  // Adivinar la foto (ej: Salto Ángel)
  wordScramble, // Ordenar letras (ej: AREPA)
  slidingPuzzle, // Rompecabezas deslizante
}
