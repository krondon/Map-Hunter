import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de usar un poder.
enum PowerUseResultType { success, reflected, error }

/// Respuesta detallada del uso de un poder.
class PowerUseResponse {
  final PowerUseResultType result;
  final bool wasReturned;
  final String? returnedByName;
  final bool stealFailed;
  final String? stealFailReason;
  final String? errorMessage;

  PowerUseResponse({
    required this.result,
    this.wasReturned = false,
    this.returnedByName,
    this.stealFailed = false,
    this.stealFailReason,
    this.errorMessage,
  });

  factory PowerUseResponse.success() => PowerUseResponse(
        result: PowerUseResultType.success,
      );

  factory PowerUseResponse.reflected(String byName) => PowerUseResponse(
        result: PowerUseResultType.reflected,
        wasReturned: true,
        returnedByName: byName,
      );

  factory PowerUseResponse.error(String message) => PowerUseResponse(
        result: PowerUseResultType.error,
        errorMessage: message,
      );
}

/// Información de rivales para broadcast de poderes.
class RivalInfo {
  final String gamePlayerId;
  RivalInfo(this.gamePlayerId);
}

/// Servicio de poderes que encapsula la lógica de uso y efectos de poderes.
/// 
/// Implementa DIP al recibir [SupabaseClient] por constructor.
/// NO maneja PowerEffectProvider - retorna datos para que el Provider coordine UI.
class PowerService {
  final SupabaseClient _supabase;
  final Map<String, Duration> _powerDurationCache = {};

  PowerService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Ejecuta un poder contra un objetivo.
  /// 
  /// Llama al RPC `use_power_mechanic` para la mayoría de poderes.
  /// Para `blur_screen`, usa lógica de broadcast especial.
  /// 
  /// [casterGamePlayerId] - ID del jugador que lanza el poder
  /// [targetGamePlayerId] - ID del objetivo
  /// [powerSlug] - Identificador del poder
  /// [rivals] - Lista de rivales (solo para blur_screen)
  /// [eventId] - ID del evento actual (solo para blur_screen)
  Future<PowerUseResponse> executePower({
    required String casterGamePlayerId,
    required String targetGamePlayerId,
    required String powerSlug,
    List<RivalInfo>? rivals,
    String? eventId,
  }) async {
    try {
      // [FIX] GUARDIA DE AUTO-ATAQUE: Poderes ofensivos no pueden targetear al caster
      const selfTargetingPowers = {'invisibility', 'shield', 'return'};
      final isOffensivePower = !selfTargetingPowers.contains(powerSlug);
      final isSelfTargeting = casterGamePlayerId == targetGamePlayerId;
      
      if (isOffensivePower && isSelfTargeting) {
        debugPrint('PowerService: ⛔ Self-attack prohibited for offensive power: $powerSlug');
        return PowerUseResponse.error('self_targeting_prohibited');
      }
      
      dynamic response;
      bool success = false;

      // 1. INVISIBILIDAD: target es el mismo caster
      if (powerSlug == 'invisibility') {
        response = await _supabase.rpc('use_power_mechanic', params: {
          'p_caster_id': casterGamePlayerId,
          'p_target_id': casterGamePlayerId,
          'p_power_slug': 'invisibility',
        });
        success = _coerceRpcSuccess(response);
      }
      // 2. LIFE STEAL
      else if (powerSlug == 'life_steal') {
        response = await _supabase.rpc('use_power_mechanic', params: {
          'p_caster_id': casterGamePlayerId,
          'p_target_id': targetGamePlayerId,
          'p_power_slug': 'life_steal',
        });
        success = _coerceRpcSuccess(response);
      }
      // 3. BLUR SCREEN: broadcast a todos los rivales
      else if (powerSlug == 'blur_screen') {
        final paid = await decrementPowerBySlug(
          powerSlug: 'blur_screen',
          gamePlayerId: casterGamePlayerId,
        );
        if (!paid) {
          return PowerUseResponse.error('No tienes este poder');
        }

        if (rivals != null && rivals.isNotEmpty) {
          await _broadcastBlurScreenToRivals(
            casterGamePlayerId: casterGamePlayerId,
            rivals: rivals,
            eventId: eventId,
          );
        }
        return PowerUseResponse.success();
      }
      // 4. RETURN: target es el mismo caster
      else if (powerSlug == 'return') {
        response = await _supabase.rpc('use_power_mechanic', params: {
          'p_caster_id': casterGamePlayerId,
          'p_target_id': casterGamePlayerId,
          'p_power_slug': 'return',
        });
        success = _coerceRpcSuccess(response);
      }
      // 5. OTROS PODERES
      else {
        response = await _supabase.rpc('use_power_mechanic', params: {
          'p_caster_id': casterGamePlayerId,
          'p_target_id': targetGamePlayerId,
          'p_power_slug': powerSlug,
        });
        success = _coerceRpcSuccess(response);
      }

      // Manejo de errores del servidor
      if (response is Map && response['success'] == false) {
        if (response['error'] == 'target_invisible') {
          throw '¡El objetivo es invisible!';
        }
        if (response['error'] == 'shield_already_active') {
          throw '¡El escudo ya está activo!';
        }
        return PowerUseResponse.error(response['error']?.toString() ?? 'Error');
      }

      // Detectar devolución (poder reflejado)
      if (success && response is Map && response['returned'] == true) {
        final String name = response['returned_by_name'] ?? 'Un rival';
        return PowerUseResponse.reflected(name);
      }

      // Detectar life steal fallido
      if (success &&
          response is Map &&
          response['stolen'] == false &&
          response['reason'] == 'target_no_lives') {
        return PowerUseResponse(
          result: PowerUseResultType.success,
          stealFailed: true,
          stealFailReason: 'target_no_lives',
        );
      }

      if (success) {
        return PowerUseResponse.success();
      }

      return PowerUseResponse.error('Error desconocido');
    } catch (e) {
      debugPrint('PowerService: Error usando poder: $e');
      rethrow;
    }
  }

