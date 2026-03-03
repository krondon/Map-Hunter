import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clue.dart';
import '../../../shared/models/player.dart';
import '../../../shared/interfaces/i_resettable.dart';
import '../services/game_service.dart';
import '../../admin/models/sponsor.dart';
import '../../admin/services/sponsor_service.dart';
import '../models/power_effect.dart';
import '../../../core/services/leaderboard_debouncer.dart';

// ============================================================
// GATEKEEPER: User Event Status Types
// ============================================================

/// Estados posibles del usuario respecto a un evento.
/// Orden de prioridad de seguridad: banned > inGame > readyToInitialize > waitingApproval > rejected > noEvent
enum UserEventStatus {
  /// Usuario baneado - bloquear acceso
  banned,

  /// Usuario ya está jugando (existe en game_players)
  inGame,

  /// Solicitud aprobada, pendiente de inicializar juego (necesita RPC initialize_game_for_user)
  readyToInitialize,

  /// Solicitud pendiente de aprobación
  waitingApproval,

  /// Solicitud rechazada
  rejected,

  /// Sin evento asociado (puede seleccionar uno)
  noEvent,
}

/// Resultado de la verificación de estado del usuario.
class UserEventStatusResult {
  final UserEventStatus status;
  final String? eventId;
  final String? gamePlayerId;

  const UserEventStatusResult({
    required this.status,
    this.eventId,
    this.gamePlayerId,
  });

  /// Constructor para estado sin evento
  const UserEventStatusResult.noEvent()
      : status = UserEventStatus.noEvent,
        eventId = null,
        gamePlayerId = null;

  /// Constructor para estado baneado
  const UserEventStatusResult.banned()
      : status = UserEventStatus.banned,
        eventId = null,
        gamePlayerId = null;

  bool get isBanned => status == UserEventStatus.banned;
  bool get isInGame => status == UserEventStatus.inGame;
  bool get isReadyToInitialize => status == UserEventStatus.readyToInitialize;
  bool get isWaitingApproval => status == UserEventStatus.waitingApproval;
  bool get isRejected => status == UserEventStatus.rejected;
  bool get hasNoEvent => status == UserEventStatus.noEvent;

  @override
  String toString() =>
      'UserEventStatusResult(status: $status, eventId: $eventId, gamePlayerId: $gamePlayerId)';
}

/// Provider principal que gestiona el estado global del juego.
///
/// Responsabilidades:
/// - Gestión de Pistas (Clues) y progreso del jugador.
/// - Control de Vidas (Lives) y sincronización con el servidor.
/// - Ranking en tiempo real (Leaderboard).
/// - Estado de la carrera (Race Status) para detectar ganadores.
/// - Gestión de efectos visuales globales (Congelamiento, etc.).
class GameProvider extends ChangeNotifier implements IResettable {
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
  bool _isPowerActionLoading =
      false; // Guards against double-clicks during power execution
  bool _isFrozen = false; // Estado de congelamiento para minijuegos
  String? _currentUserId; // Check current user ID for leaderboard fetching

  // Minigame Data from Supabase
  List<Map<String, String>> _minigameCapitals = [];
  List<Map<String, dynamic>> _minigameTFStatements = [];
  bool _isMinigameDataLoading = false;

  // New: Current Sponsor
  Sponsor? _currentSponsor;
  Sponsor? get currentSponsor => _currentSponsor;

  List<PowerEffect> get activePowerEffects => _activePowerEffects;
  bool get isPowerActionLoading => _isPowerActionLoading;
  bool get isFrozen => _isFrozen;

  List<Map<String, String>> get minigameCapitals => _minigameCapitals;
  List<Map<String, dynamic>> get minigameTFStatements => _minigameTFStatements;
  bool get isMinigameDataLoading => _isMinigameDataLoading;

  /// Sets the frozen state (called by PowerEffectProvider)
  void setFrozen(bool value) {
    if (_isFrozen != value) {
      _isFrozen = value;
      notifyListeners();
    }
  }

