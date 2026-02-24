import 'package:flutter/foundation.dart';
import '../../features/game/models/i_targetable.dart';

class Player implements ITargetable {
  final String userId;
  final String name;
  final String email;
  final String _avatarUrl;
  final String role; // 'admin' or 'user'
  String? avatarId; // ID del sprite elegido
  String? gamePlayerId; // ID de inscripción al evento (game_players.id)
  String? currentEventId; // ID del evento actual en el que está jugando
  int level;
  int experience;
  int totalXP;
  @override
  int completedCluesCount; // Precise tracking for race
  String profession;
  int coins;
  List<String> inventory;
  PlayerStatus status;
  DateTime? frozenUntil;
  DateTime? lastCompletionTime; // [FIX] Para desempate en ranking
  List<String>? eventsCompleted;
  int lives;
  int clovers; // New currency - tréboles
  final String? cedula;
  final String? phone;
  final String? documentType; // Added for Payment Profile
  final bool isProtected; // SHIELD CONSISTENCY FIX
  final bool emailVerified; // Whether email has been verified
  Map<String, dynamic> stats;
  final DateTime? createdAt;

  Player({
    required this.userId,
    required this.name,
    required this.email,
    String? avatarUrl,
    this.role = 'user',
    this.level = 1,
    this.experience = 0,
    this.totalXP = 0,
    this.completedCluesCount = 0,
    this.profession = 'Novice',
    this.coins = 300,
    List<String>? inventory,
    this.status = PlayerStatus.active,
    this.frozenUntil,
    this.lastCompletionTime,
    this.eventsCompleted,
    this.lives = 3,
    this.clovers = 0,
    Map<String, dynamic>? stats,
    this.avatarId,
    this.gamePlayerId,
    this.currentEventId,
    this.cedula,
    this.phone,
    this.documentType,
    this.createdAt,
    this.isProtected = false,
    this.emailVerified = true,
  })  : _avatarUrl = avatarUrl ?? '',
        inventory = inventory ?? [],
        stats = stats ??
            {
              'speed': 0,
              'strength': 0,
              'intelligence': 0,
            };

