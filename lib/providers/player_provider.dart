import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final _supabase = Supabase.instance.client;

  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;

  bool get isLoggedIn => _currentPlayer != null;

  Future<void> login(String email, String password) async {
    try {
      // Call Edge Function for login
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
        // Set the session in the client to maintain auth state
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
      // Call Edge Function for register
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
        // Set session if auto-confirm is enabled
        await _supabase.auth.setSession(data['session']['refresh_token']);
        
        if (data['user'] != null) {
          // Wait a bit for the trigger to create the profile
          await Future.delayed(const Duration(seconds: 1));
          await _fetchProfile(data['user']['id']);
        }
      } else if (data['user'] != null) {
        // User created but maybe email confirmation is required
        // Just return, user will need to confirm email
      }
    } catch (e) {
      debugPrint('Error registering: $e');
      rethrow;
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final data =
          await _supabase.from('profiles').select().eq('id', userId).single();

      _currentPlayer = Player.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // If profile doesn't exist yet (race condition), maybe retry or handle gracefully
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _currentPlayer = null;
    notifyListeners();
  }

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
      // Ejecutar la función de Supabase para banear/desbanear
      await _supabase.rpc('toggle_ban',
          params: {'user_id': userId, 'new_status': ban ? 'banned' : 'active'});

      // Actualizar estado local
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

  // Methods below would need to be updated to sync with Supabase DB
  // For now, we'll keep them updating local state, but in a real app
  // they should call RPCs or update tables.

  void addExperience(int xp) {
    if (_currentPlayer != null) {
      final oldLevel = _currentPlayer!.level;
      _currentPlayer!.addExperience(xp);

      if (_currentPlayer!.level > oldLevel) {
        // Level up!
        _currentPlayer!.updateProfession();
      }
      notifyListeners();
    }
  }

  void addCoins(int amount) {
    if (_currentPlayer != null) {
      _currentPlayer!.coins += amount;
      notifyListeners();
    }
  }

  bool spendCoins(int amount) {
    if (_currentPlayer != null && _currentPlayer!.coins >= amount) {
      _currentPlayer!.coins -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }

  void addItemToInventory(String item) {
    if (_currentPlayer != null) {
      _currentPlayer!.addItem(item);
      notifyListeners();
    }
  }

  bool useItemFromInventory(String item) {
    if (_currentPlayer != null && _currentPlayer!.removeItem(item)) {
      notifyListeners();
      return true;
    }
    return false;
  }

  void freezePlayer(DateTime until) {
    if (_currentPlayer != null) {
      _currentPlayer!.status = PlayerStatus.frozen;
      _currentPlayer!.frozenUntil = until;
      notifyListeners();
    }
  }

  void unfreezePlayer() {
    if (_currentPlayer != null) {
      _currentPlayer!.status = PlayerStatus.active;
      _currentPlayer!.frozenUntil = null;
      notifyListeners();
    }
  }

  void updateStats(String stat, int value) {
    if (_currentPlayer != null) {
      _currentPlayer!.stats[stat] =
          (_currentPlayer!.stats[stat] as int) + value;
      _currentPlayer!.updateProfession();
      notifyListeners();
    }
  }

  Future<bool> sabotageRival(String rivalId) async {
    try {
      final response = await _supabase.functions.invoke('game-play/sabotage-rival', 
        body: {'rivalId': rivalId},
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        // Refresh profile to show deducted coins
        if (_currentPlayer != null) {
          await _fetchProfile(_currentPlayer!.id);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sabotaging rival: $e');
      return false;
    }
  }
}
