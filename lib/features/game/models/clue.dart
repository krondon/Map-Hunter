import 'package:flutter/material.dart';

enum ClueType {
  qrScan,
  geolocation,
  minigame,
  npcInteraction,
}

enum MinigameDifficulty { easy, medium, hard }

enum PuzzleType {
  slidingPuzzle,
  ticTacToe,
  hangman,
  tetris,
  findDifference,
  flags,
  minesweeper,
  snake,
  blockFill,
  codeBreaker,
  imageTrivia,
  wordScramble,
  memorySequence,
  drinkMixer,
  librarySort,
  fastNumber,
  bagShuffle,
  chargeShaker,
  emojiMovie,
  virusTap,
  droneDodge,
  holographicPanels,
  missingOperator,
  primeNetwork,
  percentageCalculation,
  chronologicalOrder,
  capitalCities,
  trueFalse,
  matchThree;

  String get dbValue => toString().split('.').last;

  /// Difficulty level for automation and balancing
  MinigameDifficulty get difficulty {
    switch (this) {
      // EASY: Simple logic, fast completion
      case PuzzleType.slidingPuzzle:
      case PuzzleType.ticTacToe:
      case PuzzleType.imageTrivia:
      case PuzzleType.trueFalse:
      case PuzzleType.virusTap:
      case PuzzleType.flags:
      case PuzzleType.matchThree:
      case PuzzleType.fastNumber:
        return MinigameDifficulty.easy;

      // MEDIUM: Requires some focus or memory
      case PuzzleType.hangman:
      case PuzzleType.wordScramble:
      case PuzzleType.memorySequence:
      case PuzzleType.emojiMovie:
      case PuzzleType.bagShuffle:
      case PuzzleType.droneDodge:
      case PuzzleType.missingOperator:
      case PuzzleType.capitalCities:
        return MinigameDifficulty.medium;

      // HARD: High focus, strategy, or math
      case PuzzleType.tetris:
      case PuzzleType.minesweeper:
      case PuzzleType.snake:
      case PuzzleType.blockFill:
      case PuzzleType.codeBreaker:
      case PuzzleType.holographicPanels:
      case PuzzleType.primeNetwork:
      case PuzzleType.percentageCalculation:
      case PuzzleType.chronologicalOrder:
      case PuzzleType.drinkMixer:
      case PuzzleType.librarySort:
      case PuzzleType.findDifference:
        return MinigameDifficulty.hard;

      default:
        return MinigameDifficulty.medium;
    }
  }

  /// Whether this minigame is suitable for auto-generation
  bool get automationAvailable {
    // Exclude chargeShaker as it was noted as problematic/manual in some contexts
    if (this == PuzzleType.chargeShaker) return false;
    return true;
  }

  /// Helper to get all puzzles of a specific difficulty
  static Iterable<PuzzleType> byDifficulty(MinigameDifficulty level) {
    return PuzzleType.values
        .where((p) => p.automationAvailable && p.difficulty == level);
  }

  String get label {
    switch (this) {
      case PuzzleType.ticTacToe:
        return '❌⭕ La Vieja (Tic Tac Toe)';
      case PuzzleType.hangman:
        return '🔤 El Ahorcado';
      case PuzzleType.slidingPuzzle:
        return '🧩 Rompecabezas (Sliding)';
      case PuzzleType.tetris:
        return '🧱 Tetris';
      case PuzzleType.findDifference:
        return '🔎 Encuentra la Diferencia';
      case PuzzleType.flags:
        return '🏳️ Banderas (Quiz)';
      case PuzzleType.minesweeper:
        return '💣 Buscaminas';
      case PuzzleType.snake:
        return '🐍 Snake (Culebrita)';
      case PuzzleType.blockFill:
        return '🟦 Rellenar Bloques';
      case PuzzleType.codeBreaker:
        return '🔐 Caja Fuerte (Code)';
      case PuzzleType.imageTrivia:
        return '🖼️ Trivia de Imagen';
      case PuzzleType.wordScramble:
        return '🔤🔠 Ordenar Palabras';
      case PuzzleType.chargeShaker:
        return '⚡ Agitar Carga';
      case PuzzleType.emojiMovie:
        return '🎬 Adivina Película';
      case PuzzleType.virusTap:
        return '🦠 Virus Tap (Whack-a-Mole)';
      case PuzzleType.droneDodge:
        return '🚁 Drone Esquiva';
      case PuzzleType.holographicPanels:
        return '🔢 Paneles Holográficos';
      case PuzzleType.missingOperator:
        return '➕ Operador Perdido';
      case PuzzleType.primeNetwork:
        return '🕸️ Red de Primos';
      case PuzzleType.percentageCalculation:
        return '💯 Porcentajes';
      case PuzzleType.chronologicalOrder:
        return '📅 Orden Cronológico';
      case PuzzleType.capitalCities:
        return '🌍 Capitales';
      case PuzzleType.trueFalse:
        return '✅❌ Verdadero o Falso';
      case PuzzleType.matchThree:
        return '🍬 Match 3';
      case PuzzleType.memorySequence:
        return '🧠 Secuencia de Memoria (Simon)';
      case PuzzleType.drinkMixer:
        return '🍹 Cócteles de Neón (Mixer)';
      case PuzzleType.librarySort:
        return '📚 Biblioteca de Tonos (Sort)';
      case PuzzleType.fastNumber:
        return '⚡ Número Veloz';
      case PuzzleType.bagShuffle:
        return '🛍️ El Trile (Bolsas)';
    }
  }

