import 'package:flutter/material.dart'; // Mantener por IconData si fuera necesario, pero el usuario pidió eliminar referencias a Navigator/BuildContext. 
// Para ser estricto con "Limpieza de UI en Datos", deberíamos quitar Material. 
// Pero ClueType.typeIcon devuelve un String (emoji) que no requiere Material.
// Sin embargo, ClueType usa colores? No.
// Vamos a eliminar los imports de pantallas tambien.

enum ClueType {
  qrScan,
  geolocation,
  minigame,
  npcInteraction,
}

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
  wordScramble;      

  String get dbValue => toString().split('.').last;

  String get label {
    switch (this) {
      case PuzzleType.ticTacToe: return '❌⭕ La Vieja (Tic Tac Toe)';
      case PuzzleType.hangman: return '🔤 El Ahorcado';
      case PuzzleType.slidingPuzzle: return '🧩 Rompecabezas (Sliding)';
      case PuzzleType.tetris: return '🧱 Tetris';
      case PuzzleType.findDifference: return '🔎 Encuentra la Diferencia';
      case PuzzleType.flags: return '🏳️ Banderas (Quiz)';
      case PuzzleType.minesweeper: return '💣 Buscaminas';
      case PuzzleType.snake: return '🐍 Snake (Culebrita)';
      case PuzzleType.blockFill: return '🟦 Rellenar Bloques';
      case PuzzleType.codeBreaker: return '🔐 Caja Fuerte (Code)';
      case PuzzleType.imageTrivia: return '🖼️ Desafío Visual (Trivia)';
      case PuzzleType.wordScramble: return '🔤 Palabra Misteriosa';
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
        return true; 
      default:
        return false;
    }
  }

  String get defaultQuestion {
    switch (this) {
      case PuzzleType.ticTacToe: return 'Gana una partida contra la IA';
      case PuzzleType.slidingPuzzle: return 'Ordena la imagen correctamente';
      case PuzzleType.hangman: return 'Pista sobre la palabra...';
      case PuzzleType.tetris: return 'Alcanza el puntaje objetivo';
      case PuzzleType.findDifference: return 'Encuentra el icono diferente';
      case PuzzleType.flags: return 'Adivina 5 banderas correctamente';
      case PuzzleType.minesweeper: return 'Descubre todas las casillas seguras';
      case PuzzleType.snake: return 'Come 15 manzanas sin chocar';
      case PuzzleType.blockFill: return 'Rellena todo el camino';
      case PuzzleType.codeBreaker: return 'Descifra el código de 4 dígitos';
      case PuzzleType.imageTrivia: return '¿Qué es lo que ves en la imagen?';
      case PuzzleType.wordScramble: return 'Ordena las letras para formar la palabra';
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
  final int coinReward;
  bool isCompleted;
  bool isLocked;
  final int sequenceIndex;

  Clue({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.type,
    this.xpReward = 50,
    this.coinReward = 10,
    this.isCompleted = false,
    this.isLocked = true,
    this.sequenceIndex = 0,
  });

  /// Abstract getters (moved logic out, kept string/icon data)
  String get typeName;
  String get typeIcon;

  // Virtual getters for compatibility (returning null by default)
  double? get latitude => null;
  double? get longitude => null;
  String? get qrCode => null;
  String? get minigameUrl => null;
  String? get riddleQuestion => null;
  String? get riddleAnswer => null;
  PuzzleType get puzzleType => PuzzleType.slidingPuzzle; 
  
  factory Clue.fromJson(Map<String, dynamic> json) {
    
    // Safety check for image URLs in JSON (from original code)
    String? image = json['image_url'];
    if (image != null && (image.contains('C:/') || image.contains('file:///'))) {
       // print('⚠️ Ruta inválida detectada y bloqueada: $image'); // Removing print to keep purely data if possible, or use debugPrint
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
  final double? latitude;
  final double? longitude;
  final String? qrCode;

  PhysicalClue({
    required super.id,
    required super.title,
    required super.description,
    required super.hint,
    required super.type,
    super.xpReward,
    super.coinReward,
    super.isCompleted,
    super.isLocked,
    super.sequenceIndex,
    this.latitude,
    this.longitude,
    this.qrCode,
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
      coinReward: (json['coin_reward'] as num?)?.toInt() ?? 10,
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
  
  // REMOVED: executeAction
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
    super.coinReward,
    super.isCompleted,
    super.isLocked,
    super.sequenceIndex,
    this.minigameUrl,
    this.riddleQuestion,
    this.riddleAnswer,
    this.puzzleType = PuzzleType.slidingPuzzle,
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
      coinReward: (json['coin_reward'] as num?)?.toInt() ?? 10,
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      isLocked: json['isLocked'] ?? json['is_locked'] ?? true,
      sequenceIndex: json['sequence_index'] ?? 0,
    );
  }

  @override
  String get typeName => 'Minijuego';

  @override
  String get typeIcon => '🎮';

  // REMOVED: executeAction
}