  factory Player.fromJson(Map<String, dynamic> json) {
    debugPrint('DEBUG: Player.fromJson input: $json');
    String? avatar = json['avatar_url'];
    if (avatar != null && (avatar.contains('file:') || avatar.contains('C:/'))) {
       avatar = null; // Sanitize local paths
    }

    // INSPECCIÓN DE LLAVES (Para diagnosticar por qué no se ve el avatar)
    debugPrint('DEBUG: Player.fromJson Keys for ${json['name']}: ${json.keys.toList()}');
    
    String? avatarUrlCol = json['avatar_url']?.toString();
    dynamic profilesData = json['profiles'];
    String? extractedAvatarId;
    
    if (profilesData is Map) {
      extractedAvatarId = profilesData['avatar_id']?.toString() ?? profilesData['avatarId']?.toString();
    } else if (profilesData is List && profilesData.isNotEmpty) {
      extractedAvatarId = profilesData.first['avatar_id']?.toString() ?? profilesData.first['avatarId']?.toString();
    }
    
    // Si avatar_url no es una URL real, podría ser el ID
    if (avatarUrlCol != null && !avatarUrlCol.startsWith('http') && avatarUrlCol.isNotEmpty && !avatarUrlCol.contains('/')) {
      extractedAvatarId ??= avatarUrlCol;
    }
    
    // Lista de posibles nombres para el ID del sprite
    final avatarId = json['avatar_id'] ?? 
                     json['avatarId'] ?? 
                     json['sprite_id'] ?? 
                     json['avatar_url_local'] ?? 
                     json['avatar'] ?? 
                     extractedAvatarId;
                     
    debugPrint('DEBUG: Player.fromJson final avatarId mapping result for ${json['name']}: $avatarId');

    // Parse document type from DNI if missing
    final String? dniVal = json['cedula']?.toString() ?? json['dni']?.toString();
    String? docTypeVal = json['document'];
    
    // If document is null but DNI exists and starts with a letter, extract it.
    if (docTypeVal == null && dniVal != null && dniVal.length > 1) {
       final firstChar = dniVal[0].toUpperCase();
       if (['V', 'E', 'J', 'G'].contains(firstChar)) {
          docTypeVal = firstChar;
       }
    }

    return Player(
      userId: json['user_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: avatar ?? '',
      role: json['role'] ?? 'user',
      level: json['level'] ?? 1,
      experience: json['experience'] ?? 0,
      totalXP: json['total_xp'] ?? 0,
      completedCluesCount: json['completed_clues_count'] ?? json['completed_clues'] ?? 0,
      profession: json['profession'] ?? 'Novice',
      // [REF] Coins now prioritize active session (game_players) over global profile
      coins: () {
        // 1. Try to extract from nested game_players object
        if (json['game_players'] != null) {
          final gp = json['game_players'];
          if (gp is List && gp.isNotEmpty) return gp.first['coins'];
          if (gp is Map) return gp['coins'];
        }
        // 2. Fallback to direct field (handled by provider overwrite or legacy)
        return (json['total_coins'] is num 
          ? (json['total_coins'] as num).toInt() 
          : (json['coins'] is num 
              ? (json['coins'] as num).toInt() 
              : int.tryParse(json['coins']?.toString() ?? '300') ?? 300));
      }(),
      status: _parseStatus(json['status']),
      frozenUntil: json['frozen_until'] != null
          ? DateTime.parse(json['frozen_until'])
          : null,
      // [FIX] Parsear last_completion_time para desempate en Race Tracker
      lastCompletionTime: json['last_completion_time'] != null
          ? DateTime.tryParse(json['last_completion_time'])
          : null,
      stats: {
        'speed': json['stat_speed'] ?? 0,
        'strength': json['stat_strength'] ?? 0,
        'intelligence': json['stat_intelligence'] ?? 0,
      },
      eventsCompleted: json['events_completed'] != null
          ? List<String>.from(json['events_completed'])
          : [],
      inventory:
          json['inventory'] != null ? List<String>.from(json['inventory']) : [],
      gamePlayerId: json['player_id'] ?? json['game_player_id'],
      avatarId: avatarId,
      clovers: json['clovers'] ?? 0,
      documentType: docTypeVal,
      // Map 'dni' (int) from DB to 'cedula' (String) in model if 'cedula' is null
      cedula: dniVal,
      phone: json['phone'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      isProtected: json['is_protected'] ?? false,
      emailVerified: json['email_verified'] ?? true,
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
      case 'invisible': 
        return PlayerStatus.invisible;
      default:
        return PlayerStatus.active;
    }
  }

  int get experienceToNextLevel => (level * 100);

  double get experienceProgress => experience / experienceToNextLevel;

  bool get isInvisible => status == PlayerStatus.invisible;

  bool get isFrozen =>
      status == PlayerStatus.frozen &&
      (frozenUntil == null ||
          DateTime.now().toUtc().isBefore(frozenUntil!.toUtc()));

  // SHIELDED STATE NOW DEPENDS ON isProtected flag
  bool get isShielded => isProtected;

  bool get isBlinded =>
      status == PlayerStatus.blinded &&
      (frozenUntil == null ||
          DateTime.now().toUtc().isBefore(frozenUntil!.toUtc()));

  bool get isSlowed =>
      status == PlayerStatus.slowed &&
      (frozenUntil == null ||
          DateTime.now().toUtc().isBefore(frozenUntil!.toUtc()));

  // Validation for payment profile
  bool get hasCompletePaymentProfile =>
      cedula != null &&
      cedula!.isNotEmpty &&
      phone != null &&
      phone!.isNotEmpty;

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
  
  // --- ITargetable Implementation ---
  
  // Imprime gamePlayerId como ID principal para el sistema de targeting
  @override
  String get id => gamePlayerId ?? userId; 

  @override
  String? get label => name;

  @override
  double get progress => completedCluesCount.toDouble(); 

  @override
  bool get isSelectable => status == PlayerStatus.active || isProtected || status == PlayerStatus.slowed;
  
  @override
  String get avatarUrl => _avatarUrl;


  Player copyWith({
    String? userId,
    String? name,
    String? email,
    String? avatarUrl,
    String? role,
    int? level,
    int? experience,
    int? totalXP,
    int? completedCluesCount,
    String? profession,
    int? coins,
    List<String>? inventory,
    PlayerStatus? status,
    DateTime? frozenUntil,
    DateTime? lastCompletionTime,
    List<String>? eventsCompleted,
    int? lives,
    int? clovers,
    Map<String, dynamic>? stats,
    String? gamePlayerId,
    String? avatarId,
    String? currentEventId,
    String? cedula,
    String? phone,
    String? documentType,
    DateTime? createdAt,
    bool? isProtected,
    bool? emailVerified,
  }) {
    return Player(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? _avatarUrl,
      role: role ?? this.role,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      totalXP: totalXP ?? this.totalXP,
      completedCluesCount: completedCluesCount ?? this.completedCluesCount,
      profession: profession ?? this.profession,
      coins: coins ?? this.coins,
      inventory: inventory ?? this.inventory,
      status: status ?? this.status,
      frozenUntil: frozenUntil ?? this.frozenUntil,
      lastCompletionTime: lastCompletionTime ?? this.lastCompletionTime,
      eventsCompleted: eventsCompleted ?? this.eventsCompleted,
      lives: lives ?? this.lives,
      clovers: clovers ?? this.clovers,
      stats: stats ?? this.stats,
      gamePlayerId: gamePlayerId ?? this.gamePlayerId,
      avatarId: avatarId ?? this.avatarId,
      currentEventId: currentEventId ?? this.currentEventId,
      cedula: cedula ?? this.cedula,
      phone: phone ?? this.phone,
      documentType: documentType ?? this.documentType,
      createdAt: createdAt ?? this.createdAt,
      isProtected: isProtected ?? this.isProtected,
      emailVerified: emailVerified ?? this.emailVerified,
    );
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
  invisible, 
}