  /// Sets the power action loading state (called by PowerActionDispatcher)
  void setPowerActionLoading(bool value) {
    _isPowerActionLoading = value;
    notifyListeners();
  }

  void _setRaceCompleted(bool completed, String source) {
    if (_isRaceCompleted != completed) {
      // REMOVED CHECK: if (completed && totalClues <= 0)
      // Reason: If the event is marked completed globally (via Realtime 'events' table),
      // we must respect it even if local clues are not fully loaded (e.g. spectator or late joiner).

      debugPrint('--- RACE STATUS CHANGE: $completed (via $source) ---');
      _isRaceCompleted = completed;
      notifyListeners();
    }
  }

  // Timer y Realtime para el ranking
  Timer? _leaderboardTimer;
  RealtimeChannel? _raceStatusChannel;
  RealtimeChannel? _livesSubscription; // Suscripción a vidas globales

  /// Debouncer para el leaderboard: evita reconstrucciones excesivas cuando
  /// múltiples jugadores completan pistas simultáneamente.
  /// Con 50 jugadores activos, sin esto se dispararían 50+ notifyListeners()/seg.
  final LeaderboardDebouncer _leaderboardDebouncer = LeaderboardDebouncer(
    interval: const Duration(milliseconds: 2000),
    maxWait: const Duration(milliseconds: 5000),
  );

  List<Clue> get clues => _clues;
  List<Player> get leaderboard => _leaderboard;
  Clue? get currentClue =>
      _currentClueIndex < _clues.length ? _clues[_currentClueIndex] : null;

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

  bool get hasCompletedAllClues =>
      totalClues > 0 && completedClues == totalClues;

  GameProvider({required GameService gameService}) : _gameService = gameService;

  /// Limpia COMPLETAMENTE el estado del juego (Global Reset)
  /// Implementación de IResettable
  @override
  void resetState() {
    print('GameProvider: Executing resetState()...');
    _clues = [];
    _leaderboard = [];
    _currentClueIndex = 0;
    _isGameActive = false;
    _isLoading = false;
    _currentEventId = null;
    _errorMessage = null;
    _lives = 0;
    _isRaceCompleted = false;
    _hintActive = false;
    _activeHintText = null;
    _targetPlayerId = null;
    _activePowerEffects = [];
    _isFrozen = false;
    _minigameCapitals = [];
    _minigameTFStatements = [];
    _isMinigameDataLoading = false;
    _currentSponsor = null;
    _currentUserId = null;

    stopLeaderboardUpdates();
    stopLivesSubscription();
    notifyListeners();
  }

  // --- GESTIÓN DE VIDAS ---

  /// Obtiene el número actual de vidas del jugador desde el servidor.
  ///
  /// [userId] Identificador único del usuario (UUID de `profiles`).
  /// Actualiza la variable `_lives` y notifica a los listeners.
  /// Lanza excepción si hay error de red en `GameService`.
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

  // Sync lives manually (e.g. from PlayerProvider purchase)
  void syncLives(int newLives) {
    if (_lives != newLives) {
      _lives = newLives;
      notifyListeners();
    }
  }

  /// Ejecuta la pérdida de una vida (Optimistic UI).
  ///
  /// 1. Reduce la vida localmente de inmediato para feedback instantáneo.
  /// 2. Llama al servicio para persistir el cambio en Supabase.
  /// 3. Si falla, hace rollback (restaura la vida).
  ///
  /// [userId] ID del usuario que pierde la vida.
  /// Retorna el número de vidas restantes confirmadas por el servidor.
  Future<int> loseLife(String userId) async {
    if (_lives <= 0) {
      debugPrint('[LIVES_DEBUG] loseLife aborted: Lives is $_lives');
      return 0; // Already 0
    }
    if (_currentEventId == null) {
      debugPrint('[LIVES_DEBUG] loseLife aborted: currentEventId is null');
      return _lives;
    }

    try {
      debugPrint(
          '[LIVES_DEBUG] loseLife called for userId: $userId, eventId: $_currentEventId');

      // 1. Optimistic Update
      _lives--;
      debugPrint(
          '[LIVES_DEBUG] Optimistic decrement. New local lives: $_lives');
      notifyListeners();

      // 2. Ejecutar servicio
      debugPrint('[LIVES_DEBUG] Calling GameService.loseLife...');
      final remainingLives =
          await _gameService.loseLife(_currentEventId!, userId);
      debugPrint(
          '[LIVES_DEBUG] GameService returned. Server lives: $remainingLives');

      // 3. Sincronizar verdad
      _lives = remainingLives;
      notifyListeners();
      return _lives;
    } catch (e) {
      debugPrint('[LIVES_DEBUG] Error perdiendo vida: $e');
      // Rollback
      // Rollback only if we actually decremented
      if (_lives < 3) {
        // Simple check, or just ++
        _lives++;
      }
      debugPrint('[LIVES_DEBUG] Rollback. Restored lives to: $_lives');
      notifyListeners();
      return _lives;
    }
  }

