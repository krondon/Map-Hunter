import 'package:flutter/material.dart';
import '../../../core/interfaces/i_lives_repository.dart';

/// Provider for player stats management.
/// 
/// Extracted from PlayerProvider to follow SRP.
/// Only handles lives, experience, and player stats.
class PlayerStatsProvider extends ChangeNotifier {
  final ILivesRepository _livesRepository;

  int _lives = 3;
  int _experience = 0;
  int _completedClues = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentEventId;
  String? _currentUserId;

  PlayerStatsProvider({required ILivesRepository livesRepository})
      : _livesRepository = livesRepository;

  // --- Getters ---
  int get lives => _lives;
  int get experience => _experience;
  int get completedClues => _completedClues;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAlive => _lives > 0;
  bool get isGameOver => _lives <= 0;

  // --- State Management ---

  /// Initialize stats for a user in an event.
  Future<void> initialize({
    required String userId,
    required String eventId,
  }) async {
    _currentUserId = userId;
    _currentEventId = eventId;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final lives = await _livesRepository.fetchLives(
        eventId: eventId,
        userId: userId,
      );
      _lives = lives ?? 3;
      debugPrint('[StatsProvider] Initialized with $lives lives');
    } catch (e) {
      _errorMessage = 'Error cargando stats: $e';
      debugPrint('[StatsProvider] Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to real-time lives updates.
  void subscribeToLives() {
    if (_currentUserId == null || _currentEventId == null) return;

    _livesRepository.subscribeToLives(
      eventId: _currentEventId!,
      userId: _currentUserId!,
      onLivesChange: (newLives) {
        if (_lives != newLives) {
          _lives = newLives;
          debugPrint('[StatsProvider] Lives updated via realtime: $newLives');
          notifyListeners();
        }
      },
    );
  }

  /// Lose a life (optimistic update).
  Future<int> loseLife() async {
    if (_currentUserId == null || _currentEventId == null) {
      return _lives;
    }

    if (_lives <= 0) return 0;

    // Optimistic update
    _lives--;
    notifyListeners();

    try {
      final confirmedLives = await _livesRepository.loseLife(
        eventId: _currentEventId!,
        userId: _currentUserId!,
      );
      _lives = confirmedLives;
      notifyListeners();
      return _lives;
    } catch (e) {
      // Rollback
      _lives++;
      notifyListeners();
      debugPrint('[StatsProvider] Error losing life, rolling back: $e');
      return _lives;
    }
  }

  /// Update lives from external source.
  void syncLives(int newLives) {
    if (_lives != newLives) {
      _lives = newLives;
      notifyListeners();
    }
  }

  /// Update experience.
  void addExperience(int xp) {
    _experience += xp;
    notifyListeners();
  }

  /// Increment completed clues.
  void incrementCompletedClues() {
    _completedClues++;
    notifyListeners();
  }

  /// Reset stats to initial values.
  Future<void> resetStats() async {
    if (_currentUserId == null || _currentEventId == null) return;

    try {
      await _livesRepository.resetLives(
        eventId: _currentEventId!,
        userId: _currentUserId!,
      );
      _lives = 3;
      notifyListeners();
    } catch (e) {
      debugPrint('[StatsProvider] Error resetting stats: $e');
    }
  }

  /// Clear state.
  void clear() {
    _livesRepository.unsubscribeAll();
    _lives = 3;
    _experience = 0;
    _completedClues = 0;
    _currentUserId = null;
    _currentEventId = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _livesRepository.dispose();
    super.dispose();
  }
}