  /// Decrementa un poder del inventario del jugador.
  /// 
  /// Retorna `true` si se decrementó exitosamente.
  Future<bool> decrementPowerBySlug({
    required String powerSlug,
    required String gamePlayerId,
  }) async {
    try {
      final powerRes = await _supabase
          .from('powers')
          .select('id')
          .eq('slug', powerSlug)
          .maybeSingle();

      if (powerRes == null || powerRes['id'] == null) return false;
      final String powerId = powerRes['id'];

      final existing = await _supabase
          .from('player_powers')
          .select('id, quantity')
          .eq('game_player_id', gamePlayerId)
          .eq('power_id', powerId)
          .maybeSingle();

      if (existing == null) return false;
      final int currentQty = (existing['quantity'] as num?)?.toInt() ?? 0;
      if (currentQty <= 0) return false;

      final updated = await _supabase
          .from('player_powers')
          .update({'quantity': currentQty - 1})
          .eq('id', existing['id'])
          .eq('quantity', currentQty)
          .select();

      return updated.isNotEmpty;
    } catch (e) {
      debugPrint('PowerService: _decrementPowerBySlug error: $e');
      return false;
    }
  }

  /// Obtiene la duración de un poder desde la base de datos.
  /// 
  /// Usa caché para evitar consultas repetidas.
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

  /// Difunde blur_screen a todos los rivales del evento.
  Future<void> _broadcastBlurScreenToRivals({
    required String casterGamePlayerId,
    required List<RivalInfo> rivals,
    String? eventId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final duration = await getPowerDuration(powerSlug: 'blur_screen');
      final expiresAt = now.add(duration).toIso8601String();

      final validRivals = rivals
          .where((r) => r.gamePlayerId.isNotEmpty && r.gamePlayerId != casterGamePlayerId)
          .toList();

      if (validRivals.isEmpty) return;

      final payloads = validRivals
          .map((rival) => <String, dynamic>{
                'target_id': rival.gamePlayerId,
                'caster_id': casterGamePlayerId,
                'power_slug': 'blur_screen',
                'expires_at': expiresAt,
                if (eventId != null) 'event_id': eventId,
              })
          .toList();

      await _supabase.from('active_powers').insert(payloads);
    } catch (e) {
      debugPrint('PowerService: _broadcastBlurScreenToRivals error: $e');
    }
  }

  /// Interpreta respuestas RPC de Supabase como booleanos.
  bool _coerceRpcSuccess(dynamic response) {
    if (response == null) return true;
    if (response is bool) return response;
    if (response is num) return response != 0;
    if (response is String) {
      final v = response.toLowerCase().trim();
      return v == 'true' || v == 't' || v == '1' || v == 'ok' || v == 'success';
    }
    if (response is Map) {
      final v = response['success'];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == 'true' || s == 't' || s == '1';
      }
      return true;
    }
    if (response is List) {
      if (response.isEmpty) return true;
      final first = response.first;
      if (first is Map && first.containsKey('success')) {
        return _coerceRpcSuccess(first);
      }
      return true;
    }
    return true;
  }
}
