import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de obtener inventario por evento.
class InventoryResult {
  /// Mapa de itemId -> cantidad
  final Map<String, int> eventItems;
  /// Lista plana de items para la UI
  final List<String> inventoryList;

  InventoryResult({
    required this.eventItems,
    required this.inventoryList,
  });
}

/// Resultado de una compra.
class PurchaseResult {
  final bool success;
  final int? newCoins;
  final int? newLives;
  final String? errorMessage;

  PurchaseResult({
    required this.success,
    this.newCoins,
    this.newLives,
    this.errorMessage,
  });

  factory PurchaseResult.error(String message) => PurchaseResult(
        success: false,
        errorMessage: message,
      );
}

/// Resultado de sincronización de inventario real.
class SyncInventoryResult {
  final bool success;
  final String? gamePlayerId;
  final int? lives;
  final List<String> inventory;

  SyncInventoryResult({
    required this.success,
    this.gamePlayerId,
    this.lives,
    required this.inventory,
  });

  factory SyncInventoryResult.empty() => SyncInventoryResult(
        success: false,
        inventory: [],
      );
}

/// Servicio de inventario que encapsula la lógica de gestión de items y compras.
/// 
/// Implementa DIP al recibir [SupabaseClient] por constructor.
class InventoryService {
  final SupabaseClient _supabase;

  InventoryService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Obtiene el inventario de un usuario para un evento específico.
  /// 
  /// Llama al RPC `get_my_inventory_by_event`.
  Future<InventoryResult> fetchInventoryByEvent({
    required String userId,
    required String eventId,
  }) async {
    try {
      final List<dynamic> response = await _supabase.rpc(
        'get_my_inventory_by_event',
        params: {
          'p_user_id': userId,
          'p_event_id': eventId,
        },
      );

      final Map<String, int> eventItems = {};
      final List<String> inventoryList = [];

      for (var item in response) {
        // Usamos 'slug' en lugar de 'power_id' para coincidir con PowerItem.getShopItems()
        final String itemId = item['slug'] ?? item['power_id'].toString();
        final int qty = item['quantity'] ?? 0;

        eventItems[itemId] = qty;

        for (int i = 0; i < qty; i++) {
          inventoryList.add(itemId);
        }
      }

      return InventoryResult(
        eventItems: eventItems,
        inventoryList: inventoryList,
      );
    } catch (e) {
      debugPrint('InventoryService: Error fetching event inventory: $e');
      rethrow;
    }
  }

  /// Compra un item de la tienda.
  /// 
  /// Llama al RPC `buy_item`. Para vidas, usa `purchaseExtraLife()`.
  Future<PurchaseResult> purchaseItem({
    required String userId,
    required String eventId,
    required String itemId,
    required int cost,
    bool isPower = true,
    String? gamePlayerId,
  }) async {
    try {
      final params = {
        'p_user_id': userId,
        'p_event_id': eventId,
        'p_item_id': itemId,
        'p_cost': cost,
        'p_is_power': isPower,
      };
      
      if (gamePlayerId != null) {
        params['p_game_player_id'] = gamePlayerId;
      }

      await _supabase.rpc('buy_item', params: params);

      return PurchaseResult(success: true);
    } catch (e) {
      debugPrint('InventoryService: Error en compra (RPC): $e');
      rethrow;
    }
  }

