import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final _supabase = Supabase.instance.client;

  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;

  bool get isLoggedIn => _currentPlayer != null;

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
      final gamePlayerRes = await _supabase
          .from('game_players')
          .select('id, lives') // Agregamos lives por si acaso quieres sincronizarlo aquí
          .eq('user_id', _currentPlayer!.id)
          .maybeSingle(); 

      if (gamePlayerRes == null) {
        _currentPlayer!.inventory.clear();
        notifyListeners();
        return;
      }

      // Opcional: Sincronizar vidas si el modelo Player no lo trajo de profiles
      if (gamePlayerRes['lives'] != null) {
         _currentPlayer!.lives = gamePlayerRes['lives'];
      }

      final String gamePlayerId = gamePlayerRes['id'];

      final List<dynamic> powersData = await _supabase
          .from('player_powers')
          .select('power_id, quantity')
          .eq('game_player_id', gamePlayerId)
          .gt('quantity', 0); 

      List<String> realInventory = [];
      for (var item in powersData) {
        final String pId = item['power_id'];
        final int qty = item['quantity'];
        for (var i = 0; i < qty; i++) {
          realInventory.add(pId);
        }
      }

      _currentPlayer!.inventory.clear();
      _currentPlayer!.inventory.addAll(realInventory);
      notifyListeners();

    } catch (e) {
      debugPrint('Error syncing real inventory: $e');
    }
  }

  Future<bool> usePower({
    required String powerId, 
    required String targetUserId 
  }) async {
    if (_currentPlayer == null) return false;

    try {
      final casterRes = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', _currentPlayer!.id)
          .maybeSingle();

      if (casterRes == null) return false;
      final String casterId = casterRes['id'];

      final targetRes = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', targetUserId)
          .maybeSingle();

      if (targetRes == null) return false;
      final String targetId = targetRes['id'];

      final response = await _supabase.rpc('use_power_mechanic', params: {
        'p_caster_id': casterId,
        'p_target_id': targetId,
        'p_power_id': powerId,
      });

      if (response['success'] == true) {
        await syncRealInventory();
        
        if (targetUserId == _currentPlayer!.id) {
           await Future.delayed(const Duration(milliseconds: 200));
           // Refresco simple
           await refreshProfile(); 
        }
        
        return true;
      } else {
        debugPrint('Fallo lógica Backend: ${response['message']}');
        return false;
      }

    } catch (e) {
      debugPrint('Error crítico al usar poder: $e');
      return false;
    }
  }

  // --- LÓGICA DE TIENDA ---

  Future<bool> purchaseItem(String itemId, int cost) async {
    if (_currentPlayer == null) return false;
    if (_currentPlayer!.coins < cost) return false;

    try {
      final response = await _supabase.rpc('buy_item', params: {
        'p_user_id': _currentPlayer!.id,
        'p_item_id': itemId,
        'p_cost': cost
      });

      if (response != null && response['success'] == true) {
        await refreshProfile(); 
        return true;
      } else {
        debugPrint("Error en compra (Backend): ${response['message']}");
        return false;
      }

    } catch (e) {
      debugPrint("Error crítico RPC compra: $e");
      return false;
    }
  }

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