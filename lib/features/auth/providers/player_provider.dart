import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mall/models/power_item.dart';
import '../../../shared/models/player.dart';
import '../../../shared/interfaces/i_resettable.dart';
import '../../game/providers/power_effect_provider.dart';
import '../../game/providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/power_service.dart';
import '../../admin/services/admin_service.dart';

enum PowerUseResult { success, reflected, error, blocked }

  /// Core Player Provider - Handles player identity, session, and coordination.
/// 
/// After SRP refactoring:
/// - Inventory operations are handled by [PlayerInventoryProvider]
/// - Stats/Lives operations are handled by [PlayerStatsProvider]
/// - This provider focuses on: Auth, Profile, Avatar, Session management
/// 
/// Public API remains unchanged for backward compatibility.
class PlayerProvider extends ChangeNotifier implements IResettable {
  Player? _currentPlayer;
  List<Player> _allPlayers = [];
  final SupabaseClient _supabase;
  
  // Services (DIP)
  final AuthService _authService;
  final AdminService _adminService;
  final InventoryService _inventoryService;
  final PowerService _powerService;

  // Event-scoped inventories (kept for backward compatibility)
  final Map<String, Map<String, int>> _eventInventories = {};

  bool _isProcessing = false;
  bool _isLoggingOut = false;
  bool _isDisposed = false;
  StreamSubscription? _gamePlayersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  Timer? _pollingTimer;
  
  List<PowerItem> _shopItems = PowerItem.getShopItems();
  
  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;
  bool get isLoggedIn => _currentPlayer != null;
  List<PowerItem> get shopItems => _shopItems;

  String? _banMessage;
  String? get banMessage => _banMessage;

  /// Constructor with dependency injection.
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

  /// Get power count for a specific event.
  int getPowerCount(String itemId, String eventId) {
    return _eventInventories[eventId]?[itemId] ?? 0;
  }
  
  /// Update local lives without backend sync.
  void updateLocalLives(int newLives) {
    if (_currentPlayer != null) {
      _currentPlayer = _currentPlayer!.copyWith(lives: newLives);
      notifyListeners();
    }
  }

  /// Set current event context for profile sync.
  Future<void> setCurrentEventContext(String eventId) async {
    if (_currentPlayer == null) return;
    
    debugPrint('PlayerProvider: Setting current event context to $eventId');
    
    if (_currentPlayer!.currentEventId == eventId) {
      return;
    }

    await _fetchProfile(_currentPlayer!.userId, eventId: eventId);
  }

  /// Load shop items configuration from service.
  Future<void> loadShopItems() async {
    try {
      final configs = await _powerService.getPowerConfigs();
      
      _shopItems = _shopItems.map((item) {
          final matches = configs.where((d) => d['slug'] == item.id);
          final config = matches.isNotEmpty ? matches.first : null;

          if (config != null) {
            final int duration = (config['duration'] as num?)?.toInt() ?? 0;
            
            String newDesc = item.description;
            if (duration > 0) {
              newDesc = newDesc.replaceAll(RegExp(r'\b\d+\s*s\b'), '${duration}s');
            }

            return item.copyWith(
              durationSeconds: duration,
              description: newDesc,
            );
          }
          return item;
        }).toList();
        
        notifyListeners();
    } catch (e) {
      debugPrint("PlayerProvider: Error loading shop items: $e");
    }
  }

  // ============================================================
  // AUTHENTICATION (delegated to AuthService)
  // ============================================================

