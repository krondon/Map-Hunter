import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/player.dart';
import '../../game/providers/power_effect_provider.dart';
import '../../game/providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/power_service.dart';
import '../../admin/services/admin_service.dart';

enum PowerUseResult { success, reflected, error }

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final SupabaseClient _supabase;
  
  // Services (DIP)
  final AuthService _authService;
  final AdminService _adminService;
  final InventoryService _inventoryService;
  final PowerService _powerService;

  // Mapa para guardar el inventario filtrado por evento
  // Estructura: { eventId: { powerId: quantity } }
  final Map<String, Map<String, int>> _eventInventories = {};

  bool _isProcessing = false;
  bool _isLoggingOut = false;
  bool _isDisposed = false; // Flag para evitar notifyListeners tras dispose
  StreamSubscription? _gamePlayersSubscription; // Nueva suscripción por stream para baneos de competencia

  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;
  bool get isLoggedIn => _currentPlayer != null;

  String? _banMessage;
  String? get banMessage => _banMessage;

  /// Constructor con inyección de dependencias.
  PlayerProvider({
    required SupabaseClient supabaseClient,
    required AuthService authService,
    required AdminService adminService,
    required InventoryService inventoryService,
    required PowerService powerService,
  })  : _supabase = supabaseClient,
        _authService = authService,
        _adminService = adminService,
        _inventoryService = inventoryService,
        _powerService = powerService;
  
  void clearBanMessage() {
    _banMessage = null;
    notifyListeners();
  }

  // --- NUEVO: Obtener cantidad de un poder específico en un evento ---
  int getPowerCount(String itemId, String eventId) {
    return _eventInventories[eventId]?[itemId] ?? 0;
  }
  
  // --- SYNC MANUAL: Validar estado local sin fetch ---
  void updateLocalLives(int newLives) {
    if (_currentPlayer != null) {
      _currentPlayer = _currentPlayer!.copyWith(lives: newLives);
      notifyListeners();
    }
  }

  // --- AUTHENTICATION ---

  // --- AUTHENTICATION (delegado a AuthService) ---

  Future<void> login(String email, String password) async {
    try {
      final userId = await _authService.login(email, password);
      await _fetchProfile(userId);
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final userId = await _authService.register(name, email, password);
      await _fetchProfile(userId);
    } catch (e) {
      debugPrint('Error registering: $e');
      rethrow;
    }
  }

  Future<void> logout({bool clearBanMessage = true}) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    _pollingTimer?.cancel();
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    
    await _gamePlayersSubscription?.cancel();
    _gamePlayersSubscription = null;

    await _authService.logout();
    _currentPlayer = null;
    
    if (clearBanMessage) {
      _banMessage = null;
    }
    
    notifyListeners();
    _isLoggingOut = false;
  }

  Future<void> _checkPendingPenalties(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pending_life_loss') == true) {
        final eventId = prefs.getString('pending_life_loss_event');
        debugPrint('PlayerProvider: Procesando penalización pendiente para $userId');
        
        await loseLife(eventId: eventId);
        
        // Limpiar para no cobrar doble
        await prefs.remove('pending_life_loss');
        await prefs.remove('pending_life_loss_event');
        debugPrint('PlayerProvider: Penalización pendiente aplicada con éxito');
      }
    } catch (e) {
      debugPrint('Error consumiendo penalización: $e');
    }
  }

  // --- PROFILE MANAGEMENT ---

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  /// Obtiene el inventario del usuario para un evento (delegado a InventoryService).
  Future<void> fetchInventory(String userId, String eventId) async {
    try {
      final result = await _inventoryService.fetchInventoryByEvent(
        userId: userId,
        eventId: eventId,
      );

      // Guardamos la relación cantidad/item para validaciones de la tienda
      _eventInventories[eventId] = result.eventItems;

      // Actualizamos el inventario del jugador actual
      if (_currentPlayer != null) {
        _currentPlayer!.inventory = result.inventoryList;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching event inventory: $e');
    }
  }

  // --- LÓGICA DE TIENDA (delegada a InventoryService) ---

  Future<bool> purchaseItem(String itemId, String eventId, int cost,
      {bool isPower = true}) async {
    if (_currentPlayer == null) return false;

    // MANEJO ESPECIAL PARA VIDAS
    if (itemId == 'extra_life') {
      return _purchaseLifeManual(eventId, cost);
    }

    try {
      final result = await _inventoryService.purchaseItem(
        userId: _currentPlayer!.userId,
        eventId: eventId,
        itemId: itemId,
        cost: cost,
        isPower: isPower,
      );

      if (result.success) {
        _currentPlayer!.coins -= cost;
        await fetchInventory(_currentPlayer!.userId, eventId);
        notifyListeners();
      }
      return result.success;
    } catch (e) {
      debugPrint("Error en compra: $e");
      rethrow;
    }
  }

  Future<bool> _purchaseLifeManual(String eventId, int cost) async {
    if ((_currentPlayer?.coins ?? 0) < cost) {
      return false;
    }

    final result = await _inventoryService.purchaseExtraLife(
      userId: _currentPlayer!.userId,
      eventId: eventId,
      cost: cost,
    );

    if (result.success) {
      _currentPlayer!.coins -= cost;
      if (result.newLives != null) {
        _currentPlayer!.lives = result.newLives!;
      }
      notifyListeners();
    }
    return result.success;
  }

// --- LÓGICA DE USO DE PODERES (delegada a PowerService) ---

  Future<PowerUseResult> usePower({
    required String powerSlug,
    required String targetGamePlayerId,
    required PowerEffectProvider effectProvider,
    GameProvider? gameProvider,
    bool allowReturnForward = true,
  }) async {
    if (_currentPlayer == null) return PowerUseResult.error;
    if (_isProcessing) return PowerUseResult.error;
    _isProcessing = true;

    final casterGamePlayerId = _currentPlayer!.gamePlayerId;
    if (casterGamePlayerId == null || casterGamePlayerId.isEmpty) {
      _isProcessing = false;
      return PowerUseResult.error;
    }

    try {
      // Configurar estado de lanzamiento manual
      effectProvider.setManualCasting(true);

      // Preparar lista de rivales para blur_screen
      List<RivalInfo>? rivals;
      String? eventId;
      if (powerSlug == 'blur_screen' && gameProvider != null) {
        eventId = gameProvider.currentEventId;
        if (eventId != null && gameProvider.leaderboard.isEmpty) {
          try {
            await gameProvider.fetchLeaderboard();
          } catch (_) {}
        }
        rivals = gameProvider.leaderboard
            .where((p) => p.gamePlayerId != null && p.gamePlayerId!.isNotEmpty)
            .map((p) => RivalInfo(p.gamePlayerId!))
            .toList();
      }

      // Ejecutar poder a través del servicio
      final response = await _powerService.executePower(
        casterGamePlayerId: casterGamePlayerId,
        targetGamePlayerId: targetGamePlayerId,
        powerSlug: powerSlug,
        rivals: rivals,
        eventId: eventId,
      );

      // Manejar respuesta basada en el resultado
      switch (response.result) {
        case PowerUseResultType.reflected:
          // Notificar devolución solo si no tenemos return armado
          if (powerSlug != 'return' && !effectProvider.isReturnArmed) {
            effectProvider.notifyPowerReturned(response.returnedByName ?? 'Un rival');
          }
          await refreshProfile();
          return PowerUseResult.reflected;

        case PowerUseResultType.success:
          // Manejar efectos especiales
          if (response.stealFailed) {
            effectProvider.notifyStealFailed();
          }
          if (powerSlug == 'shield') {
            effectProvider.setShielded(true, sourceSlug: powerSlug);
          }
          await syncRealInventory(effectProvider: effectProvider);
          return PowerUseResult.success;

        case PowerUseResultType.error:
          return PowerUseResult.error;
      }
    } catch (e) {
      debugPrint('Error usando poder: $e');
      rethrow;
    } finally {
      effectProvider.setManualCasting(false);
      _isProcessing = false;
    }
  }

  Future<void> refreshProfile({String? eventId}) async {
    if (_currentPlayer != null) {
      await _fetchProfile(_currentPlayer!.userId, eventId: eventId);
    }
  }

  Future<void> _fetchProfile(String userId, {String? eventId}) async {
    try {
      // 1. Obtener perfil básico
      final profileData =
          await _supabase.from('profiles').select().eq('id', userId).single();

      // 2. Obtener GamePlayer y Vidas
      // Si tenemos eventId explícito, úsalo. Si no, usa el currentEventId almacenado
      final targetEventId = eventId ?? _currentPlayer?.currentEventId;
      
      final baseQuery = _supabase
          .from('game_players')
          .select('id, lives, status, event_id')
          .eq('user_id', userId);
      
      Map<String, dynamic>? gpData;
      
      if (targetEventId != null) {
        // Buscar específicamente para este evento
        gpData = await baseQuery.eq('event_id', targetEventId).maybeSingle();
      } else {
        // Si no hay evento específico, tomar el más reciente
        gpData = await baseQuery.order('joined_at', ascending: false).limit(1).maybeSingle();
      }

      List<String> realInventory = [];
      int actualLives = 3;
      String? gamePlayerId;
      String? fetchedEventId;

      if (gpData != null) {
        fetchedEventId = gpData['event_id'] as String?;
        
        // Check if user is suspended/banned from THIS SPECIFIC event
        final status = gpData['status'] as String?;
        if (status == 'suspended' || status == 'banned') {
          debugPrint('PlayerProvider: User is $status from event $fetchedEventId. Invalidating session.');
          // Don't set gamePlayerId - this will trigger GameSessionMonitor to kick the user
          gpData = null;
          fetchedEventId = null;
        } else {
          actualLives = gpData['lives'] ?? 3;
          final String gpId = gpData['id'];
          gamePlayerId = gpId;
        }
      }

      // Only fetch inventory if we have a valid, non-suspended game player
      if (gpData != null && gamePlayerId != null) {

        // 3. Obtener Inventario real de player_powers
        final List<dynamic> powersData = await _supabase
            .from('player_powers')
            .select('quantity, powers!inner(slug)')
            .eq('game_player_id', gamePlayerId!)
            .gt('quantity', 0);

        for (var item in powersData) {
          final powerDetails = item['powers'];
          if (powerDetails != null && powerDetails['slug'] != null) {
            final String slug = powerDetails['slug'];
            final int qty = item['quantity'];
            for (var i = 0; i < qty; i++) {
              realInventory.add(slug);
            }
          }
        }
      }

      // 4. Construir jugador de forma atómica
      final newPlayer = Player.fromJson(profileData);
      newPlayer.lives = actualLives;
      newPlayer.inventory = realInventory;
      newPlayer.gamePlayerId = gamePlayerId;
      newPlayer.currentEventId = fetchedEventId; // Store the event ID

      // --- CAMBIO: Verificar baneo ANTES de notificar un estado "válido" ---
      if (newPlayer.status == PlayerStatus.banned) {
         debugPrint("Usuario BANEADO detectado en tiempo real. Cerrando sesión...");
         _banMessage = 'Has sido baneado por un administrador.';
         // No actualizamos _currentPlayer para evitar "flicker" de isLoggedIn=true si ya estaba fallando
         await logout(clearBanMessage: false);
         return; 
      }

      _currentPlayer = newPlayer;
      debugPrint('🔍 PlayerProvider: notifyListeners() called. gamePlayerId: ${_currentPlayer?.gamePlayerId}');
      notifyListeners();

      // --- NUEVO: Verificar penalizaciones pendientes de desconexiones previas ---
      unawaited(_checkPendingPenalties(userId));

      // ASEGURAR que los listeners estén corriendo pero SOLAMENTE UNA VEZ
      _startListeners(userId);

      // --- NUEVO: Suscripción en tiempo real (STREAM) para el jugador actual ---
      _subscribeToGamePlayers(userId);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Timer? _pollingTimer;

  void _startListeners(String userId) {
    // Siempre reiniciamos el timer para asegurar que esté activo
    _startPolling(userId);
    
    // El stream solo lo iniciamos si no existe
    if (_profileSubscription == null) _subscribeToProfile(userId);
  }

  void _startPolling(String userId) {
    // Aumentamos el tiempo a 5 segundos para reducir el LAG pero ser más reactivos si Realtime falla.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_currentPlayer != null && _currentPlayer!.userId == userId) {
        try {
          // OPTIMIZACION: Solo verificamos el estatus, no todo el perfil ni inventario
          await _checkPlayerStatus(userId);
        } catch (e) {
           // debugPrint("Polling error: $e");
        }
      } else {
        timer.cancel();
        _pollingTimer = null;
      }
    });
  }

  Future<void> _checkPlayerStatus(String userId) async {
    try {
      // 1. Verificar estatus del perfil
      final response = await _supabase
          .from('profiles')
          .select('status')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final String statusStr = response['status'] ?? 'active';
        if (statusStr == 'banned' && _currentPlayer?.status != PlayerStatus.banned) {
           debugPrint("Polling detectó BAN. Forzando actualización...");
           await refreshProfile();
           return;
        }
      }

      // 2. DETECTAR REINICIO (Pérdida de inscripción al evento)
      if (_currentPlayer?.gamePlayerId != null) {
        final gpRes = await _supabase
            .from('game_players')
            .select('id')
            .eq('id', _currentPlayer!.gamePlayerId!)
            .maybeSingle();
        
        if (gpRes == null) {
          debugPrint("Polling detectó REINICIO (Inscripción desaparecida).");
          await refreshProfile();
        }
      }
    } catch (e) {
      // debugPrint("Error checking player status: $e");
    }
  }

  void _subscribeToProfile(String userId) {
    if (_profileSubscription != null) return; // Ya suscrito

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            debugPrint("Stream Profile Update: ${data.first['status']}");
            // Si el status cambió a banned, se detectará en _fetchProfile
            _fetchProfile(userId);
          }
        }, onError: (e) {
          debugPrint('Profile stream error: $e');
          _profileSubscription = null;
        });
  }

  void _subscribeToGamePlayers(String userId) {
    // Si ya estamos suscritos, no hacemos nada.
    if (_gamePlayersSubscription != null) return;

    debugPrint('🔊 PlayerProvider: Suscribiendo STREAM de game_players para usuario $userId');
    
    _gamePlayersSubscription = _supabase
        .from('game_players')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          debugPrint('🔊 PlayerProvider: ⚡ STREAM UPDATE recibida en game_players! (${data.length} filas)');
          
          bool banDetectedForCurrentEvent = false;
          final currentEventId = _currentPlayer?.currentEventId;

          for (final gp in data) {
            final String? status = gp['status'];
            final String? eventId = gp['event_id'];
            
            if (eventId == currentEventId && (status == 'suspended' || status == 'banned')) {
               debugPrint('🚫 PlayerProvider: BAN detectado para el evento actual ($eventId) via Stream!');
               banDetectedForCurrentEvent = true;
               break;
            }
          }

          if (!_isDisposed && _currentPlayer != null) {
            if (banDetectedForCurrentEvent) {
              // ACCIÓN INMEDIATA: Invalidar el ID de sesión localmente para disparar el GameSessionMonitor
              _currentPlayer!.gamePlayerId = null;
              _currentPlayer!.status = PlayerStatus.banned; // Asegurar consistencia total del estado
              debugPrint('🔍 PlayerProvider: Invalidadando sesión local (BAN INSTANTÁNEO).');
              notifyListeners();
            } else {
              // Para cualquier otro cambio (vidas, unban, etc.), refrescamos normalmente
              refreshProfile();
            }
          }
        }, onError: (error) {
          debugPrint('❌ PlayerProvider: Error en STREAM game_players: $error');
          _gamePlayersSubscription = null;
        });
  }

  // --- LOGICA DE INVENTARIO (delegada a InventoryService) ---
  
  Future<void> syncRealInventory({PowerEffectProvider? effectProvider}) async {
    if (_currentPlayer == null) return;

    try {
      debugPrint("Sincronizando inventario para user: ${_currentPlayer!.userId}");

      final result = await _inventoryService.syncRealInventory(
        userId: _currentPlayer!.userId,
      );

      if (!result.success) {
        debugPrint("Usuario no tiene game_player activo.");
        _currentPlayer!.inventory.clear();
        _currentPlayer!.gamePlayerId = null;
        effectProvider?.startListening(null);
        notifyListeners();
        return;
      }

      // Actualizar estado local
      if (result.lives != null) {
        _currentPlayer!.lives = result.lives!;
      }
      
      _currentPlayer!.gamePlayerId = result.gamePlayerId;
      
      // Configurar PowerEffectProvider
      effectProvider?.setShielded(_currentPlayer!.status == PlayerStatus.shielded);
      effectProvider?.configureReturnHandler((slug, casterId) async {
        final powerResult = await usePower(
          powerSlug: slug,
          targetGamePlayerId: casterId,
          effectProvider: effectProvider,
          allowReturnForward: false,
        );
        return powerResult != PowerUseResult.error;
      });
      effectProvider?.startListening(result.gamePlayerId);
      
      debugPrint("GamePlayer encontrado: ${result.gamePlayerId}");

      // Actualizar inventario
      _currentPlayer!.inventory.clear();
      _currentPlayer!.inventory.addAll(result.inventory);
      notifyListeners();
    } catch (e) {
      debugPrint('Error CRITICO syncing real inventory: $e');
    }
  }

  // --- LÓGICA DE TIENDA ---

  // player_provider.dart

  // --- MINIGAME LIFE MANAGEMENT (OPTIMIZED RPC) ---

  Future<void> loseLife({String? eventId}) async {
    if (_currentPlayer == null) return;

    // Evitamos llamada si ya está en 0 localmente para ahorrar red,
    // aunque el backend es la fuente de verdad.
    if (_currentPlayer!.lives <= 0) return;

    try {
      // Llamada RPC atómica: la base de datos resta y nos devuelve el valor final.
      // Importante: en el contexto del juego por evento, necesitamos p_event_id.
      final params = <String, dynamic>{
        'p_user_id': _currentPlayer!.userId,
      };
      if (eventId != null && eventId.isNotEmpty) {
        params['p_event_id'] = eventId;
      }

      final int newLives = await _supabase.rpc('lose_life', params: params);
      debugPrint("DEBUG: lose_life RPC result: newLives=$newLives");

      // Actualizamos estado local inmediatamente con la respuesta real del servidor
      _currentPlayer!.lives = newLives;
      notifyListeners();
    } catch (e) {
      debugPrint("Error perdiendo vida: $e");
      // Opcional: Revertir UI o mostrar error
    }
  }

  Future<void> resetLives() async {
    if (_currentPlayer == null) return;

    try {
      final int newLives = await _supabase.rpc('reset_lives', params: {
        'p_user_id': _currentPlayer!.userId,
      });

      _currentPlayer!.lives = newLives;
      notifyListeners();
    } catch (e) {
      debugPrint("Error reseteando vidas: $e");
    }
  }

  // --- SOCIAL & ADMIN (delegado a AdminService) ---

  Future<void> fetchAllPlayers() async {
    try {
      _allPlayers = await _adminService.fetchAllPlayers();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching all players: $e');
    }
  }

  Future<void> toggleBanUser(String userId, bool ban) async {
    try {
      await _adminService.toggleBanUser(userId, ban);

      final index = _allPlayers.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        _allPlayers[index].status =
            ban ? PlayerStatus.banned : PlayerStatus.active;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling ban: $e');
      rethrow;
    }
  }

  Future<void> toggleGameBanUser(String userId, String eventId, bool ban) async {
    debugPrint('PlayerProvider: toggleGameBanUser CALLED. Delegating to AdminService...');
    try {
      await _adminService.toggleGameBanUser(userId, eventId, ban);
      debugPrint('PlayerProvider: toggleGameBanUser completed successfully');
      // No actualizamos _allPlayers porque ese es global. 
      // El estado de juego se recarga al entrar a la competencia.
    } catch (e) {
      debugPrint('PlayerProvider: Error toggling game ban: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _adminService.deleteUser(userId);
      _allPlayers.removeWhere((p) => p.userId == userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // --- DEBUG ONLY ---
  Future<void> debugAddPower(String powerSlug) async {
    if (_currentPlayer == null) return;
    try {
      final gp = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', _currentPlayer!.userId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (gp == null) return;
      final String gpId = gp['id'];
      final power = await _supabase
          .from('powers')
          .select('id')
          .eq('slug', powerSlug)
          .single();
      final String powerUuid = power['id'];
      final existing = await _supabase
          .from('player_powers')
          .select('id, quantity')
          .eq('game_player_id', gpId)
          .eq('power_id', powerUuid)
          .maybeSingle();
      if (existing != null) {
        await _supabase
            .from('player_powers')
            .update({'quantity': (existing['quantity'] ?? 0) + 1}).eq(
                'id', existing['id']);
      } else {
        await _supabase.from('player_powers').insert(
            {'game_player_id': gpId, 'power_id': powerUuid, 'quantity': 1});
      }
      await refreshProfile();
      debugPrint("DEBUG: Poder $powerSlug añadido.");
    } catch (e) {
      debugPrint("Error en debugAddPower: $e");
    }
  }

  Future<void> debugToggleStatus(String status) async {
    if (_currentPlayer == null) return;
    try {
      final newStatus =
          _currentPlayer!.status.name == status ? 'active' : status;

      // ✅ CORRECCIÓN: Eliminamos 'frozen_until' porque no existe en tu tabla 'profiles'
      await _supabase.from('profiles').update({
        'status': newStatus,
      }).eq('id', _currentPlayer!.userId);

      await refreshProfile();
      debugPrint("DEBUG: Status cambiado a $newStatus");
    } catch (e) {
      debugPrint("Error en debugToggleStatus: $e");
    }
  }

  Future<void> debugAddAllPowers() async {
    final slugs = [
      'freeze',
      'black_screen',
      'life_steal',
      'blur_screen',
      'return',
      'shield',
      'invisibility',
      'extra_life'
    ];
    for (var slug in slugs) {
      await debugAddPower(slug);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _profileSubscription?.cancel();
    _gamePlayersSubscription?.cancel();
    super.dispose();
  }
}
