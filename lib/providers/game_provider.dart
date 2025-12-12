import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clue.dart';
import '../models/player.dart';

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
      final Map<String, dynamic> queryParams = {};
      if (idToUse != null) queryParams['eventId'] = idToUse;

      final response = await _supabase.functions.invoke(
        'game-data', // Changed from game-api/clues
        method: HttpMethod.get,
        queryParameters: queryParams,
      );
      
      if (response.status == 200) {
        final List<dynamic> data = response.data;
        _clues = data.map((json) => Clue.fromJson(json)).toList();
        
        // Debug logs to verify clue status
        for (var c in _clues) {
          debugPrint('Clue ${c.title} (ID: ${c.id}): locked=${c.isLocked}, completed=${c.isCompleted}');
        }
        
        // Find first unlocked but not completed clue to set as current
        final index = _clues.indexWhere((c) => !c.isCompleted && !c.isLocked);
        if (index != -1) {
          _currentClueIndex = index;
        } else {
          _currentClueIndex = 0;
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
  
  Future<bool> completeCurrentClue(String answer) async {
    if (_currentClueIndex >= _clues.length) return false;
    
    final clue = _clues[_currentClueIndex];
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _supabase.functions.invoke('game-play/complete-clue', 
        body: {
          'clueId': clue.id,
          'answer': answer,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        // Refresh clues to get updated status and next unlock
        // We need to know the current event ID to refresh correctly, 
        // but fetchClues without ID might work if we assume user only plays one at a time
        // or we store currentEventId in provider.
        // For now, let's assume fetchClues handles it or we pass null (fetching all active clues?)
        // Actually, fetchClues needs eventId to filter. 
        // Let's assume we can get it from the current clue.
        // But Clue model doesn't have eventId exposed in Dart yet (it's in DB).
        // Let's add eventId to Clue model or just refresh all.
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
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('total_xp', ascending: false)
          .limit(20);
          
      _leaderboard = (data as List).map((json) => Player.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
  }
  
  void updateLeaderboard(Player player) {
    // Deprecated
  }
}
