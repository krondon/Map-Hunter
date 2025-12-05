import 'package:flutter/material.dart';
import '../models/player.dart';

class PlayerProvider extends ChangeNotifier {
  Player? _currentPlayer;
  
  Player? get currentPlayer => _currentPlayer;
  
  bool get isLoggedIn => _currentPlayer != null;
  
  // Mock login
  void login(String email, String password) {
    _currentPlayer = Player(
      id: '1',
      name: 'Cazador Pro',
      email: email,
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      level: 5,
      experience: 250,
      totalXP: 750,
      profession: 'Speedrunner',
      coins: 150,
      inventory: ['shield', 'hint'],
      stats: {
        'speed': 15,
        'strength': 8,
        'intelligence': 12,
      },
    );
    notifyListeners();
  }
  
  void register(String name, String email, String password) {
    _currentPlayer = Player(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      avatarUrl: 'https://i.pravatar.cc/150?img=${DateTime.now().millisecondsSinceEpoch % 70}',
    );
    notifyListeners();
  }
  
  void logout() {
    _currentPlayer = null;
    notifyListeners();
  }
  
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
      _currentPlayer!.stats[stat] = (_currentPlayer!.stats[stat] as int) + value;
      _currentPlayer!.updateProfession();
      notifyListeners();
    }
  }

  void sabotageRival(String rivalId) {
    if (_currentPlayer != null && _currentPlayer!.coins >= 50) {
      _currentPlayer!.coins -= 50;
      notifyListeners();
    }
  }
}
