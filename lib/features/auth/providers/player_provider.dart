import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final _supabase = Supabase.instance.client;

  // Mapa para guardar el inventario filtrado por evento
  // Estructura: { eventId: { powerId: quantity } }
  final Map<String, Map<String, int>> _eventInventories = {};

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
        throw Exception(error);
      }

      final data = response.data;
      
      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);
        
        if (data['user'] != null) {
          await _fetchProfile(data['user']['id']);
        }
      } else {
         throw Exception('No se recibió sesión válida');
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
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
        throw Exception(error);
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
      rethrow;
    }
  }

  Future<void> logout() async {
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
      final List<dynamic> response = await _supabase.rpc('get_my_inventory_by_event', params: {
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

  Future<bool> purchaseItem(String itemId, String eventId, int cost, {bool isPower = true}) async {
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
      await _supabase.from('profiles').update({
        'total_coins': _currentPlayer!.coins - cost
      }).eq('id', _currentPlayer!.id);

      // B. Sumar vida en game_players
      await _supabase.from('game_players').update({
        'lives': currentLives + 1
      }).eq('id', gamePlayerId);

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

  Future<bool> usePower({required String powerId, required String targetUserId}) async {
    if (_currentPlayer == null) return false;
    try {
      // Necesitamos el contexto del evento para saber qué inventario refrescar
      // Aquí asumo que usas el game_player_id como en tu SQL use_power_mechanic
      
      final response = await _supabase.rpc('use_power_mechanic', params: {
        'p_caster_id': _currentPlayer!.id, // Ajustar según tu lógica de IDs en use_power_mechanic
        'p_target_id': targetUserId,
        'p_power_id': powerId,
      });

      if (response['success'] == true) {
        // En lugar de syncRealInventory genérico, aquí deberías refrescar 
        // el inventario del evento actual si tienes el ID a mano.
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error usando poder: $e');
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
      _subscribeToProfile(userId);

      final data = await _supabase.from('profiles').select().eq('id', userId).single();

      _currentPlayer = Player.fromJson(data);
      
      // IMPORTANTE: Una vez cargado el perfil, sincronizamos inventario y vidas reales
      await syncRealInventory();
      // Nota: Si tus vidas no están en la tabla 'profiles' sino solo en 'game_players',
      // deberías sincronizarlas aquí también, similar a syncRealInventory.
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  void _subscribeToProfile(String userId) {
    _profileSubscription?.cancel();
    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            _currentPlayer = Player.fromJson(data.first);
            syncRealInventory(); 
            notifyListeners();
          }
        }, onError: (e) {
          debugPrint('Profile stream error: $e');
        });
  }

  // --- LOGICA DE PODERES E INVENTARIO (BACKEND INTEGRATION) ---
Future<void> syncRealInventory() async {
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
        notifyListeners();
        return;
      }

      if (gamePlayerRes['lives'] != null) {
         _currentPlayer!.lives = gamePlayerRes['lives'];
      }

      final String gamePlayerId = gamePlayerRes['id'];
      debugPrint("GamePlayer encontrado: $gamePlayerId");

      // 2. Traer poderes con JOIN
      final List<dynamic> powersData = await _supabase
          .from('player_powers')
          .select('quantity, powers!inner(slug)') // !inner fuerza a que exista el poder
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

      _allPlayers = (data as List).map((json) => Player.fromJson(json)).toList();
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
        _allPlayers[index].status = ban ? PlayerStatus.banned : PlayerStatus.active;
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
}