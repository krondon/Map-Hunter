import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

/// Provider for player inventory management.
/// 
/// Extracted from PlayerProvider to follow SRP.
/// Handles powers, consumables, and purchase operations.
class PlayerInventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService;

  // Inventory state
  List<String> _inventory = []; // Slug-based inventory
  Map<String, int> _powerCounts = {}; // slug -> count
  
  // Event-scoped inventories for store validation
  // Structure: { eventId: { powerId: quantity } }
  final Map<String, Map<String, int>> _eventInventories = {};
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentEventId;
  String? _currentUserId;

  PlayerInventoryProvider({required InventoryService inventoryService})
      : _inventoryService = inventoryService;

  // --- Getters ---
  List<String> get inventory => _inventory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPowers => _inventory.isNotEmpty;
  String? get currentEventId => _currentEventId;
  String? get currentUserId => _currentUserId;
  Map<String, Map<String, int>> get eventInventories => _eventInventories;

  /// Get count of a specific power by slug/id.
  int getPowerCount(String itemSlug) {
    return _powerCounts[itemSlug] ?? 0;
  }

  /// Get count of a specific power in a specific event.
  /// Used for store validation.
  int getPowerCountForEvent(String itemId, String eventId) {
    return _eventInventories[eventId]?[itemId] ?? 0;
  }

  /// Check if player has a specific power.
  bool hasPower(String powerSlug) {
    return (_powerCounts[powerSlug] ?? 0) > 0;
  }

  // --- Context Management ---

  /// Update the user/event context.
  /// Called by PlayerProvider when context changes.
  void updateContext({required String userId, required String eventId}) {
    final contextChanged = _currentUserId != userId || _currentEventId != eventId;
    _currentUserId = userId;
    _currentEventId = eventId;
    
    if (contextChanged) {
      debugPrint('[InventoryProvider] Context updated: userId=$userId, eventId=$eventId');
      // Optionally fetch inventory on context change
      // fetchInventory();
    }
  }

  /// Initialize inventory for a user in an event.
  Future<void> initialize({
    required String userId,
    required String eventId,
  }) async {
    _currentUserId = userId;
    _currentEventId = eventId;
    await fetchInventory();
  }

  // --- Inventory Operations ---

  /// Fetch current inventory from service.
  Future<void> fetchInventory() async {
    if (_currentUserId == null || _currentEventId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _inventoryService.fetchInventoryByEvent(
        userId: _currentUserId!,
        eventId: _currentEventId!,
      );

      _inventory = result.inventoryList;
      _powerCounts = result.eventItems;
      
      // Store event-scoped inventory for store validation
      _eventInventories[_currentEventId!] = result.eventItems;

      debugPrint('[InventoryProvider] Loaded ${_inventory.length} items for event $_currentEventId');
    } catch (e) {
      _errorMessage = 'Error cargando inventario: $e';
      debugPrint('[InventoryProvider] Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch inventory for a specific event without changing context.
  Future<void> fetchInventoryForEvent(String userId, String eventId) async {
    try {
      final result = await _inventoryService.fetchInventoryByEvent(
        userId: userId,
        eventId: eventId,
      );

      // Store event-scoped inventory for store validation
      _eventInventories[eventId] = result.eventItems;

      // If this is our current event, also update main state
      if (eventId == _currentEventId) {
        _inventory = result.inventoryList;
        _powerCounts = result.eventItems;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InventoryProvider] Error fetching event inventory: $e');
    }
  }

  // --- Purchase Operations ---

  /// Purchase an item from the store.
  /// 
  /// Returns true if purchase was successful.
  /// Note: For extra_life, use purchaseExtraLife instead.
  Future<bool> purchaseItem({
    required String itemId,
    required String eventId,
    required int cost,
    bool isPower = true,
  }) async {
    if (_currentUserId == null) return false;

    try {
      final result = await _inventoryService.purchaseItem(
        userId: _currentUserId!,
        eventId: eventId,
        itemId: itemId,
        cost: cost,
        isPower: isPower,
      );

      if (result.success) {
        // Update local state
        await fetchInventoryForEvent(_currentUserId!, eventId);
        debugPrint('[InventoryProvider] Purchased $itemId successfully');
      }
      
      return result.success;
    } catch (e) {
      debugPrint('[InventoryProvider] Error purchasing item: $e');
      rethrow;
    }
  }

  /// Purchase an extra life.
  /// 
  /// Returns the new lives count, or null if failed.
  Future<int?> purchaseExtraLife({
    required String eventId,
    required int cost,
  }) async {
    if (_currentUserId == null) return null;

    try {
      final result = await _inventoryService.purchaseExtraLife(
        userId: _currentUserId!,
        eventId: eventId,
        cost: cost,
      );

      if (result.success) {
        debugPrint('[InventoryProvider] Extra life purchased, new lives: ${result.newLives}');
        return result.newLives;
      }
      
      return null;
    } catch (e) {
      debugPrint('[InventoryProvider] Error purchasing extra life: $e');
      return null;
    }
  }

  // --- Sync Operations ---

  /// Sync inventory with real data from backend.
  /// 
  /// Returns the sync result with gamePlayerId, lives, and inventory.
  Future<SyncInventoryResult> syncRealInventory() async {
    if (_currentUserId == null) {
      return SyncInventoryResult.empty();
    }
    
    try {
      final result = await _inventoryService.syncRealInventory(
        userId: _currentUserId!,
      );
      
      if (result.success) {
        _inventory = result.inventory;
        _powerCounts = {};
        for (final slug in _inventory) {
          _powerCounts[slug] = (_powerCounts[slug] ?? 0) + 1;
        }
        notifyListeners();
        debugPrint('[InventoryProvider] Synced ${_inventory.length} items');
      }
      
      return result;
    } catch (e) {
      debugPrint('[InventoryProvider] Error syncing: $e');
      return SyncInventoryResult.empty();
    }
  }

  /// Consume a power from inventory.
  Future<bool> consumePower(String powerSlug) async {
    final count = _powerCounts[powerSlug] ?? 0;
    if (count <= 0) return false;

    // Optimistic update
    _powerCounts[powerSlug] = count - 1;
    _inventory.remove(powerSlug);
    notifyListeners();

    // Sync with backend handled elsewhere
    return true;
  }

  /// Add a power to local inventory (after purchase).
  void addPower(String powerSlug) {
    _inventory.add(powerSlug);
    _powerCounts[powerSlug] = (_powerCounts[powerSlug] ?? 0) + 1;
    notifyListeners();
  }

  /// Update inventory from external source (e.g., PlayerProvider sync).
  void updateInventory(List<String> newInventory) {
    _inventory = List.from(newInventory);
    _powerCounts = {};
    for (final slug in _inventory) {
      _powerCounts[slug] = (_powerCounts[slug] ?? 0) + 1;
    }
    notifyListeners();
  }

  /// Clear inventory state.
  void clear() {
    _inventory = [];
    _powerCounts = {};
    _eventInventories.clear();
    _currentUserId = null;
    _currentEventId = null;
    _errorMessage = null;
    notifyListeners();
  }
}
