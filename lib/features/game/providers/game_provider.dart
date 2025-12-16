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
  
  GameProvider() {
    // Constructor
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
  
  Future<void> fetchClues({String? eventId, bool silent = false}) async {
    if (eventId != null) {
      _currentEventId = eventId;
    }
    
    final idToUse = eventId ?? _currentEventId;
    
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    
    try {
      if (idToUse == null) {
         debugPrint('Warning: fetchClues called without eventId');
         if (!silent) {
           _isLoading = false;
           notifyListeners();
         }
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
        
        // --- INYECCIÓN DE CAMPAÑA DEMO (TODOS LOS MINIJUEGOS) ---
        // FORZAR MODO DEMO: Ignoramos lo que venga del backend para mostrar todos los juegos creados.
        if (true) {
           _clues.clear(); // Limpiamos para evitar duplicados o datos parciales del backend
           int level = 1;

           // PISTA 1: Objeto Oculto (Requires QR Scan to start)
           _clues.add(Clue(
             id: 'demo_level_${level++}', 
             title: 'Nivel 1: El Comienzo',
             description: 'Escanea el QR para iniciar tu misión.',
             hint: 'Busca el código en la entrada.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.findDifference, 
             riddleQuestion: 'Encuentra el objeto perdido',
             xpReward: 100,
             coinReward: 50,
             isLocked: false, // DESBLOQUEADA VISUALMENTE (Requiere QR interna)
             isCompleted: false,
           ));

           // PISTA 2: Buscaminas
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 2: Campo Minado',
             description: 'Cuidado donde pisas.',
             hint: 'Usa las banderas.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.minesweeper, 
             riddleQuestion: 'Despeja el campo',
             xpReward: 120,
             coinReward: 60,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 3: Serpiente
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 3: Serpiente Glotona',
             description: 'Alimenta a la bestia.',
             hint: 'No choques con las paredes.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.snake, 
             riddleQuestion: 'Come 15 manzanas',
             xpReward: 140,
             coinReward: 70,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 4: Puzzle Deslizante
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 4: Rompecabezas',
             description: 'Ordena la imagen.',
             hint: 'Mueve las piezas al espacio vacío.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.slidingPuzzle, 
             riddleQuestion: 'Completa la imagen',
             xpReward: 160,
             coinReward: 80,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 5: La Vieja (Tic Tac Toe)
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 5: La Vieja',
             description: 'Gana a la IA.',
             hint: 'Haz una línea de 3.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.ticTacToe, 
             riddleQuestion: 'Gana la partida',
             xpReward: 180,
             coinReward: 90,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 6: Ahorcado
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 6: El Ahorcado',
             description: 'Adivina la palabra secreta.',
             hint: 'Cuidado con tus vidas.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.hangman, 
             riddleQuestion: 'Descubre la palabra',
             xpReward: 200,
             coinReward: 100,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 7: Rellenar Bloques
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 7: Laberinto de Color',
             description: 'Pinta todo el camino sin repetir.',
             hint: 'Planifica tu ruta.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.blockFill, 
             riddleQuestion: 'Llena todos los bloques',
             xpReward: 220,
             coinReward: 110,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 8: Banderas
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel 8: Banderas del Mundo',
             description: 'Viaja sin moverte.',
             hint: 'Conoce tu geografía.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.flags, 
             riddleQuestion: 'Identifica el país',
             xpReward: 240,
             coinReward: 120,
             isLocked: true, 
             isCompleted: false,
           ));

           // PISTA 9: Tetris (Final Boss)
           _clues.add(Clue(
             id: 'demo_level_${level++}',
             title: 'Nivel Final: Tetris',
             description: 'La prueba definitiva de agilidad.',
             hint: 'Completa líneas.',
             type: ClueType.minigame,
             puzzleType: PuzzleType.tetris, 
             riddleQuestion: 'Sobrevive y gana puntos',
             xpReward: 500,
             coinReward: 250,
             isLocked: true, 
             isCompleted: false,
           ));
        }

        // --- LÓGICA DE PROGRESIÓN ESTRICTA ---
        // 1. Encontrar la primera pista NO completada.
        int firstIncomplete = _clues.indexWhere((c) => !c.isCompleted);
        
        if (firstIncomplete == -1) {
           // Si todas están completas (Juego terminado), nos quedamos en la última
           _currentClueIndex = _clues.length - 1;
        } else {
           _currentClueIndex = firstIncomplete;
           
           // ASEGURAR ESTRUCTURA "CANDADO":
           // La pista actual (_currentClueIndex) es la única "Activa".
           // Si está locked, el usuario debe escanear QR.
           // Si está unlocked, el usuario puede jugar.
           // Todas las pistas FUTURAS deben star locked.
           // Todas las pistas PASADAS están completed (y visualmente unlocked/check).
           
           for (int i = 0; i < _clues.length; i++) {
              if (i > firstIncomplete) {
                  _clues[i].isLocked = true; // Futuro bloqueado
              }
           }
           // La pista actual (firstIncomplete) mantiene su estado de 'isLocked'.
           // Si queremos obligar a scannear QR para la PRIMERA, la dejamos en true.
           // Si ya scanneó, estará en false.
        }
      } else {
        _errorMessage = 'Error fetching clues: ${response.status}';
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
    if (clueId == 'demo_flags_01') {
      final index = _clues.indexWhere((c) => c.id == clueId);
      if (index != -1) {
        _clues[index].isLocked = false;
        _clues[index].isCompleted = false; // FORCE UNCOMPLETE
        _currentClueIndex = index;
        notifyListeners();
        return;
      }
    }

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
  
  void resetGame() {
    _clues.clear();
    _currentClueIndex = 0;
    fetchClues(silent: false); // Reloads demo data fresh
  }
  
  @override
  void dispose() {
    stopLeaderboardUpdates();
    super.dispose();
  }
}