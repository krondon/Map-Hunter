import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game/strategies/power_response.dart';




import '../../game/strategies/power_strategy_factory.dart';

class PowerService {
  final SupabaseClient _supabase;
  final PowerStrategyFactory _factory;
  final Map<String, Duration> _powerDurationCache = {};

  PowerService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient,
        _factory = PowerStrategyFactory(supabaseClient);

  /// Ejecuta un poder contra un objetivo mediante estrategias.
  Future<PowerUseResponse> executePower({
    required String casterGamePlayerId,
    required String targetGamePlayerId,
    required String powerSlug,
    List<RivalInfo>? rivals,
    String? eventId,
    bool isSpectator = false,
    bool isAlreadyActive = false,
  }) async {
    try {
      // --- DEFENSE EXCLUSIVITY CHECK (Refactor) ---
      // We need access to the provider state to check other active powers.
      // Since PowerService is stateless regarding provider, we rely on `isAlreadyActive` 
      // which was passed from the caller (PlayerProvider/Dispatcher).
      // BUT, `isAlreadyActive` only checked if the SAME power was active.
      // We need to know if ANY defense power is active.
      
      // Ideally, the caller should have checked `canActivateDefensePower` before calling this.
      // However, as a safeguard, if we could check here it would be good.
      // Given we don't have provider reference here, we must rely on the caller to enforce 
      // "Can I cast this?".
      // But we can check if `isAlreadyActive` passed in implies "Specific Power Active".
      
      if (isAlreadyActive) {
         debugPrint('PowerService: 🛑 Power $powerSlug is already active locally. Aborting execution.');
         return PowerUseResponse.error('already_active_locally');
      }

      // GUARDIA DE AUTO-ATAQUE: Poderes ofensivos no pueden targetear al caster
      const selfTargetingPowers = {'invisibility', 'shield', 'return', 'blur_screen'};
      final isOffensivePower = !selfTargetingPowers.contains(powerSlug);
      final isSelfTargeting = casterGamePlayerId == targetGamePlayerId;
      
      if (isOffensivePower && isSelfTargeting && !isSpectator) {
        debugPrint('PowerService: ⛔ Self-attack prohibited for offensive power: $powerSlug');
        return PowerUseResponse.error('self_targeting_prohibited');
      }

      final strategy = _factory.get(powerSlug);
      
      debugPrint('PowerService: 🚀 Executing strategy for $powerSlug');
      return await strategy.execute(
        casterId: casterGamePlayerId,
        targetId: targetGamePlayerId,
        rivals: rivals,
        eventId: eventId,
        isSpectator: isSpectator,
      );
    } catch (e) {
      debugPrint('PowerService: Error using power strategy: $e');
      rethrow;
    }
  }

  /// Obtiene la duración de un poder desde la base de datos.
  Future<Duration> getPowerDuration({required String powerSlug}) async {
    final cached = _powerDurationCache[powerSlug];
    if (cached != null) return cached;

    try {
      final row = await _supabase
          .from('powers')
          .select('duration')
          .eq('slug', powerSlug)
          .maybeSingle();

      final seconds = (row?['duration'] as num?)?.toInt() ?? 0;
      final duration = seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
      _powerDurationCache[powerSlug] = duration;
      return duration;
    } catch (e) {
      debugPrint('PowerService: getPowerDuration($powerSlug) error: $e');
      return Duration.zero;
    }
  }

  /// Obtiene la configuración de duración (segundos) de todos los poderes.
  Future<List<Map<String, dynamic>>> getPowerConfigs() async {
    try {
      final response = await _supabase.from('powers').select('slug, duration');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('PowerService: Error fetching power configs: $e');
      rethrow;
    }
  }

  /// Obtiene la configuración de precios para espectadores de un evento.
  Future<Map<String, dynamic>> getSpectatorConfig(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('spectator_config')
          .eq('id', eventId)
          .maybeSingle();

      if (response != null && response['spectator_config'] != null) {
        return Map<String, dynamic>.from(response['spectator_config']);
      }
      return {};
    } catch (e) {
      debugPrint('PowerService: Error fetching spectator config: $e');
      return {};
    }
  }
}
