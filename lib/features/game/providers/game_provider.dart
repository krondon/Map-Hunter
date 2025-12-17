import 'dart:async'; // Necesario para el Timer
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
  int _lives = 3;
  
  // Timer para el ranking en tiempo real
  Timer? _leaderboardTimer;
  
  final _supabase = Supabase.instance.client;
  
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
  
  GameProvider() {
    // Constructor
  }

  // --- GESTIÓN DE VIDAS ---

  Future<void> fetchLives(String userId) async {
    if (_currentEventId == null) return;
    try {
      final response = await _supabase
          .from('game_players')
          .select('lives')
          .eq('event_id', _currentEventId!)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        _lives = response['lives'];
        notifyListeners();
      } else {
        // Si no existe registro, asumimos 3 (o creamos el registro si es necesario al unirse)
        _lives = 3;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching lives: $e');
    }
  }
  
Future<void> loseLife(String userId) async {
  // Nota: _lives es tu variable local para actualización optimista
  if (_lives <= 0) return;
  
  // Validamos que exista un evento activo para restar vidas de ESE evento
  if (_currentEventId == null) return;
  
  try {
    // 1. Optimistic Update (Feedback instantáneo visual)
    _lives--;
    notifyListeners();
    
    // 2. Ejecutar en Supabase
    // Usamos la función que acabamos de mejorar en SQL
    final response = await _supabase.rpc('lose_life', params: {
      'p_user_id': userId,
      'p_event_id': _currentEventId,
    });
    
    // 3. Sincronizar verdad (Response trae las vidas reales restantes)
    if (response != null) {
      _lives = response as int;
    }
    notifyListeners();

  } catch (e) {
    debugPrint('Error perdiendo vida: $e');
    // Rollback visual si falló la conexión
    _lives++; 
    notifyListeners();
  }
}
  // --- GESTIÓN DEL RANKING EN TIEMPO REAL ---

  /// Inicia la actualización automática del ranking cada 20 segundos
  void startLeaderboardUpdates() {
    // 1. Carga inicial inmediata
    fetchLeaderboard();
    
    // 2. Limpiar timer anterior si existe
    stopLeaderboardUpdates();
    
    // 3. Configurar nuevo timer
    _leaderboardTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_currentEventId != null) {
        // fetchLeaderboard silent=true para no mostrar loading spinners
        _fetchLeaderboardInternal(silent: true);
      }
    });
  }

  /// Detiene la actualización automática (llamar en dispose)
  void stopLeaderboardUpdates() {
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
  }

  /// Método público para cargar ranking (puede mostrar loading)
  Future<void> fetchLeaderboard() async {
    await _fetchLeaderboardInternal(silent: false);
  }

  /// Lógica interna de carga del ranking
  Future<void> _fetchLeaderboardInternal({bool silent = false}) async {
    // Necesitamos un evento activo para filtrar
    if (_currentEventId == null) return;

    try {
      // Consultamos directamente la VISTA SQL creada
      // Esto es mucho más rápido y eficiente que una Edge Function para polling
      final List<dynamic> data = await _supabase
          .from('event_leaderboard')
          .select()
          .eq('event_id', _currentEventId!) // Asumiendo que la vista tiene event_id si filtramos por evento
          .order('completed_clues', ascending: false) // Más pistas primero
          .order('last_completion_time', ascending: true) // Desempate: quien terminó antes
          .limit(50);

      _leaderboard = data.map((json) {
        // TRUCO: Para no romper el modelo Player ni modificar otros archivos,
        // inyectamos el conteo de pistas ('completed_clues') en el campo 'total_xp'.
        // Así la UI mostrará el número de pistas usando el campo existente.
        if (json['completed_clues'] != null) {
          json['total_xp'] = json['completed_clues'];
        }
        return Player.fromJson(json);
      }).toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      // Intentamos fallback a la Edge Function si la vista falla o no existe
      if (!silent) _fetchLeaderboardFallback();
    }
  }

  // Fallback a la lógica antigua por si acaso
  Future<void> _fetchLeaderboardFallback() async {
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
      }
    } catch (e) {
      debugPrint('Error fallback leaderboard: $e');
    }
  }

  // --- FIN GESTIÓN RANKING ---
  
  Future<void> fetchClues({String? eventId, bool silent = false, String? userId}) async {
    // Si el evento es nuevo, reseteamos las vidas localmente para no mostrar las del evento anterior
    if (eventId != null && eventId != _currentEventId) {
      _currentEventId = eventId;
      _lives = 3; // Valor por defecto temporal mientras carga el real
    }
    
    final idToUse = eventId ?? _currentEventId;
    
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    
    try {
      if (idToUse == null) return;

      // --- NUEVO: Sincronizar vidas inmediatamente si tenemos el userId ---
      if (userId != null) {
        await fetchLives(userId); 
      }

      final response = await _supabase.functions.invoke(
        'game-play/get-clues', 
        body: {'eventId': idToUse},
        method: HttpMethod.post,
      );
      
      if (response.status == 200) {
        final List<dynamic> data = response.data;
        _clues = data.map((json) => Clue.fromJson(json)).toList();
        
        final index = _clues.indexWhere((c) => !c.isCompleted && !c.isLocked);
        _currentClueIndex = (index != -1) ? index : _clues.length;
      }
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
      final response = await _supabase.functions.invoke('game-play/complete-clue', 
        body: {
          'clueId': targetId, 
          'answer': answer,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        await fetchClues(silent: true); 
        // También actualizamos el ranking si completó una pista
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