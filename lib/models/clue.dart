import 'package:flutter/material.dart';

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
}

enum PuzzleType {
  riddle,       // Acertijo de texto
  codeBreaker,  // Código numérico (ej: 1811)
  imageTrivia,  // Adivinar la foto (ej: Salto Ángel)
  wordScramble, // Ordenar letras (ej: AREPA)
}
