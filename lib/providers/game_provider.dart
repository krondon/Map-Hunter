import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../models/player.dart';

class GameProvider extends ChangeNotifier {
  List<Clue> _clues = [];
  List<Player> _leaderboard = [];
  int _currentClueIndex = 0;
  bool _isGameActive = false;
  
  List<Clue> get clues => _clues;
  List<Player> get leaderboard => _leaderboard;
  Clue? get currentClue => _currentClueIndex < _clues.length ? _clues[_currentClueIndex] : null;
  
  // Getter que faltaba para el Mini Mapa
  int get currentClueIndex => _currentClueIndex;
  
  bool get isGameActive => _isGameActive;
  int get completedClues => _clues.where((c) => c.isCompleted).length;
  int get totalClues => _clues.length;
  
  GameProvider() {
    _initializeMockData();
  }
  
  void _initializeMockData() {
    // Mock clues
    _clues = [
      Clue(
        id: '1',
        title: 'La Cámara Secreta',
        description: 'Descifra el código de la bóveda antigua.',
        hint: 'El año que cambió la historia.',
        type: ClueType.qrScan,
        puzzleType: PuzzleType.codeBreaker,
        riddleQuestion: '¿En qué año comenzó el nuevo milenio?',
        riddleAnswer: '2000',
        xpReward: 100,
        coinReward: 20,
      ),
      Clue(
        id: '2',
        title: 'Monumento Perdido',
        description: 'Identifica esta maravilla del mundo.',
        hint: 'Una de las 7 maravillas modernas.',
        type: ClueType.qrScan,
        puzzleType: PuzzleType.imageTrivia,
        minigameUrl: 'https://picsum.photos/800/600?random=1',
        riddleQuestion: '¿Qué monumento famoso es este?',
        riddleAnswer: 'taj mahal',
        xpReward: 150,
        coinReward: 30,
      ),
      Clue(
        id: '3',
        title: 'El Tesoro Escondido',
        description: 'Ordena las letras del cofre mágico.',
        hint: 'Lo que todos los piratas buscan.',
        type: ClueType.qrScan,
        puzzleType: PuzzleType.wordScramble,
        riddleQuestion: 'Ordena estas letras:',
        riddleAnswer: 'TREASURE',
        xpReward: 120,
        coinReward: 25,
      ),
      Clue(
        id: '4',
        title: 'Acertijo del Sabio',
        description: 'Resuelve el enigma ancestral.',
        hint: 'Piensa en las horas del día.',
        type: ClueType.qrScan,
        puzzleType: PuzzleType.riddle,
        riddleQuestion: 'Tengo cara pero no cuerpo, manos pero no puedo aplaudir. ¿Qué soy?',
        riddleAnswer: 'reloj',
        xpReward: 130,
        coinReward: 28,
      ),
    ];
    
    // Desbloquear la primera pista
    if (_clues.isNotEmpty) {
      _clues[0].isLocked = false;
    }
    
    // Mock leaderboard
    _leaderboard = [
      Player(
        id: '1',
        name: 'Cazador Pro',
        email: 'pro@game.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=1',
        level: 8,
        totalXP: 1250,
        profession: 'Speedrunner',
        coins: 350,
      ),
      Player(
        id: '2',
        name: 'Estratega Master',
        email: 'master@game.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=2',
        level: 7,
        totalXP: 1100,
        profession: 'Strategist',
        coins: 280,
      ),
      Player(
        id: '3',
        name: 'Guerrero Audaz',
        email: 'warrior@game.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=3',
        level: 6,
        totalXP: 950,
        profession: 'Warrior',
        coins: 220,
      ),
      Player(
        id: '4',
        name: 'Explorador',
        email: 'explorer@game.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=4',
        level: 5,
        totalXP: 750,
        profession: 'Balanced',
        coins: 180,
      ),
      Player(
        id: '5',
        name: 'Novato Listo',
        email: 'novice@game.com',
        avatarUrl: 'https://i.pravatar.cc/150?img=5',
        level: 3,
        totalXP: 420,
        profession: 'Novice',
        coins: 95,
      ),
    ];
  }
  
  void startGame() {
    _isGameActive = true;
    _currentClueIndex = 0;
    notifyListeners();
  }
  
  void completeCurrentClue() {
    if (_currentClueIndex < _clues.length) {
      // Marcar la pista actual como completada
      _clues[_currentClueIndex].isCompleted = true;
      
      // Desbloquear la siguiente pista si existe
      if (_currentClueIndex + 1 < _clues.length) {
        _clues[_currentClueIndex + 1].isLocked = false;
      }
      
      // Avanzar al siguiente índice
      _currentClueIndex++;
      
      notifyListeners();
    }
  }
  
  void switchToClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1 && !_clues[index].isLocked) {
      _currentClueIndex = index;
      notifyListeners();
    }
  }
  
  void updateLeaderboard(Player player) {
    final index = _leaderboard.indexWhere((p) => p.id == player.id);
    if (index != -1) {
      _leaderboard[index] = player;
    } else {
      _leaderboard.add(player);
    }
    
    // Sort by total XP
    _leaderboard.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    notifyListeners();
  }
}
