import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clover_plan.dart';

/// Service for fetching clover purchase plans from Supabase.
/// 
/// Plans are stored in `clover_plans` table and fetched dynamically.
/// This allows admins to change prices without code deployments.
class CloverPlanService {
  final SupabaseClient _supabase;

  CloverPlanService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Fetches all active clover plans, sorted by sort_order.
  /// 
  /// RLS policy ensures only active plans are returned.
  Future<List<CloverPlan>> fetchActivePlans() async {
    try {
      final data = await _supabase
          .from('clover_plans')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (data as List)
          .map((json) => CloverPlan.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[CloverPlanService] Error fetching plans: $e');
      rethrow;
    }
  }

  /// Fetches all plans including inactive (admin use).
  Future<List<CloverPlan>> fetchAllPlans() async {
    try {
      // This requires admin privileges due to RLS
      final data = await _supabase
          .from('clover_plans')
          .select()
          .order('sort_order', ascending: true);

      return (data as List)
          .map((json) => CloverPlan.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[CloverPlanService] Error fetching all plans: $e');
      rethrow;
    }
  }

  /// Updates a plan's properties (admin only).
  Future<void> updatePlan(
    String id, {
    double? priceUsd,
    int? cloversQuantity,
    bool? isActive,
    String? name,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (priceUsd != null) updates['price_usd'] = priceUsd;
      if (cloversQuantity != null) updates['clovers_quantity'] = cloversQuantity;
      if (isActive != null) updates['is_active'] = isActive;
      if (name != null) updates['name'] = name;

      await _supabase
          .from('clover_plans')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      debugPrint('[CloverPlanService] Error updating plan: $e');
      rethrow;
    }
  }
}
