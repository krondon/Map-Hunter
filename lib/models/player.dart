import 'package:flutter/material.dart';

class Player {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  int level;
  int experience;
  int totalXP;
  String profession;
  int coins;
  List<String> inventory;
  PlayerStatus status;
  DateTime? frozenUntil;
  Map<String, dynamic> stats;
  
  Player({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.level = 1,
    this.experience = 0,
    this.totalXP = 0,
    this.profession = 'Novice',
    this.coins = 100,
    List<String>? inventory,
    this.status = PlayerStatus.active,
    this.frozenUntil,
    Map<String, dynamic>? stats,
  }) : inventory = inventory ?? [],
       stats = stats ?? {
         'speed': 0,
         'strength': 0,
         'intelligence': 0,
       };
  
  int get experienceToNextLevel => (level * 100);
  
  double get experienceProgress => experience / experienceToNextLevel;
  
  bool get isFrozen => status == PlayerStatus.frozen && 
      frozenUntil != null && 
      DateTime.now().isBefore(frozenUntil!);
  
  void addExperience(int xp) {
    experience += xp;
    totalXP += xp;
    
    while (experience >= experienceToNextLevel) {
      experience -= experienceToNextLevel;
      level++;
    }
  }
  
  void addItem(String item) {
    inventory.add(item);
  }
  
  bool removeItem(String item) {
    return inventory.remove(item);
  }
  
  void updateProfession() {
    final speed = stats['speed'] as int;
    final strength = stats['strength'] as int;
    final intelligence = stats['intelligence'] as int;
    
    if (speed > strength && speed > intelligence) {
      profession = 'Speedrunner';
    } else if (strength > speed && strength > intelligence) {
      profession = 'Warrior';
    } else if (intelligence > speed && intelligence > strength) {
      profession = 'Strategist';
    } else {
      profession = 'Balanced';
    }
  }
}

enum PlayerStatus {
  active,
  frozen,
  shielded,
}