  /// Compra manual para espectadores (bypass RPC buy_item que pide status active)
  Future<PurchaseResult> purchaseItemAsSpectator({
    required String userId,
    required String eventId,
    required String itemId,
    required int cost,
  }) async {
    try {
      // 1. Obtener GamePlayer ID del espectador
      var gp = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();
      
      if (gp == null) {
        // Auto-fix: Registrar como espectador si no existe
        await _supabase.from('game_players').insert({
          'user_id': userId,
          'event_id': eventId,
          'status': 'spectator',
          'lives': 0,
        });
        
        // Re-fetch después de insertar
        gp = await _supabase
            .from('game_players')
            .select('id')
            .eq('user_id', userId)
            .eq('event_id', eventId)
            .maybeSingle();

        if (gp == null) throw 'Error al registrar como espectador. Intenta de nuevo.';
      }
      final String gpId = gp['id'];

      // 2. Obtener Power ID desde el slug
      final power = await _supabase
          .from('powers')
          .select('id')
          .eq('slug', itemId)
          .single();
      final String powerId = power['id'];

      // 3. Verificar monedas (game_players - Session Based)
      final gpCheck = await _supabase
          .from('game_players')
          .select('coins')
          .eq('id', gpId)
          .single();
          
      final int currentCoins = (gpCheck['coins'] as num?)?.toInt() ?? 0;
      if (currentCoins < cost) throw 'No tienes suficientes monedas';

      // 4. Descontar monedas
      await _supabase.from('game_players').update({'coins': currentCoins - cost}).eq('id', gpId);

      // 5. Añadir poder al inventario
      final existingPower = await _supabase
          .from('player_powers')
          .select('id, quantity')
          .eq('game_player_id', gpId)
          .eq('power_id', powerId)
          .maybeSingle();

      if (existingPower != null) {
        await _supabase
            .from('player_powers')
            .update({'quantity': (existingPower['quantity'] ?? 0) + 1})
            .eq('id', existingPower['id']);
      } else {
        await _supabase.from('player_powers').insert({
          'game_player_id': gpId,
          'power_id': powerId,
          'quantity': 1,
        });
      }

      return PurchaseResult(success: true, newCoins: currentCoins - cost);
    } catch (e) {
      debugPrint('InventoryService: Error en compra manual de espectador: $e');
      rethrow;
    }
  }

  /// Compra una vida extra.
  /// 
  /// Llama al RPC `buy_extra_life` que hace todo atómicamente.
  Future<PurchaseResult> purchaseExtraLife({
    required String userId,
    required String eventId,
    required int cost,
  }) async {
    try {
      final int newLives = await _supabase.rpc('buy_extra_life', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
        'p_cost': cost,
      });

      return PurchaseResult(
        success: true,
        newLives: newLives,
      );
    } catch (e) {
      debugPrint('InventoryService: Error comprando vida: $e');
      return PurchaseResult.error(e.toString());
    }
  }

  /// Sincroniza el inventario real desde la tabla `player_powers`.
  /// 
  /// Retorna el estado actual del game_player incluyendo vidas e inventario.
  /// Si se proporciona [eventId], filtra por ese evento específico.
  /// Si no, retorna el game_player más reciente.
  Future<SyncInventoryResult> syncRealInventory({
    required String userId,
    String? eventId,
  }) async {
    try {
      // 1. Obtener el GamePlayer - filtrado por evento si se proporciona
      Map<String, dynamic>? gamePlayerRes;
      
      if (eventId != null && eventId.isNotEmpty) {
        // Filtrar por evento específico
        debugPrint('[DEBUG] InventoryService: Filtrando por eventId: $eventId');
        gamePlayerRes = await _supabase
            .from('game_players')
            .select('id, lives, event_id')
            .eq('user_id', userId)
            .eq('event_id', eventId)
            .maybeSingle();
      } else {
        // Fallback: obtener el más reciente
        debugPrint('[DEBUG] InventoryService: Sin eventId, obteniendo más reciente');
        gamePlayerRes = await _supabase
            .from('game_players')
            .select('id, lives, event_id')
            .eq('user_id', userId)
            .order('joined_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (gamePlayerRes == null) {
        debugPrint('InventoryService: Usuario no tiene game_player activo.');
        return SyncInventoryResult.empty();
      }

      final String gamePlayerId = gamePlayerRes['id'];
      final int? lives = gamePlayerRes['lives'];
      debugPrint('[DEBUG] InventoryService: Found gamePlayerId=$gamePlayerId for eventId=$eventId');

      // 2. Traer poderes con JOIN
      final List<dynamic> powersData = await _supabase
          .from('player_powers')
          .select('quantity, powers!inner(slug)')
          .eq('game_player_id', gamePlayerId)
          .gt('quantity', 0);

      List<String> realInventory = [];

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

      return SyncInventoryResult(
        success: true,
        gamePlayerId: gamePlayerId,
        lives: lives,
        inventory: realInventory,
      );
    } catch (e) {
      debugPrint('InventoryService: Error syncing real inventory: $e');
      return SyncInventoryResult.empty();
    }
  }
}