  bool get isAutoValidation {
    switch (this) {
      case PuzzleType.ticTacToe:
      case PuzzleType.slidingPuzzle:
      case PuzzleType.tetris:
      case PuzzleType.findDifference:
      case PuzzleType.flags:
      case PuzzleType.minesweeper:
      case PuzzleType.snake:
      case PuzzleType.blockFill:
      case PuzzleType.memorySequence: // Auto-validado al ganar
      case PuzzleType.drinkMixer:
      case PuzzleType.librarySort:
      case PuzzleType.fastNumber:
      case PuzzleType.bagShuffle:
      case PuzzleType.chargeShaker:
      case PuzzleType.emojiMovie:
      case PuzzleType.virusTap:
      case PuzzleType.droneDodge:
      case PuzzleType.holographicPanels:
      case PuzzleType.missingOperator:
      case PuzzleType.primeNetwork:
      case PuzzleType.percentageCalculation:
      case PuzzleType.chronologicalOrder:
      case PuzzleType.capitalCities:
      case PuzzleType.trueFalse:
      case PuzzleType.matchThree:
        return true;
      default:
        return false;
    }
  }

  String get defaultQuestion {
    switch (this) {
      case PuzzleType.ticTacToe:
        return 'Gana una partida contra la IA';
      case PuzzleType.slidingPuzzle:
        return 'Ordena la imagen correctamente';
      case PuzzleType.hangman:
        return 'Pista sobre la palabra...';
      case PuzzleType.tetris:
        return 'Alcanza el puntaje objetivo';
      case PuzzleType.findDifference:
        return 'Encuentra el icono diferente';
      case PuzzleType.flags:
        return 'Adivina 5 banderas correctamente';
      case PuzzleType.minesweeper:
        return 'Descubre todas las casillas seguras';
      case PuzzleType.snake:
        return 'Come 15 manzanas sin chocar';
      case PuzzleType.blockFill:
        return 'Rellena todo el camino';
      case PuzzleType.codeBreaker:
        return 'Descifra el código de 4 dígitos';
      case PuzzleType.imageTrivia:
        return '¿Qué es lo que ves en la imagen?';
      case PuzzleType.wordScramble:
        return 'Ordena las letras para formar la palabra';
      case PuzzleType.memorySequence:
        return 'Repite la secuencia de colores correctamente';
      case PuzzleType.drinkMixer:
        return 'Mezcla los colores para igualar el cóctel';
      case PuzzleType.librarySort:
        return 'Ordena los libros por su tonalidad de color';
      case PuzzleType.fastNumber:
        return 'Escribe el número de 5 cifras que aparecerá brevemente';
      case PuzzleType.bagShuffle:
        return 'Sigue la bolsa que contiene el color solicitado';
      case PuzzleType.chargeShaker:
        return '¡Agita el celular para cargar la batería!';
      case PuzzleType.emojiMovie:
        return 'Adivina la película con los emojis';
      case PuzzleType.virusTap:
        return 'Elimina 15 virus antes de que acabe el tiempo';
      case PuzzleType.droneDodge:
        return 'Sobrevive 30 segundos esquivando los obstáculos';
      case PuzzleType.holographicPanels:
        return 'Selecciona la ecuación con el resultado mayor.';
      case PuzzleType.missingOperator:
        return 'Encuentra el operador que falta.';
      case PuzzleType.primeNetwork:
        return 'Toca solo los números primos.';
      case PuzzleType.percentageCalculation:
        return 'Calcula el porcentaje correcto.';
      case PuzzleType.chronologicalOrder:
        return 'Ordena los eventos cronológicamente.';
      case PuzzleType.capitalCities:
        return 'Selecciona la capital correcta.';
      case PuzzleType.trueFalse:
        return 'Responde correctamente 5 afirmaciones.';
      case PuzzleType.matchThree:
        return 'Combina 3 elementos iguales.';
    }
  }
}

/// Base abstract class for all clues
abstract class Clue {
  final String id;
  final String title;
  final String description;
  final String hint;
  final ClueType type;
  final int xpReward;
  // final int coinReward; // REMOVED
  bool isCompleted;
  bool isLocked;
  final int sequenceIndex;

