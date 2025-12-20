import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';
import '../../game/providers/power_effect_provider.dart';
import '../../game/providers/game_provider.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final _supabase = Supabase.instance.client;

  // Mapa para guardar el inventario filtrado por evento
  // Estructura: { eventId: { powerId: quantity } }
  final Map<String, Map<String, int>> _eventInventories = {};

  bool _isProcessing = false;

  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;
  bool get isLoggedIn => _currentPlayer != null;

  // --- NUEVO: Obtener cantidad de un poder específico en un evento ---
  int getPowerCount(String itemId, String eventId) {
    return _eventInventories[eventId]?[itemId] ?? 0;
  }

  // --- AUTHENTICATION ---

  Future<void> login(String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/login',
        body: {'email': email, 'password': password},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        throw error; // Lanzar el string directamente para procesarlo
      }

      final data = response.data;

      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);

        if (data['user'] != null) {
          await _fetchProfile(data['user']['id']);
        }
      } else {
        throw 'No se recibió sesión válida';
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      throw _handleAuthError(e);
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/register',
        body: {'email': email, 'password': password, 'name': name},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        throw error;
      }

      final data = response.data;

      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);

        if (data['user'] != null) {
          await Future.delayed(const Duration(seconds: 1));
          await _fetchProfile(data['user']['id']);
        }
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(dynamic e) {
    String errorMsg = e.toString().toLowerCase();

    if (errorMsg.contains('invalid login credentials') ||
        errorMsg.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';
    }
    if (errorMsg.contains('user already registered') ||
        errorMsg.contains('already exists')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('password should be at least 6 characters')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (errorMsg.contains('network') || errorMsg.contains('connection')) {
      return 'Error de conexión. Revisa tu internet e intenta de nuevo.';
    }
    if (errorMsg.contains('email not confirmed')) {
      return 'Debes confirmar tu correo electrónico antes de entrar.';
    }
    if (errorMsg.contains('too many requests')) {
      return 'Demasiados intentos. Por favor espera un momento.';
    }

    // Limpiar el prefijo 'Exception: ' si existe
    return e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
  }

  Future<void> logout() async {
    _pollingTimer?.cancel();
    await _profileSubscription?.cancel();
    await _supabase.auth.signOut();
    _currentPlayer = null;
    notifyListeners();
  }

  // --- PROFILE MANAGEMENT ---

  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  Future<void> fetchInventory(String userId, String eventId) async {
    try {
      // Llamamos a la nueva función SQL que retorna el campo 'slug'
      final List<dynamic> response =
          await _supabase.rpc('get_my_inventory_by_event', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
      });

      // Procesar datos y guardarlos en el mapa de inventarios
      final Map<String, int> eventItems = {};
      final List<String> inventoryList = [];

      for (var item in response) {
        // CAMBIO CLAVE: Usamos 'slug' en lugar de 'power_id'
        // Esto permite que coincida con los IDs de PowerItem.getShopItems() (ej: 'freeze')
        final String itemId = item['slug'] ?? item['power_id'].toString();
        final int qty = item['quantity'] ?? 0;

        eventItems[itemId] = qty;

        // Llenamos la lista plana para que la UI (InventoryScreen) pueda iterar
        for (int i = 0; i < qty; i++) {
          inventoryList.add(itemId);
        }
      }

      // Guardamos la relación cantidad/item para validaciones de la tienda (máx 3)
      _eventInventories[eventId] = eventItems;

      // Actualizamos el inventario del jugador actual para que la UI se refresque
      if (_currentPlayer != null) {
        _currentPlayer!.inventory = inventoryList;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching event inventory: $e');
    }
  }
  // --- LÓGICA DE TIENDA ACTUALIZADA ---

  Future<bool> purchaseItem(String itemId, String eventId, int cost,
      {bool isPower = true}) async {
    if (_currentPlayer == null) return false;

    // MANEJO ESPECIAL PARA VIDAS (extra_life)
    if (itemId == 'extra_life') {
      return _purchaseLifeManual(eventId, cost);
    }

    try {
      // Llamada a la función SQL: buy_item
      await _supabase.rpc('buy_item', params: {
        'p_user_id': _currentPlayer!.id,
        'p_event_id': eventId,
        'p_item_id': itemId,
        'p_cost': cost,
        'p_is_power': isPower,
      });

      // Si la función SQL no lanzó excepción, la compra fue exitosa
      // Actualizamos monedas localmente para feedback inmediato
      _currentPlayer!.coins -= cost;

      // Refrescamos el inventario específico para que el contador de la tienda se actualice
      await fetchInventory(_currentPlayer!.id, eventId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error en compra: $e");
      // Re-lanzamos el error para que el SnackBar en la UI lo muestre
      rethrow;
    }
  }

  Future<bool> _purchaseLifeManual(String eventId, int cost) async {
    try {
      // 1. Validar monedas localmente
      if ((_currentPlayer?.coins ?? 0) < cost) {
        return false;
      }

      // 2. Obtener game_player_id y vidas actuales
      final gpResponse = await _supabase
          .from('game_players')
          .select('id, lives')
          .eq('user_id', _currentPlayer!.id)
          .eq('event_id', eventId)
          .single();

      final String gamePlayerId = gpResponse['id'];
      final int currentLives = gpResponse['lives'];

      // 3. Realizar actualizaciones
      // A. Restar monedas en profiles
      await _supabase
          .from('profiles')
          .update({'total_coins': _currentPlayer!.coins - cost}).eq(
              'id', _currentPlayer!.id);

      // B. Sumar vida en game_players
      await _supabase
          .from('game_players')
          .update({'lives': currentLives + 1}).eq('id', gamePlayerId);

      // C. Registrar transacción
      await _supabase.from('transactions').insert({
        'game_player_id': gamePlayerId,
        'transaction_type': 'purchase',
        'coins_change': -cost,
        'description': 'Compra de Vida Extra',
      });

      // 4. Actualizar estado local
      _currentPlayer!.coins -= cost;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint("Error comprando vida manualmente: $e");
      return false;
    }
  }

  // --- USO DE PODERES ---

  Future<bool> usePower({
    required String powerSlug,
    required String targetGamePlayerId,
    required PowerEffectProvider effectProvider,
    GameProvider? gameProvider,
    bool allowReturnForward = true,
  }) async {
    if (_currentPlayer == null) return false;
    if (_isProcessing) return false;
    _isProcessing = true;

    final casterGamePlayerId = _currentPlayer!.gamePlayerId;
    if (casterGamePlayerId == null || casterGamePlayerId.isEmpty) {
      debugPrint('usePower abortado: caster gamePlayerId nulo');
      _isProcessing = false;
      return false;
    }

    try {
      bool success = false;

      if (powerSlug == 'return') {
        // Persistencia (Point C): descontar inmediatamente en player_powers.
        final paid = await _decrementPowerBySlug('return', casterGamePlayerId);
        if (!paid) {
          debugPrint('usePower(return): sin cantidad disponible.');
          return false;
        }
        // Armar devolución para el próximo ataque entrante
        success = true;
        effectProvider.armReturn();
      } else {
        final response = await _supabase.rpc('use_power_mechanic', params: {
          'p_caster_id': casterGamePlayerId,
          'p_target_id': targetGamePlayerId,
          'p_power_slug': powerSlug,
        });
        success = response is Map && response['success'] == true;
      }

      // Evitar rebotes infinitos de devoluciones
      if (!allowReturnForward && powerSlug == 'return') {
        success = true;
      }

      if (success) {
        // Hooks de front inmediato
        if (powerSlug == 'shield') {
          effectProvider.setShielded(true, sourceSlug: powerSlug);
        }

        // Broadcast solicitado: cuando se envía blur_screen a un rival,
        // disparar la misma animación de invisibilidad en TODOS los rivales del evento.
        // Implementación: insertamos registros adicionales en `active_powers` para cada rival.
        if (powerSlug == 'blur_screen' && gameProvider != null) {
          await _broadcastBlurScreenToEventRivals(
            gameProvider: gameProvider,
            casterGamePlayerId: casterGamePlayerId,
            excludeTargetGamePlayerId: targetGamePlayerId,
          );
        }

        await syncRealInventory(effectProvider: effectProvider);
      }
      return success;
    } catch (e) {
      debugPrint('Error usando poder: $e');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> _decrementPowerBySlug(
      String powerSlug, String gamePlayerId) async {
    try {
      final powerRes = await _supabase
          .from('powers')
          .select('id')
          .eq('slug', powerSlug)
          .maybeSingle();

      if (powerRes == null || powerRes['id'] == null) return false;
      final String powerId = powerRes['id'];

      final existing = await _supabase
          .from('player_powers')
          .select('id, quantity')
          .eq('game_player_id', gamePlayerId)
          .eq('power_id', powerId)
          .maybeSingle();

      if (existing == null) return false;
      final int currentQty = (existing['quantity'] as num?)?.toInt() ?? 0;
      if (currentQty <= 0) return false;

      final updated = await _supabase
          .from('player_powers')
          .update({'quantity': currentQty - 1})
          .eq('id', existing['id'])
          .eq('quantity', currentQty)
          .select();

      return updated.isNotEmpty;
    } catch (e) {
      debugPrint('_decrementPowerBySlug error: $e');
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (_currentPlayer != null) {
      await _fetchProfile(_currentPlayer!.id);
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      // 1. Obtener perfil básico
      final profileData =
          await _supabase.from('profiles').select().eq('id', userId).single();

      // 2. Obtener GamePlayer y Vidas
      final gpData = await _supabase
          .from('game_players')
          .select('id, lives')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      List<String> realInventory = [];
      int actualLives = 3;
      String? gamePlayerId;

      if (gpData != null) {
        actualLives = gpData['lives'] ?? 3;
        final String gpId = gpData['id'];
        gamePlayerId = gpId;

        // 3. Obtener Inventario real de player_powers
        final List<dynamic> powersData = await _supabase
            .from('player_powers')
            .select('quantity, powers!inner(slug)')
            .eq('game_player_id', gpId)
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

      _currentPlayer = newPlayer;
      notifyListeners();

      // ASEGURAR que los listeners estén corriendo pero SOLAMENTE UNA VEZ
      _startListeners(userId);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Timer? _pollingTimer;

  void _startListeners(String userId) {
    if (_pollingTimer == null) _startPolling(userId);
    if (_profileSubscription == null) _subscribeToProfile(userId);
  }

  void _startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentPlayer != null) {
        try {
          await refreshProfile();
        } catch (e) {
          // Si falla por internet (No host), ignoramos y reintentamos en 2s
          debugPrint("Polling silenciado por error de red: $e");
        }
      } else {
        timer.cancel();
        _pollingTimer = null;
      }
    });
  }

  void _subscribeToProfile(String userId) {
    if (_profileSubscription != null) return; // Ya suscrito

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            _fetchProfile(userId);
          }
        }, onError: (e) {
          debugPrint('Profile stream error: $e');
          _profileSubscription = null;
        });
  }

  // --- LOGICA DE PODERES E INVENTARIO (BACKEND INTEGRATION) ---
  Future<void> syncRealInventory({PowerEffectProvider? effectProvider}) async {
    if (_currentPlayer == null) return;

    try {
      debugPrint("Sincronizando inventario para user: ${_currentPlayer!.id}");

      // 1. Obtenemos el GamePlayer MÁS RECIENTE
      // Ordenamos por joined_at descendente para asegurar que es el juego actual
      final gamePlayerRes = await _supabase
          .from('game_players')
          .select('id, lives')
          .eq('user_id', _currentPlayer!.id)
          .order('joined_at', ascending: false) // <--- CRÍTICO
          .limit(1)
          .maybeSingle();

      if (gamePlayerRes == null) {
        debugPrint("Usuario no tiene game_player activo.");
        _currentPlayer!.inventory.clear();
        _currentPlayer!.gamePlayerId = null;
        effectProvider?.startListening(null);
        notifyListeners();
        return;
      }

      if (gamePlayerRes['lives'] != null) {
        _currentPlayer!.lives = gamePlayerRes['lives'];
      }

      final String gamePlayerId = gamePlayerRes['id'];
      _currentPlayer!.gamePlayerId = gamePlayerId;
      effectProvider
          ?.setShielded(_currentPlayer!.status == PlayerStatus.shielded);
      effectProvider?.configureReturnHandler((slug, casterId) {
        return usePower(
          powerSlug: slug,
          targetGamePlayerId: casterId,
          effectProvider: effectProvider,
          allowReturnForward: false,
        );
      });
      effectProvider?.startListening(gamePlayerId);
      debugPrint("GamePlayer encontrado: $gamePlayerId");

      // 2. Traer poderes con JOIN
      final List<dynamic> powersData = await _supabase
          .from('player_powers')
          .select(
              'quantity, powers!inner(slug)') // !inner fuerza a que exista el poder
          .eq('game_player_id', gamePlayerId)
          .gt('quantity', 0);

      debugPrint("Poderes encontrados en BD: ${powersData.length}");

      List<String> realInventory = [];

      for (var item in powersData) {
        final powerDetails = item['powers'];
        // Protección extra contra nulos
        if (powerDetails != null && powerDetails['slug'] != null) {
          final String pId = powerDetails['slug'];
          final int qty = item['quantity'];

          debugPrint("Agregando $qty de $pId");
          for (var i = 0; i < qty; i++) {
            realInventory.add(pId);
          }
        }
      }

      _currentPlayer!.inventory.clear();
      _currentPlayer!.inventory.addAll(realInventory);
      notifyListeners();
    } catch (e) {
      debugPrint('Error CRITICO syncing real inventory: $e');
    }
  }

  // --- LÓGICA DE TIENDA ---

  // player_provider.dart

  // --- MINIGAME LIFE MANAGEMENT (OPTIMIZED RPC) ---

  Future<void> loseLife() async {
    if (_currentPlayer == null) return;

    // Evitamos llamada si ya está en 0 localmente para ahorrar red,
    // aunque el backend es la fuente de verdad.
    if (_currentPlayer!.lives <= 0) return;

    try {
      // Llamada RPC atómica: la base de datos resta y nos devuelve el valor final
      final int newLives = await _supabase.rpc('lose_life', params: {
        'p_user_id': _currentPlayer!.id,
      });

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
        'p_user_id': _currentPlayer!.id,
      });

      _currentPlayer!.lives = newLives;
      notifyListeners();
    } catch (e) {
      debugPrint("Error reseteando vidas: $e");
    }
  }

  // --- SOCIAL & ADMIN ---

  Future<void> fetchAllPlayers() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('name', ascending: true);

      _allPlayers =
          (data as List).map((json) => Player.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching all players: $e');
    }
  }

  Future<void> toggleBanUser(String userId, bool ban) async {
    try {
      await _supabase.rpc('toggle_ban',
          params: {'user_id': userId, 'new_status': ban ? 'banned' : 'active'});

      final index = _allPlayers.indexWhere((p) => p.id == userId);
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

  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.rpc('delete_user', params: {'user_id': userId});
      _allPlayers.removeWhere((p) => p.id == userId);
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
          .eq('user_id', _currentPlayer!.id)
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
      final expiration =
          DateTime.now().toUtc().add(const Duration(seconds: 15));
      final newStatus =
          _currentPlayer!.status.name == status ? 'active' : status;

      await _supabase.from('profiles').update({
        'status': newStatus,
        'frozen_until':
            newStatus == 'active' ? null : expiration.toIso8601String(),
      }).eq('id', _currentPlayer!.id);

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

  Future<void> _broadcastBlurScreenToEventRivals({
    required GameProvider gameProvider,
    required String casterGamePlayerId,
    required String excludeTargetGamePlayerId,
  }) async {
    try {
      final eventId = gameProvider.currentEventId;
      final now = DateTime.now().toUtc();
      // Según tu DB: blur_screen duration = 10
      final expiresAt = now.add(const Duration(seconds: 10)).toIso8601String();

      final rivals = gameProvider.leaderboard
          .where((p) => p.gamePlayerId != null && p.gamePlayerId!.isNotEmpty)
          .map((p) => p.gamePlayerId!)
          .where((gpId) => gpId != casterGamePlayerId)
          .where((gpId) => gpId != excludeTargetGamePlayerId)
          .toSet()
          .toList();

      if (rivals.isEmpty) return;

      final payloads = rivals
          .map((gpId) => <String, dynamic>{
                'target_id': gpId,
                'caster_id': casterGamePlayerId,
                'power_slug': 'blur_screen',
                'expires_at': expiresAt,
                if (eventId != null) 'event_id': eventId,
              })
          .toList();

      await _supabase.from('active_powers').insert(payloads);
    } catch (e) {
      debugPrint('_broadcastBlurScreenToEventRivals error: $e');
    }
  }
}
