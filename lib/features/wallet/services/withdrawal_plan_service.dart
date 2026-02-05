import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/withdrawal_plan.dart';

/// Service for managing withdrawal plans from Supabase.
class WithdrawalPlanService {
  final SupabaseClient _supabase;

  WithdrawalPlanService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Fetches all active withdrawal plans (for users).
  Future<List<WithdrawalPlan>> fetchActivePlans() async {
    try {
      final response = await _supabase
          .from('withdrawal_plans')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => WithdrawalPlan.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[WithdrawalPlanService] Error fetching active plans: $e');
      rethrow;
    }
  }

  /// Fetches all plans including inactive (for admin).
  Future<List<WithdrawalPlan>> fetchAllPlans() async {
    try {
      final response = await _supabase
          .from('withdrawal_plans')
          .select()
          .order('sort_order');

      return (response as List)
          .map((json) => WithdrawalPlan.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[WithdrawalPlanService] Error fetching all plans: $e');
      rethrow;
    }
  }

  /// Updates a withdrawal plan (admin only).
  Future<void> updatePlan(
    String planId, {
    int? cloversCost,
    double? amountUsd,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (cloversCost != null) updates['clovers_cost'] = cloversCost;
    if (amountUsd != null) updates['amount_usd'] = amountUsd;
    if (isActive != null) updates['is_active'] = isActive;

    await _supabase
        .from('withdrawal_plans')
        .update(updates)
        .eq('id', planId);

    debugPrint('[WithdrawalPlanService] Plan $planId updated');
  }

  /// Creates a new withdrawal plan (admin only).
  Future<void> createPlan({
    required String name,
    required int cloversCost,
    required double amountUsd,
    String? icon,
  }) async {
    await _supabase.from('withdrawal_plans').insert({
      'name': name,
      'clovers_cost': cloversCost,
      'amount_usd': amountUsd,
      'icon': icon ?? '💸',
      'is_active': true,
    });

    debugPrint('[WithdrawalPlanService] New plan created: $name');
  }
}