  // Universal coordinates for all clue types (including Minigames)
  final double? latitude;
  final double? longitude;
  final String? qrCode;

  Clue({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.type,
    this.xpReward = 50,
    // this.coinReward = 10,
    this.isCompleted = false,
    this.isLocked = true,
    this.sequenceIndex = 0,
    this.latitude,
    this.longitude,
    this.qrCode,
  });

  /// Abstract getters
  String get typeName;
  String get typeIcon;

  /// Strategy Pattern: Each clue type knows how to check its own unlock requirements.
  Future<bool> checkUnlockRequirements();

  String? get minigameUrl => null;
  String? get riddleQuestion => null;
  String? get riddleAnswer => null;
  PuzzleType get puzzleType => PuzzleType.slidingPuzzle;

  factory Clue.fromJson(Map<String, dynamic> json) {
    // Safety check for image URLs in JSON
    String? image = json['image_url'];
    if (image != null &&
        (image.contains('C:/') || image.contains('file:///'))) {
      // local path handling
    }

    final typeStr = json['type'] as String?;
    final type = ClueType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => ClueType.qrScan,
    );

    if (type == ClueType.minigame) {
      return OnlineClue.fromJson(json, type);
    } else {
      return PhysicalClue.fromJson(json, type);
    }
  }
}

class PhysicalClue extends Clue {
  PhysicalClue({
    required super.id,
    required super.title,
    required super.description,
    required super.hint,
    required super.type,
    super.xpReward,
    // super.coinReward, // REMOVED
    super.isCompleted,
    super.isLocked,
    super.sequenceIndex,
    super.latitude,
    super.longitude,
    super.qrCode,
  });

  factory PhysicalClue.fromJson(Map<String, dynamic> json, ClueType type) {
    return PhysicalClue(
      id: json['id'].toString(),
      title: json['title'],
      description: json['description'] ?? '',
      hint: json['hint'] ?? '',
      type: type,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      qrCode: json['qr_code'],
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 50,
      // coinReward: (json['coin_reward'] as num?)?.toInt() ?? 10, // REMOVED
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      isLocked: json['isLocked'] ?? json['is_locked'] ?? true,
      sequenceIndex: json['sequence_index'] ?? 0,
    );
  }

  @override
  String get typeName {
    switch (type) {
      case ClueType.qrScan:
        return 'Escanear QR';
      case ClueType.geolocation:
        return 'Ubicación';
      case ClueType.npcInteraction:
        return 'Tiendita';
      default:
        return 'Física';
    }
  }

  @override
  String get typeIcon {
    switch (type) {
      case ClueType.qrScan:
        return '📷';
      case ClueType.geolocation:
        return '📍';
      case ClueType.npcInteraction:
        return '🏪';
      default:
        return '📍';
    }
  }

  @override
  Future<bool> checkUnlockRequirements() async {
    return false;
  }
}

class OnlineClue extends Clue {
  final String? minigameUrl;
  final String? riddleQuestion;
  final String? riddleAnswer;
  final PuzzleType puzzleType;

  OnlineClue({
    required super.id,
    required super.title,
    required super.description,
    required super.hint,
    required super.type,
    super.xpReward,
    // super.coinReward, // REMOVED
    super.isCompleted,
    super.isLocked,
    super.sequenceIndex,
    this.minigameUrl,
    this.riddleQuestion,
    this.riddleAnswer,
    this.puzzleType = PuzzleType.slidingPuzzle,
    super.latitude,
    super.longitude,
    super.qrCode,
  });

  factory OnlineClue.fromJson(Map<String, dynamic> json, ClueType type) {
    return OnlineClue(
      id: json['id'].toString(),
      title: json['title'],
      description: json['description'] ?? '',
      hint: json['hint'] ?? '',
      type: type,
      minigameUrl: json['minigame_url'],
      riddleQuestion: json['riddle_question'],
      riddleAnswer: json['riddle_answer'],
      puzzleType: json['puzzle_type'] != null
          ? PuzzleType.values.firstWhere(
              (e) => e.toString().split('.').last == json['puzzle_type'],
              orElse: () => PuzzleType.slidingPuzzle,
            )
          : PuzzleType.slidingPuzzle,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 50,
      // coinReward: (json['coin_reward'] as num?)?.toInt() ?? 10, // REMOVED
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      isLocked: json['isLocked'] ?? json['is_locked'] ?? true,
      sequenceIndex: json['sequence_index'] ?? 0,
      // Parse coordinates for online clues
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      qrCode: json['qr_code'],
    );
  }

  @override
  String get typeName => 'Minijuego';

  @override
  String get typeIcon => '🎮';

  @override
  Future<bool> checkUnlockRequirements() async {
    return true;
  }
}
