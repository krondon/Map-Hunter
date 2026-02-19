import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mall/models/power_item.dart';
import '../../../shared/models/player.dart';
import '../../../shared/interfaces/i_resettable.dart';
import '../../game/providers/power_effect_provider.dart';
import '../../game/providers/power_interfaces.dart';
import '../../game/providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';
import '../services/power_service.dart';
import '../../admin/services/admin_service.dart';
import '../../game/strategies/power_response.dart';

enum PowerUseResult {
  success,
  reflected,
  error,
  blocked,
  gameFinished,
  targetFinished,
  gifted
}

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
  bool _isSpectatorSession = false; // NEW: Flag for spectator mode choice
  bool _isDarkMode = false; // Global theme state

  List<PowerItem> _shopItems = PowerItem.getShopItems();

  Player? get currentPlayer => _currentPlayer;
  List<Player> get allPlayers => _allPlayers;
  bool get isLoggedIn => _currentPlayer != null;
  List<PowerItem> get shopItems => _shopItems;
  bool get isDarkMode => _isDarkMode;

  String? _banMessage;
  String? get banMessage => _banMessage;

  // Error handling for powers
  String? _lastPowerError;
  String? get lastPowerError => _lastPowerError;

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

  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
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

  /// Update local coins without backend sync (Optimistic UI).
  void updateLocalCoins(int newCoins) {
    if (_currentPlayer != null) {
      _currentPlayer = _currentPlayer!.copyWith(coins: newCoins);
      notifyListeners();
    }
  }

  /// Update local clovers without backend sync (Optimistic UI).
  void updateLocalClovers(int newClovers) {
    if (_currentPlayer != null) {
      _currentPlayer = _currentPlayer!.copyWith(clovers: newClovers);
      notifyListeners();
    }
  }

  // Flag to prevent auto-reconnection after explicit exit
  bool _suppressAutoJoin = false;

  /// Set current event context for profile sync.
  Future<void> setCurrentEventContext(String eventId) async {
    if (_currentPlayer == null) return;

    debugPrint('PlayerProvider: Setting current event context to $eventId');

    if (_currentPlayer!.currentEventId == eventId) {
      return;
    }

    await _fetchProfile(_currentPlayer!.userId, eventId: eventId);
  }

  /// Reloads the current player's profile data (including wallet).
  Future<void> reloadProfile() async {
    if (_currentPlayer == null) return;
    await _fetchProfile(_currentPlayer!.userId,
        eventId: _currentPlayer!.currentEventId);
  }

  /// Load shop items configuration from service.
  /// Load shop items configuration from service.
  Future<void> loadShopItems() async {
    try {
      final configs = await _powerService.getPowerConfigs();

      // NEW: Fetch Spectator Prices if applicable
      Map<String, dynamic> spectatorPrices = {};
      if (_isSpectatorSession && _currentPlayer?.currentEventId != null) {
        spectatorPrices = await _powerService
            .getSpectatorConfig(_currentPlayer!.currentEventId!);
      }

      // Refresh base items to ensure clean slate
      _shopItems = PowerItem.getShopItems();

      _shopItems = _shopItems.map((item) {
        final matches = configs.where((d) => d['slug'] == item.id);
        final config = matches.isNotEmpty ? matches.first : null;

        // Base logic for duration updates
        int duration = item.durationSeconds;
        String newDesc = item.description;

        if (config != null) {
          duration = (config['duration'] as num?)?.toInt() ?? 0;
          if (duration > 0) {
            newDesc =
                newDesc.replaceAll(RegExp(r'\b\d+\s*s\b'), '${duration}s');
          }
        }

        // NEW: Spectator Price Override
        int finalCost = item.cost;
        if (_isSpectatorSession && spectatorPrices.containsKey(item.id)) {
          finalCost = (spectatorPrices[item.id] as num).toInt();
        }

        return item.copyWith(
          durationSeconds: duration,
          description: newDesc,
          cost: finalCost, // Apply override
        );
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
      await restoreSession(userId);
    } catch (e) {
      debugPrint('Error logging in: $e');
      rethrow;
    }
  }

  Future<void> register(String name, String email, String password,
      {String? cedula, String? phone}) async {
    try {
      final userId = await _authService.register(name, email, password,
          cedula: cedula, phone: phone);

      // Solo intentamos restaurar sesión si realmente tenemos una activa
      if (_supabase.auth.currentSession != null) {
        await restoreSession(userId);
      }
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
      await prefs.setString(
          'cached_avatar_${_currentPlayer!.userId}', avatarId);
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

  Future<void> updateProfile(
      {String? name, String? email, String? cedula, String? phone}) async {
    if (_currentPlayer == null) return;
    try {
      await _authService.updateProfile(
        _currentPlayer!.userId,
        name: name,
        email: email,
        cedula: cedula,
        phone: phone,
      );

      // Actualizar localmente
      _currentPlayer = _currentPlayer!.copyWith(
        name: name,
        email: email,
        cedula: cedula,
        phone: phone,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile in provider: $e');
      rethrow;
    }
  }

  Future<void> addPaymentMethod({required String bankCode}) async {
    try {
      await _authService.addPaymentMethod(bankCode: bankCode);
    } catch (e) {
      debugPrint('Error adding payment method in provider: $e');
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

  /// Elimina la cuenta del usuario permanentemente.
  Future<void> deleteAccount(String password) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    try {
      await _authService.deleteAccount(password);
      // El logout se maneja dentro del servicio, pero limpiamos estado local por si acaso
      resetState();
    } catch (e) {
      debugPrint('PlayerProvider: Error deleting account: $e');
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
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

  /// Explicitly clears the game context (gamePlayerId and currentEventId).
  /// This signals that the player has exited any active competition.
  void clearGameContext() {
    if (_currentPlayer != null) {
      debugPrint('PlayerProvider: 🧹 Clearing Game Context (Exiting Event)...');
      _currentPlayer!.gamePlayerId = null;
      _currentPlayer!.currentEventId = null;
      _currentPlayer!.lives = 3; // Reset lives visual to default/safe state
      notifyListeners();
    }
  }

  /// Cambia el rol localmente (usado para Modo Espectador).
  void setSpectatorRole(bool isSpectator) {
    _isSpectatorSession = isSpectator;
    if (_currentPlayer != null) {
      _currentPlayer =
          _currentPlayer!.copyWith(role: isSpectator ? 'spectator' : 'user');
      loadShopItems(); // Reload prices for new role
      notifyListeners();
    }
  }

  /// Registra al espectador en el evento como 'ghost player' con status spectator.
  /// Esto le permite tener un game_player_id para comprar y sabotear.
  Future<void> joinAsSpectator(String eventId) async {
    if (_currentPlayer == null) return;
    try {
      final userId = _currentPlayer!.userId;

      // 1. Verificar si ya tiene un record en este evento
      final existing = await _supabase
          .from('game_players')
          .select('id, status')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing == null) {
        // 2. Crear un ghost player
        await _supabase.from('game_players').insert({
          'user_id': userId,
          'event_id': eventId,
          'status': 'spectator',
          'lives': 0, // No juega, no tiene vidas
        });
        debugPrint(
            'PlayerProvider: Ghost player created for spectator $userId');
      } else if (existing['status'] == 'pending' ||
          existing['status'] == 'rejected') {
        // Si el usuario tenía una solicitud pendiente o rechazada, le permitimos ser espectador
        await _supabase.from('game_players').update(
            {'status': 'spectator', 'lives': 0}).eq('id', existing['id']);
        debugPrint(
            'PlayerProvider: Updated ${existing['status']} to spectator for user $userId');
      } else if (existing['status'] == 'banned' ||
          existing['status'] == 'suspended') {
        // CRITICAL: Banned/suspended users KEEP their status but can VIEW as spectators
        // We only clear their power effects so they can see the game without visual interference
        debugPrint(
            'PlayerProvider: Clearing power effects for ${existing['status']} user (status preserved)');
        try {
          await _supabase
              .from('active_power_effects')
              .delete()
              .eq('target_game_player_id', existing['id']);
          debugPrint(
              'PlayerProvider: ✅ Power effects cleared for ${existing['status']} user');
        } catch (e) {
          debugPrint('PlayerProvider: ⚠️ Error clearing power effects: $e');
        }
        // NOTE: We do NOT update the status. Banned users remain banned.
        debugPrint(
            'PlayerProvider: ${existing['status']} user can now view as spectator (status unchanged)');
      }

      // Refrescar perfil para cargar el gamePlayerId actualizado
      // NOTE: No llamamos clearGameContext() aquí porque causaría un bucle de rebuilds.
      // refreshProfile() se encargará de actualizar el estado correctamente.
      await refreshProfile(eventId: eventId);
    } catch (e) {
      debugPrint('PlayerProvider: Error joining as spectator: $e');
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
      final PurchaseResult result;

      if (_isSpectatorSession) {
        // Los espectadores usan el flujo manual para bypass de RPC restrictivo
        result = await _inventoryService.purchaseItemAsSpectator(
          userId: _currentPlayer!.userId,
          eventId: eventId,
          itemId: itemId,
          cost: cost,
        );
      } else {
        result = await _inventoryService.purchaseItem(
          userId: _currentPlayer!.userId,
          eventId: eventId,
          itemId: itemId,
          cost: cost,
          isPower: isPower,
          gamePlayerId: _currentPlayer!.gamePlayerId,
        );
      }

      if (result.success) {
        if (_isSpectatorSession) {
          // Espectadores pagan con tréboles (profiles.clovers)
          if (result.newClovers != null) {
            _currentPlayer!.clovers = result.newClovers!;
          } else {
            _currentPlayer!.clovers -= cost;
          }
        } else {
          // Jugadores activos pagan con monedas de sesión (game_players.coins)
          _currentPlayer!.coins -= cost;
        }
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
        final bool isPower =
            item.type != PowerType.utility && item.id != 'extra_life';

        for (int i = 0; i < qty; i++) {
          final success =
              await purchaseItem(item.id, eventId, item.cost, isPower: isPower);
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
  Future<void> syncRealInventory({PowerEffectManager? effectProvider}) async {
    if (_currentPlayer == null) {
      debugPrint('[DEBUG] ❌ syncRealInventory: _currentPlayer is NULL');
      return;
    }

    try {
      final eventId = _currentPlayer!.currentEventId;
      debugPrint('[DEBUG] 🔄 syncRealInventory START');
      debugPrint('[DEBUG]    userId: ${_currentPlayer!.userId}');
      debugPrint('[DEBUG]    eventId: $eventId');
      debugPrint(
          '[DEBUG]    effectProvider is null? ${effectProvider == null}');

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
      // REMOVED: Redundant and causes race condition (undoes optimistic update).
      // PowerEffectProvider manages its own state via startListening() stream.
      // effectProvider
      //    ?.setShielded(_currentPlayer!.status == PlayerStatus.shielded);
      // effectProvider?.configureReturnHandler - REMOVED: Return logic is now handled by strategies

      debugPrint(
          '[DEBUG] 📡 Calling startListening with gamePlayerId: ${result.gamePlayerId} and eventId: $eventId');
      effectProvider?.startListening(result.gamePlayerId, eventId: eventId);

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
    required PowerEffectManager effectProvider,
    GameProvider? gameProvider,
    bool allowReturnForward = true,
  }) async {
    if (_currentPlayer == null) {
      debugPrint('PlayerProvider: ❌ usePower aborted: _currentPlayer is NULL');
      return PowerUseResult.error;
    }
    if (_isProcessing) {
      debugPrint(
          'PlayerProvider: ⚠️ usePower aborted: _isProcessing is TRUE (Busy)');
      return PowerUseResult.error;
    }
    _isProcessing = true;
    _lastPowerError = null; // Reset error state
    debugPrint(
        'PlayerProvider: 🚀 usePower STARTED: $powerSlug -> $targetGamePlayerId');

    final casterGamePlayerId = _currentPlayer!.gamePlayerId;
    if (casterGamePlayerId == null || casterGamePlayerId.isEmpty) {
      debugPrint(
          'PlayerProvider: ❌ usePower aborted: casterGamePlayerId is NULL/Empty');
      _isProcessing = false;
      return PowerUseResult.error;
    }

    // --- RACE FINISHED CHECKS ---
    if (gameProvider != null) {
      debugPrint(
          'PlayerProvider: 🏁 Checking Race Status. Clues: ${_currentPlayer!.completedCluesCount} / ${gameProvider.totalClues}');
    }

    if (gameProvider != null && gameProvider.totalClues > 0) {
      // 1. Check if I (Caster) have finished
      if (_currentPlayer!.completedCluesCount >= gameProvider.totalClues) {
        debugPrint('PlayerProvider: 🛑 User finished race. Cannot use powers.');
        _isProcessing = false;
        return PowerUseResult.gameFinished;
      }

      // 2. Check if Target has finished
      // We need to find target in leaderboard to check their progress
      final targetPlayer = gameProvider.leaderboard.firstWhere(
        (p) =>
            p.gamePlayerId == targetGamePlayerId ||
            p.userId == targetGamePlayerId,
        orElse: () => Player(
            userId: 'unknown', name: 'Unknown', email: ''), // Dummy fallback
      );

      if (targetPlayer.userId != 'unknown' &&
          targetPlayer.completedCluesCount >= gameProvider.totalClues) {
        debugPrint(
            'PlayerProvider: 🛑 Target finished race. Cannot be targeted.');
        _isProcessing = false;
        return PowerUseResult.targetFinished;
      }
    }

    try {
      // --- EXCLUSIVITY CHECK ---
      // Fix: Only apply exclusivity check for DEFENSE powers when SELF-CASTING.
      // When gifting (caster != target), skip this check — server handles it.
      final isDefensivePower =
          ['shield', 'invisibility', 'return'].contains(powerSlug);
      final isSelfCast = casterGamePlayerId == targetGamePlayerId;

      if (isDefensivePower &&
          isSelfCast &&
          !effectProvider.canActivateDefensePower(powerSlug)) {
        debugPrint(
            'PlayerProvider: 🛑 Blocked usage of $powerSlug (Defense Exclusivity)');
        return PowerUseResult.error;
      }

      effectProvider.setManualCasting(true);

      // Prepare rivals list for blur_screen
      List<RivalInfo>? rivals;

      // Determine Event ID (Critical for Spectators and Broadcasts)
      String? eventId = _currentPlayer?.currentEventId;
      if (eventId == null && gameProvider != null) {
        eventId = gameProvider.currentEventId;
      }

      if (powerSlug == 'blur_screen' && gameProvider != null) {
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
      final isDefensive =
          ['shield', 'invisibility', 'return'].contains(powerSlug);
      final isAlreadyActive =
          isDefensive && effectProvider.isEffectActive(powerSlug);

      final response = await _powerService.executePower(
        casterGamePlayerId: casterGamePlayerId,
        targetGamePlayerId: targetGamePlayerId,
        powerSlug: powerSlug,
        rivals: rivals,
        eventId: eventId,
        isSpectator: _isSpectatorSession,
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
            effectProvider
                .notifyPowerReturned(response.returnedByName ?? 'Un rival');
          }
          await refreshProfile();
          return PowerUseResult.reflected;

        case PowerUseResultType.success:
          debugPrint("DEBUG: usePower success. Gifted? ${response.gifted}");
          if (response.gifted) {
            // No effects on self, just inventory sync
            await syncRealInventory(effectProvider: effectProvider);
            return PowerUseResult.gifted;
          }

          if (response.stealFailed) {
            effectProvider.notifyStealFailed();
          }
          if (powerSlug == 'shield') {
            effectProvider.setShielded(true, sourceSlug: powerSlug);
          }
          await syncRealInventory(effectProvider: effectProvider);
          return PowerUseResult.success;

        case PowerUseResultType.error:
        default:
          _lastPowerError =
              response.errorMessage ?? "Error desconocido tras ejecución";
          debugPrint(
              "PlayerProvider: ❌ Power Execution Error: $_lastPowerError");
          return PowerUseResult.error;
      }
    } catch (e) {
      _lastPowerError = "Excepción al usar poder: $e";
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

  /// Restores session by fetching profile AND auto-joining the user's latest event if applicable.
  /// This should ONLY be called on explicit Login or App Start.
  Future<void> restoreSession(String userId) async {
    await _fetchProfile(userId, restoreSessionContext: true);
    await _checkTutorialStatus();
  }

  /// Checks if the user is an existing legacy user and marks tutorials as seen.
  Future<void> _checkTutorialStatus() async {
    if (_currentPlayer == null || _currentPlayer!.createdAt == null) return;

    // FECHA DE CORTE: 12 de Febrero 2026
    // Usuarios creados ANTES de esta fecha se consideran "Veteranos" y no ven tutoriales.
    final cutoffDate = DateTime(2026, 2, 12);

    if (_currentPlayer!.createdAt!.isBefore(cutoffDate)) {
      debugPrint(
          "PlayerProvider: 🛡️ Legacy user detected (Created: ${_currentPlayer!.createdAt}). Marking tutorials as seen.");
      final prefs = await SharedPreferences.getInstance();

      final tutorialKeys = [
        'has_seen_tutorial_MODE_SELECTOR',
        'has_seen_tutorial_SCENARIOS',
        'has_seen_tutorial_CODE_FINDER',
        'has_seen_tutorial_CLUE_SCANNER',
        'has_seen_tutorial_HOME',
        'has_seen_tutorial_INVENTORY',
        'has_seen_tutorial_PUZZLE',
        'has_seen_tutorial_RANKING',
        'has_seen_tutorial_CLUES',
      ];

      for (var key in tutorialKeys) {
        if (!prefs.containsKey(key)) {
          await prefs.setBool(key, true);
        }
      }
    }
  }

  /// Internal fetch method.
  /// [restoreSessionContext] : If true, it attempts to find any active game participation to auto-join.
  /// If false (default), it strictly refreshes the CURRENT known context (or none).
  Future<void> _fetchProfile(String userId,
      {String? eventId, bool restoreSessionContext = false}) async {
    try {
      // 1. Fetch basic profile
      final profileData =
          await _supabase.from('profiles').select().eq('id', userId).single();
      debugPrint('PlayerProvider: Raw profile data from DB: $profileData');

      // 2. Determine which GamePlayer context to fetch (if any)
      //    We do NOT auto-guess unless restoreSessionContext is true

      final targetEventId = eventId ?? _currentPlayer?.currentEventId;
      final currentGpId = _currentPlayer?.gamePlayerId;

      final baseQuery = _supabase
          .from('game_players')
          .select('id, lives, coins, status, event_id')
          .eq('user_id', userId);

      Map<String, dynamic>? gpData;

      if (targetEventId != null) {
        // Option A: Specific Event requested or already Active
        debugPrint(
            "PlayerProvider: Fetching profile for TARGET/CURRENT event: $targetEventId");
        gpData = await baseQuery.eq('event_id', targetEventId).maybeSingle();
      } else if (currentGpId != null) {
        // Option B: No event ID, but we have a GamePlayer ID session
        debugPrint("PlayerProvider: Maintaining SESSION GP ID: $currentGpId");
        gpData = await _supabase
            .from('game_players')
            .select('id, lives, coins, status, event_id')
            .eq('id', currentGpId)
            .maybeSingle();
      } else if (restoreSessionContext) {
        // Option C: No context, but explicit restoration requested (Auto-Join latest)
        debugPrint(
            "PlayerProvider: RESTORING SESSION. Fetching LATEST joined event.");
        gpData = await baseQuery
            .order('joined_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } else {
        // Option D: No context, no specific request. (e.g. background polling while in Lobby)
        // Do NOT fetch GamePlayer data. Stay in Lobby mode.
        debugPrint(
            "PlayerProvider: No active context. Skipping GamePlayer fetch (Lobby Mode).");
        gpData = null;
      }

      List<String> realInventory = [];
      int actualLives = 3;
      int? actualCoins; // [REF] Session coins
      String? gamePlayerId;
      String? fetchedEventId;

      if (gpData != null) {
        fetchedEventId = gpData['event_id'] as String?;

        final status = gpData['status'] as String?;
        debugPrint(
            "[PlayerProvider] Profile Status='${profileData['status']}', GamePlayer Status='$status', EventId='$fetchedEventId'");

        if (status == 'suspended' || status == 'banned') {
          debugPrint(
              'PlayerProvider: User is $status from event $fetchedEventId. Invalidating session.');
          gpData = null;
          fetchedEventId = null;
        } else {
          actualLives = gpData['lives'] ?? 3;
          actualCoins = gpData['coins']; // May be null if column not filled yet
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
          debugPrint(
              'PlayerProvider: Recovering avatar $localAvatar from local cache');
          newPlayer.avatarId = localAvatar;
        }
      }

      newPlayer.lives = actualLives;
      if (actualCoins != null) {
        newPlayer.coins =
            actualCoins; // [REF] Overwrite global coins with session coins
      }
      newPlayer.inventory = realInventory;
      newPlayer.gamePlayerId = gamePlayerId;
      newPlayer.currentEventId = fetchedEventId;

      // Apply spectator session override
      Player finalPlayer = newPlayer;
      if (_isSpectatorSession) {
        finalPlayer = finalPlayer.copyWith(role: 'spectator');
      }

      // Check ban BEFORE notifying a "valid" state
      if (finalPlayer.status == PlayerStatus.banned) {
        debugPrint("BANNED user detected in realtime. Logging out...");
        _banMessage = 'Has sido baneado por un administrador.';
        await logout(clearBanMessage: false);
        return;
      }

      _currentPlayer = finalPlayer;
      // Reload prices for new event/role context
      loadShopItems();
      debugPrint(
          '🔍 PlayerProvider: notifyListeners(). gamePlayerId: ${_currentPlayer?.gamePlayerId}, eventId: ${_currentPlayer?.currentEventId}, role: ${_currentPlayer?.role}');
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
        if (statusStr == 'banned' &&
            _currentPlayer?.status != PlayerStatus.banned) {
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

    debugPrint(
        '🔊 PlayerProvider: Subscribing to game_players STREAM for user $userId');

    _gamePlayersSubscription = _supabase
        .from('game_players')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          debugPrint(
              '🔊 PlayerProvider: ⚡ STREAM UPDATE received in game_players! (${data.length} rows)');

          bool banDetectedForCurrentEvent = false;
          final currentEventId = _currentPlayer?.currentEventId;

          for (final gp in data) {
            final String? status = gp['status'];
            final String? eventId = gp['event_id'];

            if (eventId == currentEventId &&
                (status == 'suspended' || status == 'banned')) {
              debugPrint(
                  '🚫 PlayerProvider: BAN detected for current event ($eventId) via Stream!');
              banDetectedForCurrentEvent = true;
              break;
            }
          }

          if (!_isDisposed && _currentPlayer != null) {
            if (banDetectedForCurrentEvent) {
              _currentPlayer!.gamePlayerId = null;
              _currentPlayer!.status = PlayerStatus.banned;
              debugPrint(
                  '🔍 PlayerProvider: Invalidating local session (INSTANT BAN).');
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

  Future<void> toggleGameBanUser(
      String userId, String eventId, bool ban) async {
    debugPrint(
        'PlayerProvider: toggleGameBanUser CALLED. Delegating to AdminService...');
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
                newDesc =
                    newDesc.replaceAll(RegExp(r'\b\d+\s*s\b'), '${duration}s');
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

      Future<void> register(String name, String email, String password,
          {String? cedula, String? phone}) async {
        try {
          final userId = await _authService.register(name, email, password,
              cedula: cedula, phone: phone);
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
          await prefs.setString(
              'cached_avatar_${_currentPlayer!.userId}', avatarId);
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
          await _authService.updateProfile(_currentPlayer!.userId,
              name: name, email: email);

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
