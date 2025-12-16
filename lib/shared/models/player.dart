class Player {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String role; // 'admin' or 'user'
  int level;
  int experience;
  int totalXP;
  String profession;
  int coins;
  List<String> inventory;
  PlayerStatus status;
  DateTime? frozenUntil;
  int lives;
  Map<String, dynamic> stats;

  Player({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.role = 'user',
    this.level = 1,
    this.experience = 0,
    this.totalXP = 0,
    this.profession = 'Novice',
    this.coins = 100,
    List<String>? inventory,
    this.status = PlayerStatus.active,
    this.frozenUntil,
    this.lives = 3,
    Map<String, dynamic>? stats,
  })  : inventory = inventory ?? [],
        stats = stats ??
            {
              'speed': 0,
              'strength': 0,
              'intelligence': 0,
            };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      role: json['role'] ?? 'user',
      level: json['level'] ?? 1,
      experience: json['experience'] ?? 0,
      totalXP: json['total_xp'] ?? 0,
      profession: json['profession'] ?? 'Novice',
      coins: json['total_coins'] ?? 100,
      status: _parseStatus(json['status']),
      frozenUntil: json['frozen_until'] != null
          ? DateTime.parse(json['frozen_until'])
          : null,
      stats: {
        'speed': json['stat_speed'] ?? 0,
        'strength': json['stat_strength'] ?? 0,
        'intelligence': json['stat_intelligence'] ?? 0,
      },
      inventory: json['inventory'] != null 
          ? List<String>.from(json['inventory']) 
          : [],
    );
  }

  static PlayerStatus _parseStatus(String? status) {
    switch (status) {
      case 'frozen':
        return PlayerStatus.frozen;
      case 'blinded':
        return PlayerStatus.blinded;
      case 'slowed':
        return PlayerStatus.slowed;
      case 'shielded':
        return PlayerStatus.shielded;
      case 'banned':
        return PlayerStatus.banned;
      case 'pending':
        return PlayerStatus.pending;
      default:
        return PlayerStatus.active;
    }
  }

  int get experienceToNextLevel => (level * 100);

  double get experienceProgress => experience / experienceToNextLevel;

  bool get isFrozen =>
      status == PlayerStatus.frozen &&
      frozenUntil != null &&
      DateTime.now().isBefore(frozenUntil!);

  bool get isBlinded =>
      status == PlayerStatus.blinded &&
      frozenUntil != null &&
      DateTime.now().isBefore(frozenUntil!);

  bool get isSlowed =>
      status == PlayerStatus.slowed &&
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
  blinded,
  shielded,
  banned,
  pending,
  slowed,
}
