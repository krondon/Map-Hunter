import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clue.dart';
import '../../../shared/models/player.dart';

class GameProvider extends ChangeNotifier {
  List<Clue> _clues = [];
  List<Player> _leaderboard = [];
  int _currentClueIndex = 0;
  bool _isGameActive = false;
  bool _isLoading = false;
  String? _currentEventId;
  String? _errorMessage;
  
  final _supabase = Supabase.instance.client;
  
  List<Clue> get clues => _clues;
  List<Player> get leaderboard => _leaderboard;
  Clue? get currentClue => _currentClueIndex < _clues.length ? _clues[_currentClueIndex] : null;
  
  // Getter que faltaba para el Mini Mapa
  int get currentClueIndex => _currentClueIndex;
  
  bool get isGameActive => _isGameActive;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get completedClues => _clues.where((c) => c.isCompleted).length;
  int get totalClues => _clues.length;
  String? get currentEventId => _currentEventId;
  
  GameProvider() {
    // _initializeMockData(); // Removed mock data
  }
  
  Future<void> fetchClues({String? eventId}) async {
    if (eventId != null) {
      _currentEventId = eventId;
    }
    
    final idToUse = eventId ?? _currentEventId;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      if (idToUse == null) {
         debugPrint('Warning: fetchClues called without eventId');
         _isLoading = false;
         notifyListeners();
         return;
      }

      final response = await _supabase.functions.invoke(
        'game-play/get-clues', 
        body: {'eventId': idToUse},
        method: HttpMethod.post,
      );
      
      if (response.status == 200) {
        final List<dynamic> data = response.data;
        _clues = data.map((json) => Clue.fromJson(json)).toList();
        
        // Debug logs to verify clue status
        for (var c in _clues) {
          debugPrint('Clue ${c.title} (ID: ${c.id}): locked=${c.isLocked}, completed=${c.isCompleted}');
        }
        
        // Determine current index based on the returned status from Edge Function
        // The Edge Function ensures linear progression based on completed count
        final index = _clues.indexWhere((c) => !c.isCompleted);
        if (index != -1) {
          _currentClueIndex = index;
        } else {
          // If all are completed, set index to length (end of list)
          _currentClueIndex = _clues.length;
        }
      } else {
        _errorMessage = 'Error fetching clues: ${response.status}';
        debugPrint('Error fetching clues: ${response.status} ${response.data}');
      }
    } catch (e) {
      _errorMessage = 'Error fetching clues: $e';
      debugPrint('Error fetching clues: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> startGame(String eventId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/start-game', 
        body: {'eventId': eventId},
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        _isGameActive = true;
        await fetchClues(eventId: eventId);
      } else {
        debugPrint('Error starting game: ${response.status} ${response.data}');
      }
    } catch (e) {
      debugPrint('Error starting game: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void completeLocalClue(String clueId) {
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index != -1) {
      _clues[index].isCompleted = true;
      
      // Unlock next clue if available
      if (index + 1 < _clues.length) {
        _clues[index + 1].isLocked = false;
      }
      notifyListeners();
    }
  }

  Future<bool> completeCurrentClue(String answer, {String? clueId}) async {
    
    String targetId;

    // Lógica para determinar qué ID usar
    if (clueId != null) {
      targetId = clueId;
    } else {
      // Si no nos pasan ID, usamos el índice interno (comportamiento original)
      if (_currentClueIndex >= _clues.length) return false;
      targetId = _clues[_currentClueIndex].id;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/complete-clue', 
        body: {
          'clueId': targetId, // <--- Usamos el ID correcto
          'answer': answer,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        await fetchClues(); 
        return true;
      } else {
        debugPrint('Error completing clue: ${response.status} ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('Error completing clue: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> skipCurrentClue() async {
    if (_currentClueIndex >= _clues.length) return false;
    
    final clue = _clues[_currentClueIndex];
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/skip-clue', 
        body: {
          'clueId': clue.id,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        await fetchClues();
        return true;
      } else {
        debugPrint('Error skipping clue: ${response.status} ${response.data}');
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
  
  Future<void> fetchLeaderboard() async {
    // Necesitamos un evento activo para filtrar
    if (_currentEventId == null) return;

    try {
      final response = await _supabase.functions.invoke(
        'game-play/get-leaderboard',
        body: {'eventId': _currentEventId},
        method: HttpMethod.post,
      );

      if (response.status == 200) {
        final List<dynamic> data = response.data;
        _leaderboard = data.map((json) => Player.fromJson(json)).toList();
        notifyListeners();
      } else {
        debugPrint('Error fetching leaderboard: ${response.status} ${response.data}');
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
  }
  
  void updateLeaderboard(Player player) {
    // Deprecated
  }
}