  // --- GESTIÓN DEL RANKING EN TIEMPO REAL ---

  /// Inicia el polling periódico del Leaderboard (heartbeat de fallback: cada 30 segundos).
  ///
  /// OPTIMIZACIÓN: El intervalo principal de actualización ahora corre por
  /// [subscribeToRaceStatus] + [_leaderboardDebouncer] (event-driven, 2s debounce).
  /// Este timer es solo un "heartbeat" de reconciliación para cubrir casos edge:
  /// - Reconexión tras pérdida de WebSocket
  /// - Eventos que llegaron durante desconexión temporal
  void startLeaderboardUpdates() {
    fetchLeaderboard();
    stopLeaderboardUpdates();

    // 30s en lugar de 5s: Realtime + debounce maneja las actualizaciones reactivas.
    // Este timer solo es fallback de resync.
    _leaderboardTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentEventId != null) {
        _fetchLeaderboardInternal(silent: true);
      }
    });
  }

  /// Detiene las actualizaciones automáticas del leaderboard y el race status.
  /// ⚠️ NO cancela la suscripción de vidas (Single Responsibility Principle)
  void stopLeaderboardUpdates() {
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
    _raceStatusChannel?.unsubscribe();
    _raceStatusChannel = null;
    _leaderboardDebouncer
        .flush(); // Ejecutar cualquier update pendiente antes de parar
  }

  /// Detiene la suscripción Realtime de vidas.
  /// Solo debe llamarse cuando el usuario sale del evento o cierra sesión.
  void stopLivesSubscription() {
    debugPrint('[LIVES_SYNC] 🛑 Stopping lives subscription');
    _livesSubscription?.unsubscribe();
    _livesSubscription = null;
  }

  void subscribeToRaceStatus() {
    if (_currentEventId == null) return;

    _raceStatusChannel?.unsubscribe();

    _raceStatusChannel = _gameService.subscribeToRaceStatus(
        _currentEventId!, totalClues, (completed, source) {
      _setRaceCompleted(completed, source);
    }, onProgressUpdate: () {
      debugPrint(
          '🏎️ RACE UPDATE: Realtime progress detected, scheduling debounced leaderboard refresh...');
      // OPTIMIZACIÓN: Debounce de 2s para evitar 50+ fetches/segundo en ráfagas.
      // Si hay actividad continua, maxWait=5s garantiza que no parezca congelado.
      _leaderboardDebouncer.schedule(() {
        debugPrint(
            '📊 LeaderboardDebouncer: flush → _fetchLeaderboardInternal');
        _fetchLeaderboardInternal(silent: true);
      });
    });
  }

  /// Suscribe a cambios en las vidas del jugador en tiempo real.
  /// Cuando la tabla game_players actualice el campo 'lives', el Provider
  /// se actualizará automáticamente sin necesidad de fetch manual.
  ///
  /// ⚡ BYPASS DE FILTRO: Recibe TODOS los updates de game_players para el evento
  /// y filtra manualmente en el callback para evitar discrepancias de tipos de ID.
  void subscribeToLives(String userId, String eventId) {
    if (userId.isEmpty || eventId.isEmpty) {
      debugPrint('[LIVES_SYNC] ❌ Cannot subscribe: userId or eventId is empty');
      return;
    }

    // Cancelar suscripción previa si existe
    _livesSubscription?.unsubscribe();

    // Normalizar IDs para comparación robusta (trim + lowercase)
    final String normalizedUserId = userId.toString().trim();
    final String normalizedEventId = eventId.toString().trim();

    debugPrint('[LIVES_SYNC] 🔧 Subscribing to Realtime updates');
    debugPrint('[LIVES_SYNC]   User ID: $normalizedUserId');
    debugPrint('[LIVES_SYNC]   Event ID: $normalizedEventId');
    debugPrint('[LIVES_SYNC]   Current lives: $_lives');
    debugPrint(
        '[LIVES_SYNC]   Channel: lives:$normalizedUserId:$normalizedEventId');

    _livesSubscription = Supabase.instance.client
        .channel('lives:$normalizedUserId:$normalizedEventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_players',
          // ✅ FILTRO SERVER-SIDE: Requiere REPLICA IDENTITY FULL en game_players
          // (aplicado en migración 20260303100000_realtime_performance_optimizations.sql).
          // Con 50 jugadores, esto reduce de 50×enviados/todos a 1×solo-el-mío.
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: normalizedUserId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final timestamp = DateTime.now().toIso8601String();

            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            debugPrint('[LIVES_SYNC] 🔥 REALTIME EVENT RECEIVED @ $timestamp');

            // Con filtro server-side, el event_id aún requiere validación
            // porque la columna user_id no garantiza pertenecer a este evento.
            final incomingEventIdRaw = record['event_id'];
            final incomingLivesRaw = record['lives'];

            final String incomingEventId =
                incomingEventIdRaw?.toString().trim() ?? '';
            final bool eventMatches = incomingEventId == normalizedEventId;

            if (eventMatches) {
              final int newLives = incomingLivesRaw as int;
              debugPrint(
                  '[LIVES_SYNC] ✅ Match - Updating lives: $_lives → $newLives');

              if (_lives != newLives) {
                _lives = newLives;
                notifyListeners();
                debugPrint('[LIVES_SYNC] 🔔 notifyListeners() called');
              } else {
                debugPrint(
                    '[LIVES_SYNC] ⚠️ Value unchanged ($newLives), skipping');
              }
            } else {
              debugPrint('[LIVES_SYNC] ⚠️ Event ID mismatch - filtered out');
            }

            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          },
        )
        .subscribe();

    debugPrint('[LIVES_SYNC] ✅ Subscription activated');
  }

  Future<void> fetchLeaderboard({bool silent = false}) async {
    await _fetchLeaderboardInternal(silent: silent);
  }

  Future<void> _fetchLeaderboardInternal({bool silent = false}) async {
    if (_currentEventId == null) {
      debugPrint(
          "⚠️ GameProvider: _fetchLeaderboardInternal aborted. _currentEventId is null.");
      return;
    }
    debugPrint(
        "📊 GameProvider: Fetching leaderboard for event $_currentEventId");

    try {
      final data = await _gameService.getLeaderboard(_currentEventId!,
          currentUserId: _currentUserId);
      _leaderboard = data;

      // Fetch active powers in parallel or sequence
      _activePowerEffects =
          await _gameService.getActivePowers(_currentEventId!);

      // FIX: Removed legacy client-side race completion logic.
      // The server (via 'events' table status) is the only source of truth for race completion.
      // This checking was causing premature "Race Completed" state even if more winners were needed.

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
    }
  }

  // --- FIN GESTIÓN RANKING ---

  Future<void> fetchClues(
      {String? eventId, bool silent = false, String? userId}) async {
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
      _currentSponsor = null; // Reset sponsor
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
        _currentUserId = userId;
        debugPrint('═══════════════════════════════════════════');
        debugPrint('[FETCH_CLUES] 🚀 Fetching lives for user: $userId');
        await fetchLives(userId);
        // ⚡ CRÍTICO: Suscribirse SIEMPRE que haya userId, no solo cuando cambia el evento
        debugPrint('[FETCH_CLUES] 🔧 About to activate Realtime subscription');
        debugPrint('[FETCH_CLUES]    userId: $userId');
        debugPrint('[FETCH_CLUES]    eventId: $idToUse');
        subscribeToLives(userId, idToUse);
        debugPrint('[FETCH_CLUES] ✅ subscribeToLives() call completed');
        debugPrint('═══════════════════════════════════════════');
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
      // ⚡ CRÍTICO: Suscribirse o actualizar suscripción una vez que totalClues es real
      subscribeToRaceStatus();

      // Fetch Sponsor if not loaded (and eventId is valid)
      if (idToUse != null && _currentSponsor == null) {
        try {
          // We use a small service instance here or inject usage
          final sponsorService = SponsorService();
          final sponsor = await sponsorService.getSponsorForEvent(idToUse);
          if (sponsor != null) {
            _currentSponsor = sponsor;
            debugPrint(
                '✅ GameProvider: Loaded Sponsor: ${sponsor.name} (${sponsor.planType})');
          } else {
            _currentSponsor =
                await sponsorService.getActiveSponsor(); // Fallback
            if (_currentSponsor != null) {
              debugPrint(
                  '✅ GameProvider: Loaded Global Sponsor (Fallback): ${_currentSponsor!.name}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching sponsor in GameProvider: $e');
        }
      }

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
      final newXp = (updated.totalXP - penalty)
          .clamp(0, totalClues > 0 ? totalClues : updated.totalXP);
      updated.totalXP = newXp;
      notifyListeners();
    }
  }

  // PREMIO GANADO (Si aplica)
  int? _currentPrizeWon;
  int? get currentPrizeWon => _currentPrizeWon;

  /// Completa una pista y retorna los datos del servidor incluyendo coins_earned.
  /// Retorna null si falla, o un Map con success, raceCompleted, coins_earned.
  Future<Map<String, dynamic>?> completeCurrentClue(String answer,
      {String? clueId}) async {
    String targetId;

    if (clueId != null) {
      targetId = clueId;
    } else {
      if (_currentClueIndex >= _clues.length) return null;
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
      final data = await _gameService.completeClue(targetId, answer,
          eventId: _currentEventId);

      if (data != null) {
        // Success
        // Success
        // CRITICAL FIX: Only treat as Globally Completed if backend says so (raceCompletedGlobal)
        // 'raceCompleted' in previous logic might have meant "User Finished".
        // We rely on 'raceCompletedGlobal' which comes from the RPC.
        if (data['raceCompletedGlobal'] == true) {
          debugPrint("🏆 GLOBAL Race Completed confirmed by RPC!");
          _setRaceCompleted(true, 'Clue Completion (RPC)');
        } else {
          debugPrint(
              "👤 User finished clues, but Race is NOT globally finished yet.");
          // Ensure we DO NOT set _isRaceCompleted = true here.
          // The user should go to Waiting Room.
        }

        // [PERFORMANCE] Fire-and-forget: El RPC ya hizo todo atómicamente y
        // la actualización optimista ya refrescó el UI. Este fetch es solo
        // para confirmar estado desde el servidor, no debe bloquear.
        unawaited(fetchClues(silent: true));
        unawaited(fetchLeaderboard());
        return data;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error completing clue: $e');
      // En caso de error de red, aún retornamos éxito local
      // ya que la actualización optimista ya se hizo
      return {'success': true, 'coins_earned': 0, 'error': e.toString()};
    }
  }

  Future<void> checkRaceStatus() async {
    if (_currentEventId == null) return;

    // _isRaceCompleted = false; // REMOVED: Do not reset blindly, let the server response decide.

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

  // ============================================================
  // GATEKEEPER: User Event Status Methods
  // ============================================================

  /// Verifica el estado del usuario respecto a eventos.
  /// Sigue una jerarquía estricta de seguridad:
  ///
  /// Paso 0 (Seguridad): Verificar si está baneado
  /// Paso 1 (Activo): Verificar si ya es game_player
  /// Paso 2 (Solicitud): Verificar estado de game_requests
  Future<UserEventStatusResult> checkUserEventStatus(String userId) async {
    debugPrint('GameProvider: Checking user event status for $userId');

    try {
      // PASO 0: Verificar si el usuario está baneado
      final isBanned = await _gameService.checkBannedStatus(userId);
      if (isBanned) {
        debugPrint('GameProvider: User is BANNED');
        return const UserEventStatusResult.banned();
      }

      // PASO 1: Verificar si ya es un game_player activo
      final gamePlayer = await _gameService.getActiveGamePlayer(userId);
      if (gamePlayer != null) {
        final String eventId = gamePlayer['event_id'];
        final String gamePlayerId = gamePlayer['id'];
        debugPrint('GameProvider: User is IN_GAME for event $eventId');
        return UserEventStatusResult(
          status: UserEventStatus.inGame,
          eventId: eventId,
          gamePlayerId: gamePlayerId,
        );
      }

      // PASO 2: Verificar solicitudes de juego
      final gameRequest = await _gameService.getLatestGameRequest(userId);
      if (gameRequest != null) {
        final String status = gameRequest['status'] ?? '';
        final String eventId = gameRequest['event_id'];

        switch (status) {
          case 'approved':
            debugPrint(
                'GameProvider: User has APPROVED request for event $eventId');
            return UserEventStatusResult(
              status: UserEventStatus.readyToInitialize,
              eventId: eventId,
            );
          case 'pending':
            debugPrint(
                'GameProvider: User has PENDING request for event $eventId');
            return UserEventStatusResult(
              status: UserEventStatus.waitingApproval,
              eventId: eventId,
            );
          case 'rejected':
            debugPrint(
                'GameProvider: User has REJECTED request for event $eventId');
            return UserEventStatusResult(
              status: UserEventStatus.rejected,
              eventId: eventId,
            );
        }
      }

      // PASO 3: Sin evento asociado
      debugPrint('GameProvider: User has NO_EVENT');
      return const UserEventStatusResult.noEvent();
    } catch (e) {
      debugPrint('GameProvider: Error checking user event status: $e');
      // En caso de error, devolvemos noEvent para permitir el flujo normal
      return const UserEventStatusResult.noEvent();
    }
  }

  /// Inicializa el juego para un usuario con solicitud aprobada.
  /// Llama al RPC initialize_game_for_user y espera el resultado.
  Future<bool> initializeGameForApprovedUser(
      String userId, String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _gameService.initializeGameForUser(userId, eventId);
      if (success) {
        await fetchClues(eventId: eventId, userId: userId);
        debugPrint('GameProvider: Game initialized successfully');
      }
      return success;
    } catch (e) {
      debugPrint('GameProvider: Error initializing game: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper para obtener el estado de un jugador (útil para diferenciar spectadores de invisibles)
  Future<String?> getPlayerStatus(String gamePlayerId) async {
    return await _gameService.getGamePlayerStatus(gamePlayerId);
  }

  /// Helper para obtener el nombre real de un jugador (incluso si está invisible)
  Future<String?> getPlayerName(String gamePlayerId) async {
    return await _gameService.getPlayerName(gamePlayerId);
  }

  /// Carga los datos de los minijuegos desde Supabase si no han sido cargados.
  Future<void> loadMinigameData() async {
    if (_minigameCapitals.isNotEmpty && _minigameTFStatements.isNotEmpty)
      return;

    _isMinigameDataLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _gameService.fetchMinigameCapitals(),
        _gameService.fetchMinigameTrueFalse(),
      ]);

      _minigameCapitals = results[0] as List<Map<String, String>>;
      final tfRaw = results[1] as List<Map<String, dynamic>>;
      _minigameTFStatements = tfRaw;

      debugPrint(
          'GameProvider: Loaded ${_minigameCapitals.length} capitals and ${_minigameTFStatements.length} TF statements.');
    } catch (e) {
      debugPrint('GameProvider: Error loading minigame data: $e');
    } finally {
      _isMinigameDataLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopLeaderboardUpdates();
    stopLivesSubscription();
    _leaderboardDebouncer.dispose();
    super.dispose();
  }
}