  Future<void> login(String email, String password) async {
    try {
      final userId = await _authService.login(email, password);
      await _fetchProfile(userId);
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }

  Future<void> register(String name, String email, String password, {String? cedula, String? phone}) async {
    try {
      final userId = await _authService.register(name, email, password, cedula: cedula, phone: phone);
      await _fetchProfile(userId);
    } catch (e) {
      debugPrint('Error registering: $e');
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _authService.updatePassword(newPassword);
    } catch (e) {
      debugPrint('Error updating password: $e');
      rethrow;
    }
  }

  Future<void> updateAvatar(String avatarId) async {
    if (_currentPlayer == null) return;
    try {
      // 1. Cache locally for immediate and offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_avatar_${_currentPlayer!.userId}', avatarId);
      debugPrint('PlayerProvider: Avatar $avatarId cached locally');

      // 2. Update DB
      await _authService.updateAvatar(_currentPlayer!.userId, avatarId);
      
      // 3. Update memory and notify
      _currentPlayer = _currentPlayer!.copyWith(avatarId: avatarId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating avatar: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({String? name, String? email}) async {
    if (_currentPlayer == null) return;
    try {
      await _authService.updateProfile(_currentPlayer!.userId, name: name, email: email);
      
      // Actualizar localmente
      if (name != null) {
        _currentPlayer = _currentPlayer!.copyWith(name: name);
      }
      if (email != null) {
        _currentPlayer = _currentPlayer!.copyWith(email: email);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile in provider: $e');
      rethrow;
    }
  }

  Future<void> logout({bool clearBanMessage = true}) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    // Use centralized AuthService logout which triggers callbacks
    await _authService.logout();
    
    // Note: Local reset() will be called via callback registered in main.dart
    // But we keep basic cleanup locally for safety if not registered
    
    if (clearBanMessage) {
      _banMessage = null;
    }
    
    _isLoggingOut = false;
  }

  /// Global Reset: Clears all user session data
  /// Implementación de IResettable
  @override
  void resetState() {
    _pollingTimer?.cancel();
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _gamePlayersSubscription?.cancel();
    _gamePlayersSubscription = null;

    _currentPlayer = null;
    _eventInventories.clear();
    // _banMessage is optional to clear depending on UX, usually yes on logout
    // But we might want to show WHY they were logged out. 
    // For now, clear it.
    _banMessage = null;
    
    notifyListeners();
  }

  /// Clears the current player's inventory list explicitly.
  /// Used to prevent ghost data when switching events.
  void clearCurrentInventory() {
    if (_currentPlayer != null) {
      _currentPlayer!.inventory = [];
      debugPrint('PlayerProvider: Inventory cleared for context switch.');
      notifyListeners();
    }
  }

  // ============================================================
  // INVENTORY OPERATIONS (delegated to InventoryService)
  // ============================================================

  /// Fetch inventory for user in an event.
  Future<void> fetchInventory(String userId, String eventId) async {
    try {
      final result = await _inventoryService.fetchInventoryByEvent(
        userId: userId,
        eventId: eventId,
      );

      _eventInventories[eventId] = result.eventItems;

      if (_currentPlayer != null) {
        _currentPlayer!.inventory = result.inventoryList;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching event inventory: $e');
    }
  }

  /// Purchase item from store.
  Future<bool> purchaseItem(String itemId, String eventId, int cost,
      {bool isPower = true}) async {
    if (_currentPlayer == null) return false;

    // Special handling for extra lives
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

  /// Developer Method: Purchase all powers up to max limit (3)
  /// Returns a summary string of what was bought or if failed.
  Future<String> purchaseFullStock(String eventId) async {
    if (_currentPlayer == null) return "No player";
    
    int totalCost = 0;
    Map<PowerItem, int> toBuy = {};
    const int maxPerItem = 3;

    // 1. Calculate what is needed
    for (final item in _shopItems) {
      // Skip utility/non-powers if needed, but user said "all powers"
      // Assuming 'extra_life' is also desirable, or filter if strictly powers.
      // Based on ShopScreen logic: bool isPower = item.type != PowerType.utility && item.id != 'extra_life';
      // But let's buy EVERYTHING that is displayed in the shop.
      
      // Get current count
      int currentCount = 0;
      bool isPower = item.type != PowerType.utility && item.id != 'extra_life';
      
      if (isPower) {
        currentCount = getPowerCount(item.id, eventId);
      } else if (item.id == 'extra_life') {
        currentCount = _currentPlayer!.lives;
      }
      
      // Calculate needed
      int needed = maxPerItem - currentCount;
      if (needed > 0) {
        toBuy[item] = needed;
        totalCost += (item.cost * needed);
      }
    }

    if (toBuy.isEmpty) {
      return "¡Ya tienes todo al máximo!";
    }

    // 2. Check funds
    if ((_currentPlayer!.coins) < totalCost) {
      return "Faltan monedas. Costo: $totalCost, Tienes: ${_currentPlayer!.coins}";
    }

    // 3. Execute purchases
    // We do this sequentially to ensure stability, though parallel could work if DB handles it.
    // For safety and simpler error handling, sequential.
    int successCount = 0;
    
    try {
      for (final entry in toBuy.entries) {
        final item = entry.key;
        final qty = entry.value;
        final bool isPower = item.type != PowerType.utility && item.id != 'extra_life';

        for (int i = 0; i < qty; i++) {
           final success = await purchaseItem(item.id, eventId, item.cost, isPower: isPower);
           if (success) successCount++;
        }
      }
      
      return "Compra masiva completada. Items comprados: $successCount por $totalCost monedas.";
    } catch (e) {
      return "Error durante la compra masiva: $e";
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

  /// Sync real inventory from backend.
  Future<void> syncRealInventory({PowerEffectProvider? effectProvider}) async {
    if (_currentPlayer == null) {
      debugPrint('[DEBUG] ❌ syncRealInventory: _currentPlayer is NULL');
      return;
    }

    try {
      final eventId = _currentPlayer!.currentEventId;
      debugPrint('[DEBUG] 🔄 syncRealInventory START');
      debugPrint('[DEBUG]    userId: ${_currentPlayer!.userId}');
      debugPrint('[DEBUG]    eventId: $eventId');
      debugPrint('[DEBUG]    effectProvider is null? ${effectProvider == null}');

      final result = await _inventoryService.syncRealInventory(
        userId: _currentPlayer!.userId,
        eventId: eventId,
      );

      debugPrint('[DEBUG] 📦 syncRealInventory result:');
      debugPrint('[DEBUG]    success: ${result.success}');
      debugPrint('[DEBUG]    gamePlayerId: ${result.gamePlayerId}');
      debugPrint('[DEBUG]    lives: ${result.lives}');

      if (!result.success) {
        debugPrint('[DEBUG] ⚠️ No active game_player found');
        _currentPlayer!.inventory.clear();
        _currentPlayer!.gamePlayerId = null;
        effectProvider?.startListening(null);
        notifyListeners();
        return;
      }

      if (result.lives != null) {
        _currentPlayer!.lives = result.lives!;
      }
      
      _currentPlayer!.gamePlayerId = result.gamePlayerId;
      
      // Configure PowerEffectProvider
      debugPrint('[DEBUG] 🎯 Configuring PowerEffectProvider...');
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
      
      debugPrint('[DEBUG] 📡 Calling startListening with gamePlayerId: ${result.gamePlayerId}');
      effectProvider?.startListening(result.gamePlayerId);
      
      debugPrint("GamePlayer found: ${result.gamePlayerId}");

      _currentPlayer!.inventory.clear();
      _currentPlayer!.inventory.addAll(result.inventory);
      notifyListeners();
    } catch (e) {
      debugPrint('CRITICAL Error syncing real inventory: $e');
    }
  }

  // ============================================================
  // POWER USAGE (delegated to PowerService)
  // ============================================================

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
      effectProvider.setManualCasting(true);

      // Prepare rivals list for blur_screen
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

      
      // Determine if this power is a self-buff that is already active
      final isDefensive = ['shield', 'invisibility', 'return'].contains(powerSlug);
      final isAlreadyActive = isDefensive && effectProvider.isEffectActive(powerSlug);

      final response = await _powerService.executePower(
        casterGamePlayerId: casterGamePlayerId,
        targetGamePlayerId: targetGamePlayerId,
        powerSlug: powerSlug,
        rivals: rivals,
        eventId: eventId,
        isAlreadyActive: isAlreadyActive, 
      );
      
      if (response.blockedByShield) {
        // [SHIELD FEEDBACK] The attack was executed but blocked.
        effectProvider.notifyAttackBlocked();
        // We might want to refresh profile to sync ammo usage.
        await syncRealInventory(effectProvider: effectProvider);
        return PowerUseResult.blocked;
      }

      switch (response.result) {
        case PowerUseResultType.reflected:
          if (powerSlug != 'return' && !effectProvider.isReturnArmed) {
            effectProvider.notifyPowerReturned(response.returnedByName ?? 'Un rival');
          }
          await refreshProfile();
          return PowerUseResult.reflected;

        case PowerUseResultType.success:
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
      debugPrint('Error using power: $e');
      rethrow;
    } finally {
      effectProvider.setManualCasting(false);
      _isProcessing = false;
    }
  }

  // ============================================================
  // PROFILE MANAGEMENT
  // ============================================================

  Future<void> refreshProfile({String? eventId}) async {
    if (_currentPlayer != null) {
      await _fetchProfile(_currentPlayer!.userId, eventId: eventId);
    }
  }

  Future<void> _fetchProfile(String userId, {String? eventId}) async {
    try {
      // 1. Fetch basic profile
      final profileData =
          await _supabase.from('profiles').select().eq('id', userId).single();
      debugPrint('PlayerProvider: Raw profile data from DB: $profileData');

      // 2. Fetch GamePlayer and Lives
      final targetEventId = eventId ?? _currentPlayer?.currentEventId;
      
      final baseQuery = _supabase
          .from('game_players')
          .select('id, lives, status, event_id')
          .eq('user_id', userId);
      
      Map<String, dynamic>? gpData;
      
      if (targetEventId != null) {
        debugPrint("PlayerProvider: Fetching profile for TARGET event: $targetEventId");
        gpData = await baseQuery.eq('event_id', targetEventId).maybeSingle();
      } else if (_currentPlayer?.gamePlayerId != null) {
        debugPrint("PlayerProvider: No target event, maintaining SESSION: ${_currentPlayer!.gamePlayerId}");
        gpData = await _supabase
            .from('game_players')
            .select('id, lives, status, event_id')
            .eq('id', _currentPlayer!.gamePlayerId!)
            .maybeSingle();
      } else {
        debugPrint("PlayerProvider: No context. Fetching LATEST joined event.");
        gpData = await baseQuery.order('joined_at', ascending: false).limit(1).maybeSingle();
      }

      List<String> realInventory = [];
      int actualLives = 3;
      String? gamePlayerId;
      String? fetchedEventId;

      if (gpData != null) {
        fetchedEventId = gpData['event_id'] as String?;
        
        final status = gpData['status'] as String?;
        debugPrint("[PlayerProvider] Profile Status='${profileData['status']}', GamePlayer Status='$status', EventId='$fetchedEventId'");
        
        if (status == 'suspended' || status == 'banned') {
          debugPrint('PlayerProvider: User is $status from event $fetchedEventId. Invalidating session.');
          gpData = null;
          fetchedEventId = null;
        } else {
          actualLives = gpData['lives'] ?? 3;
          final String gpId = gpData['id'];
          gamePlayerId = gpId;
        }
      }

      // Fetch inventory if we have a valid, non-suspended game player
      if (gpData != null && gamePlayerId != null) {
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

      // 4. Build player atomically
      final Player newPlayer = Player.fromJson(profileData);
      
      // Local cache recovery for avatar
      if (newPlayer.avatarId == null || newPlayer.avatarId!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final localAvatar = prefs.getString('cached_avatar_$userId');
        if (localAvatar != null && localAvatar.isNotEmpty) {
           debugPrint('PlayerProvider: Recovering avatar $localAvatar from local cache');
           newPlayer.avatarId = localAvatar;
        }
      }

      newPlayer.lives = actualLives;
      newPlayer.inventory = realInventory;
      newPlayer.gamePlayerId = gamePlayerId;
      newPlayer.currentEventId = fetchedEventId;

      // Check ban BEFORE notifying a "valid" state
      if (newPlayer.status == PlayerStatus.banned) {
         debugPrint("BANNED user detected in realtime. Logging out...");
         _banMessage = 'Has sido baneado por un administrador.';
         await logout(clearBanMessage: false);
         return; 
      }

      _currentPlayer = newPlayer;
      debugPrint('🔍 PlayerProvider: notifyListeners(). gamePlayerId: ${_currentPlayer?.gamePlayerId}, eventId: ${_currentPlayer?.currentEventId}');
      notifyListeners();

      // Check pending penalties from previous disconnections
      unawaited(_checkPendingPenalties(userId));

      // Ensure listeners are running (only once)
      _startListeners(userId);
      _subscribeToGamePlayers(userId);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _checkPendingPenalties(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pending_life_loss') == true) {
        final eventId = prefs.getString('pending_life_loss_event');
        debugPrint('PlayerProvider: Processing pending penalty for $userId');
        
        await loseLife(eventId: eventId);
        
        await prefs.remove('pending_life_loss');
        await prefs.remove('pending_life_loss_event');
        debugPrint('PlayerProvider: Pending penalty applied successfully');
      }
    } catch (e) {
      debugPrint('Error consuming penalty: $e');
    }
  }

  void _startListeners(String userId) {
    _startPolling(userId);
    if (_profileSubscription == null) _subscribeToProfile(userId);
  }

  void _startPolling(String userId) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_currentPlayer != null && _currentPlayer!.userId == userId) {
        try {
          await _checkPlayerStatus(userId);
        } catch (e) {
          // Ignore polling errors
        }
      } else {
        timer.cancel();
        _pollingTimer = null;
      }
    });
  }

  Future<void> _checkPlayerStatus(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('status')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final String statusStr = response['status'] ?? 'active';
        if (statusStr == 'banned' && _currentPlayer?.status != PlayerStatus.banned) {
           debugPrint("Polling detected BAN. Forcing update...");
           await refreshProfile();
           return;
        }
      }

      // Detect reset (lost event registration)
      if (_currentPlayer?.gamePlayerId != null) {
        final gpRes = await _supabase
            .from('game_players')
            .select('id')
            .eq('id', _currentPlayer!.gamePlayerId!)
            .maybeSingle();
        
        if (gpRes == null) {
          debugPrint("Polling detected RESET (registration disappeared).");
          await refreshProfile();
        }
      }
    } catch (e) {
      // Ignore status check errors
    }
  }

  void _subscribeToProfile(String userId) {
    if (_profileSubscription != null) return;

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            debugPrint("Stream Profile Update: ${data.first['status']}");
            _fetchProfile(userId);
          }
        }, onError: (e) {
          debugPrint('Profile stream error: $e');
          _profileSubscription = null;
        });
  }

  void _subscribeToGamePlayers(String userId) {
    if (_gamePlayersSubscription != null) return;

    debugPrint('🔊 PlayerProvider: Subscribing to game_players STREAM for user $userId');
    
    _gamePlayersSubscription = _supabase
        .from('game_players')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          debugPrint('🔊 PlayerProvider: ⚡ STREAM UPDATE received in game_players! (${data.length} rows)');
          
          bool banDetectedForCurrentEvent = false;
          final currentEventId = _currentPlayer?.currentEventId;

          for (final gp in data) {
            final String? status = gp['status'];
            final String? eventId = gp['event_id'];
            
            if (eventId == currentEventId && (status == 'suspended' || status == 'banned')) {
               debugPrint('🚫 PlayerProvider: BAN detected for current event ($eventId) via Stream!');
               banDetectedForCurrentEvent = true;
               break;
            }
          }

          if (!_isDisposed && _currentPlayer != null) {
            if (banDetectedForCurrentEvent) {
              _currentPlayer!.gamePlayerId = null;
              _currentPlayer!.status = PlayerStatus.banned;
              debugPrint('🔍 PlayerProvider: Invalidating local session (INSTANT BAN).');
              notifyListeners();
            } else {
              refreshProfile();
            }
          }
        }, onError: (error) {
          debugPrint('❌ PlayerProvider: Error in game_players STREAM: $error');
          _gamePlayersSubscription = null;
        });
  }

  // ============================================================
  // LIVES MANAGEMENT
  // ============================================================

  Future<void> loseLife({String? eventId}) async {
    if (_currentPlayer == null) return;
    if (_currentPlayer!.lives <= 0) return;

    try {
      final params = <String, dynamic>{
        'p_user_id': _currentPlayer!.userId,
      };
      if (eventId != null && eventId.isNotEmpty) {
        params['p_event_id'] = eventId;
      }

      final int newLives = await _supabase.rpc('lose_life', params: params);
      debugPrint("DEBUG: lose_life RPC result: newLives=$newLives");

      _currentPlayer!.lives = newLives;
      notifyListeners();
    } catch (e) {
      debugPrint("Error losing life: $e");
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
      debugPrint("Error resetting lives: $e");
    }
  }

  // ============================================================
  // ADMIN FUNCTIONS (delegated to AdminService)
  // ============================================================

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

  // ============================================================
  // DEBUG FUNCTIONS
  // ============================================================

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
      debugPrint("DEBUG: Power $powerSlug added.");
    } catch (e) {
      debugPrint("Error in debugAddPower: $e");
    }
  }

  Future<void> debugToggleStatus(String status) async {
    if (_currentPlayer == null) return;
    try {
      final newStatus =
          _currentPlayer!.status.name == status ? 'active' : status;

      await _supabase.from('profiles').update({
        'status': newStatus,
      }).eq('id', _currentPlayer!.userId);

      await refreshProfile();
      debugPrint("DEBUG: Status changed to $newStatus");
    } catch (e) {
      debugPrint("Error in debugToggleStatus: $e");
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
