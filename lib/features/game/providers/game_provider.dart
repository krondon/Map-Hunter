import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clue.dart';
import '../../../shared/models/player.dart';
import '../services/game_service.dart';
import '../models/power_effect.dart';

class GameProvider extends ChangeNotifier {
  final GameService _gameService;
  
  List<Clue> _clues = [];
  List<Player> _leaderboard = [];
  int _currentClueIndex = 0;
  bool _isGameActive = false;
  bool _isLoading = false;
  String? _currentEventId;
  String? _errorMessage;
  int _lives = 3;
  bool _isRaceCompleted = false;
  bool _hintActive = false;
  String? _activeHintText;
  String? _targetPlayerId; // Selected rival for targeting
  List<PowerEffect> _activePowerEffects = [];

  List<PowerEffect> get activePowerEffects => _activePowerEffects;

  void _setRaceCompleted(bool completed, String source) {
    if (_isRaceCompleted != completed) {
      debugPrint('--- RACE STATUS CHANGE: $completed (via $source) ---');
      _isRaceCompleted = completed;
      notifyListeners();
    }
  }
  
  // Timer y Realtime para el ranking
  Timer? _leaderboardTimer;
  RealtimeChannel? _raceStatusChannel;
  
  List<Clue> get clues => _clues;
  List<Player> get leaderboard => _leaderboard;
  Clue? get currentClue => _currentClueIndex < _clues.length ? _clues[_currentClueIndex] : null;
  
  int get currentClueIndex => _currentClueIndex;
  
  bool get isGameActive => _isGameActive;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get completedClues => _clues.where((c) => c.isCompleted).length;
  int get totalClues => _clues.length;
  String? get currentEventId => _currentEventId;
  int get lives => _lives;
  bool get isRaceCompleted => _isRaceCompleted;
  bool get hintActive => _hintActive;
  String? get activeHintText => _activeHintText;
  String? get targetPlayerId => _targetPlayerId;
  
  bool get hasCompletedAllClues => totalClues > 0 && completedClues == totalClues;
  
  GameProvider({required GameService gameService}) : _gameService = gameService;

  /// Limpia COMPLETAMENTE el estado del juego
  void resetState() {
    _clues = [];
    _leaderboard = [];
    _currentClueIndex = 0;
    _isGameActive = false;
    _isLoading = false;
    _currentEventId = null;
    _errorMessage = null;
    _lives = 3;
    _isRaceCompleted = false;
    _hintActive = false;
    _activeHintText = null;
    
    stopLeaderboardUpdates();
    notifyListeners();
  }

  // --- GESTIÓN DE VIDAS ---

