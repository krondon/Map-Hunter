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

    String? image = json['image_url'];
    
    if (image != null && (image.contains('C:/') || image.contains('file:///'))) {
    print('⚠️ Ruta inválida detectada y bloqueada: $image');
    image = null; // La volvemos nula para que no rompa la app
  }

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
  riddle,       
  codeBreaker,  
  imageTrivia,  
  wordScramble, 
  slidingPuzzle, 
  ticTacToe, 
  hangman,
  tetris,
  flags,
  blockFill,
  findDifference,
  minesweeper,
  snake;

  // --- EXTENSIÓN: Propiedades para el Panel de Admin ---

  // 1. El valor exacto que se guarda en la Base de Datos (PostgreSQL)
  String get dbValue => toString().split('.').last;

  // 2. El texto bonito que verá el Administrador en el Dropdown
  String get label {
    switch (this) {
      case PuzzleType.riddle: return '❓ Acertijo de Texto';
      case PuzzleType.ticTacToe: return '❌⭕ La Vieja (Tic Tac Toe)';
      case PuzzleType.hangman: return '🔤 El Ahorcado';
      case PuzzleType.slidingPuzzle: return '🧩 Rompecabezas (Sliding)';
      case PuzzleType.codeBreaker: return '🔢 Descifrar Código';
      case PuzzleType.imageTrivia: return '🖼️ Trivia de Imagen';
      case PuzzleType.wordScramble: return '🔠 Ordenar Palabras';
      case PuzzleType.tetris: return '🧱 Tetris';
      case PuzzleType.flags: return '🏳️ Banderas';
      case PuzzleType.blockFill: return '🟦 Rellenar Bloques';
      case PuzzleType.findDifference: return '🔍 Encontrar Diferencias';
      case PuzzleType.minesweeper: return '💣 Buscaminas';
      case PuzzleType.snake: return '🐍 Serpiente';
    }
  }

  // 3. ¿El juego valida la victoria automáticamente? (Ej: TicTacToe envía "WIN")
  // Si es true, ocultamos el campo de respuesta en el admin.
  bool get isAutoValidation {
    switch (this) {
      case PuzzleType.ticTacToe:
      case PuzzleType.slidingPuzzle:
      case PuzzleType.tetris:
      case PuzzleType.flags:
      case PuzzleType.blockFill:
      case PuzzleType.findDifference:
      case PuzzleType.minesweeper:
      case PuzzleType.snake:
        return true;  
      default:
        return false;
    }
  }

  // 4. Pregunta o instrucción por defecto para ahorrar tiempo al admin
  String get defaultQuestion {
    switch (this) {
      case PuzzleType.ticTacToe: return 'Gana una partida contra la IA';
      case PuzzleType.slidingPuzzle: return 'Ordena la imagen correctamente';
      case PuzzleType.hangman: return 'Pista sobre la palabra...';
      case PuzzleType.tetris: return 'Consigue los puntos necesarios';
      case PuzzleType.flags: return 'Adivina la bandera correcta';
      case PuzzleType.blockFill: return 'Rellena todos los bloques sin repetir';
      case PuzzleType.findDifference: return 'Encuentra las diferencias';
      case PuzzleType.minesweeper: return 'Despeja el campo sin detonar minas';
      case PuzzleType.snake: return 'Come manzanas y no choques';
      default: return '';
    }
  }
}
