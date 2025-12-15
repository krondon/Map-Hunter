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
      
      // IMPORTANTE: Una vez cargado el perfil, sobreescribimos el inventario
      // con los datos reales de la tabla 'player_powers'
      await syncRealInventory();
      
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
      // Usamos get_my_inventory RPC si existe para ser más robustos contra RLS,
      // pero mantenemos la lógica de lectura directa si tu RPC no devuelve el formato exacto.
      // Si tienes problemas de RLS aquí también, cambia esto a usar 'get_my_inventory'.
      
      final gamePlayerRes = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', _currentPlayer!.id)
          .maybeSingle(); 

      if (gamePlayerRes == null) {
        _currentPlayer!.inventory.clear();
        notifyListeners();
        return;
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
      // Si falla por RLS, intenta limpiar inventario local para evitar inconsistencias
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
           final profileData = await _supabase.from('profiles').select().eq('id', _currentPlayer!.id).single();
           _currentPlayer = Player.fromJson(profileData);
           await syncRealInventory(); 
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

  // --- LÓGICA DE TIENDA (CORREGIDA) ---

  /// Compra un ítem usando RPC para evitar error 42P17 (Infinite Recursion)
  Future<bool> purchaseItem(String itemId, int cost) async {
    if (_currentPlayer == null) return false;
    if (_currentPlayer!.coins < cost) return false;

    try {
      // LLAMADA RPC SEGURA: Toda la lógica (check saldo, restar, dar item) ocurre en el servidor
      final response = await _supabase.rpc('buy_item', params: {
        'p_user_id': _currentPlayer!.id,
        'p_item_id': itemId,
        'p_cost': cost
      });

      // Manejo de respuesta
      if (response != null && response['success'] == true) {
        // Actualizamos la UI inmediatamente
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