  Future<void> fetchLives(String userId) async {
    if (_currentEventId == null) return;
    try {
      final lives = await _gameService.fetchLives(_currentEventId!, userId);
      
      if (lives != null) {
        _lives = lives;
      } else {
        _lives = 3;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching lives: $e');
    }
  }
  
  Future<void> loseLife(String userId) async {
    if (_lives <= 0) return;
    if (_currentEventId == null) return;
    
    try {
      // 1. Optimistic Update
      _lives--;
      notifyListeners();
      
      // 2. Ejecutar servicio
      final remainingLives = await _gameService.loseLife(_currentEventId!, userId);
      
      // 3. Sincronizar verdad
      _lives = remainingLives;
      notifyListeners();

    } catch (e) {
      debugPrint('Error perdiendo vida: $e');
      // Rollback
      _lives++; 
      notifyListeners();
    }
  }

  // --- GESTIÓN DEL RANKING EN TIEMPO REAL ---

  void startLeaderboardUpdates() {
    fetchLeaderboard();
    stopLeaderboardUpdates();
    
    _leaderboardTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentEventId != null) {
        _fetchLeaderboardInternal(silent: true);
      }
    });
  }

  void stopLeaderboardUpdates() {
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
    _raceStatusChannel?.unsubscribe();
    _raceStatusChannel = null;
  }

  void subscribeToRaceStatus() {
    if (_currentEventId == null) return;
    
    _raceStatusChannel?.unsubscribe();
    
    _raceStatusChannel = _gameService.subscribeToRaceStatus(
      _currentEventId!, 
      totalClues,
      (completed, source) {
        _setRaceCompleted(completed, source);
      }
    );
  }

  Future<void> fetchLeaderboard({bool silent = false}) async {
    await _fetchLeaderboardInternal(silent: silent);
  }

  Future<void> _fetchLeaderboardInternal({bool silent = false}) async {
    if (_currentEventId == null) return;

    try {
      final data = await _gameService.getLeaderboard(_currentEventId!);
      _leaderboard = data;
      
      // Fetch active powers in parallel or sequence
      _activePowerEffects = await _gameService.getActivePowers(_currentEventId!);
      
      // Check for victory in leaderboard data
      for (var player in _leaderboard) {
        if (totalClues > 0 && player.totalXP >= totalClues) {
           _setRaceCompleted(true, 'Leaderboard Polling');
           break;
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
  }

  // --- FIN GESTIÓN RANKING ---
  
  Future<void> fetchClues({String? eventId, bool silent = false, String? userId}) async {
    if (eventId != null && eventId != _currentEventId) {
      _currentEventId = eventId;
      
      if (userId != null) {
        await fetchLives(userId); 
      } else {
        _lives = 0; 
      }
      _isRaceCompleted = false; 
      _clues = []; 
      _leaderboard = [];
      _currentClueIndex = 0;
      
      subscribeToRaceStatus();
    }
    
    final idToUse = eventId ?? _currentEventId;
    
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    
    try {
      if (idToUse == null) return;

      if (userId != null) {
        await fetchLives(userId); 
      }

      final fetchedClues = await _gameService.getClues(idToUse);
      
      _clues = fetchedClues;
      _hintActive = false;
      _activeHintText = null;
      
      final index = _clues.indexWhere((c) => !c.isCompleted && !c.isLocked);
      _currentClueIndex = (index != -1) ? index : _clues.length;
      
    } catch (e) {
      _errorMessage = 'Error fetching clues: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startGame(String eventId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _gameService.startGame(eventId);
      
      // 1. Cargamos pistas y VIDAS
      await fetchClues(eventId: eventId); 
      
      // 2. Activamos juego
      _isGameActive = true; 
      
    } catch (e) {
      debugPrint('Error starting game: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void unlockClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1) {
      _clues[index].isLocked = false;
      _currentClueIndex = index;
      notifyListeners();
    }
  }

  void completeLocalClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1) {
      _clues[index].isCompleted = true;
      _hintActive = false;
      _activeHintText = null;
      notifyListeners();
    }
  }

  void applyHintForCurrentClue() {
    if (currentClue != null) {
      _hintActive = true;
      _activeHintText = currentClue!.hint;
      notifyListeners();
    }
  }

  void clearHint() {
    _hintActive = false;
    _activeHintText = null;
    notifyListeners();
  }

  void setTargetPlayerId(String? id) {
    _targetPlayerId = id;
    notifyListeners();
  }

  void applyTimePenaltyToPlayer(String targetGamePlayerId, {int penalty = 1}) {
    final idx = _leaderboard.indexWhere((p) =>
        p.gamePlayerId == targetGamePlayerId || p.id == targetGamePlayerId);
    if (idx != -1) {
      final updated = _leaderboard[idx];
      final newXp = (updated.totalXP - penalty).clamp(0, totalClues > 0 ? totalClues : updated.totalXP);
      updated.totalXP = newXp;
      notifyListeners();
    }
  }

  Future<bool> completeCurrentClue(String answer, {String? clueId}) async {
    String targetId;

    if (clueId != null) {
      targetId = clueId;
    } else {
      if (_currentClueIndex >= _clues.length) return false;
      targetId = _clues[_currentClueIndex].id;
    }
    
    // --- ACTUALIZACIÓN OPTIMISTA ---
    int localIndex = _clues.indexWhere((c) => c.id == targetId);
    if (localIndex != -1) {
      _clues[localIndex].isCompleted = true;
      if (localIndex + 1 < _clues.length) {
        _currentClueIndex = localIndex + 1; 
      }
      notifyListeners();
    }

    try {
      final data = await _gameService.completeClue(targetId, answer);
      
      if (data != null) { // Success
        if (data['raceCompleted'] == true) {
          _setRaceCompleted(true, 'Clue Completion');
        }
        
        await fetchClues(silent: true); 
        fetchLeaderboard(); 
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error completing clue: $e');
      return false;
    }
  }
  
  Future<void> checkRaceStatus() async {
    if (_currentEventId == null) return;
    
    _isRaceCompleted = false;

    try {
      final isCompleted = await _gameService.checkRaceStatus(_currentEventId!);
      
      if (isCompleted && totalClues > 0) {
          _setRaceCompleted(true, 'Server Health Check');
      } else {
          _setRaceCompleted(false, 'Server Health Check (Falsed or 0 clues)');
      }
    } catch (e) {
      debugPrint('Error checking race status: $e');
    }
  }
  
  Future<bool> skipCurrentClue() async {
    if (_currentClueIndex >= _clues.length) return false;
    
    final clue = _clues[_currentClueIndex];
    _isLoading = true;
    notifyListeners();
    
    try {
      final success = await _gameService.skipClue(clue.id);
      
      if (success) {
        await fetchClues();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error skipping clue: $e');
      return false;
    } finally {
      _isLoading = false;
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
    // Deprecated
  }
  
  @override
  void dispose() {
    stopLeaderboardUpdates();
    super.dispose();
  }
}