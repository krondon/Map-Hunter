import 'package:flutter/material.dart';
import '../services/inventory_service.dart';

/// Provider for player inventory management.
/// 
/// Extracted from PlayerProvider to follow SRP.
/// Only handles powers and consumables inventory.
class PlayerInventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService;

  List<String> _inventory = []; // Slug-based inventory
  Map<String, int> _powerCounts = {}; // slug -> count
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

  /// Get count of a specific power by slug/id.
  int getPowerCount(String itemSlug) {
    return _powerCounts[itemSlug] ?? 0;
  }

  /// Check if player has a specific power.
  bool hasPower(String powerSlug) {
    return (_powerCounts[powerSlug] ?? 0) > 0;
  }

  // --- State Management ---

  /// Initialize inventory for a user in an event.
  Future<void> initialize({
    required String userId,
    required String eventId,
  }) async {
    _currentUserId = userId;
    _currentEventId = eventId;
    await fetchInventory();
  }

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

      debugPrint('[InventoryProvider] Loaded ${_inventory.length} items');
    } catch (e) {
      _errorMessage = 'Error cargando inventario: $e';
      debugPrint('[InventoryProvider] Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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

  /// Sync inventory with real data from backend.
  Future<void> syncFromBackend() async {
    if (_currentUserId == null) return;
    
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
      }
    } catch (e) {
      debugPrint('[InventoryProvider] Error syncing: $e');
    }
  }

  /// Clear inventory state.
  void clear() {
    _inventory = [];
    _powerCounts = {};
    _currentUserId = null;
    _currentEventId = null;
    _errorMessage = null;
    notifyListeners();
  }
}
