/// Resultado de usar un poder.
enum PowerUseResultType { success, reflected, error }

/// Respuesta detallada del uso de un poder.
class PowerUseResponse {
  final PowerUseResultType result;
  final bool wasReturned;
  final String? returnedByName;
  final bool stealFailed;
  final String? stealFailReason;
  final bool blockedByShield;
  final bool gifted;
  final String? errorMessage;

  PowerUseResponse({
    required this.result,
    this.wasReturned = false,
    this.returnedByName,
    this.stealFailed = false,
    this.stealFailReason,
    this.blockedByShield = false,
    this.gifted = false,
    this.errorMessage,
  });

  factory PowerUseResponse.success() => PowerUseResponse(
        result: PowerUseResultType.success,
      );
  
  factory PowerUseResponse.blocked() => PowerUseResponse(
        result: PowerUseResultType.success, // Technically success execution, but blocked effect
        blockedByShield: true,
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

  static PowerUseResponse fromRpcResponse(dynamic response) {
    print("DEBUG: PowerUseResponse raw: $response");
    if (response is Map) {
      // 1. Check for explicit error
      if (response['success'] == false) {
        final error = response['error'];
         if (error == 'unauthorized') return PowerUseResponse.error('No tienes permiso para usar este poder');
         if (error == 'target_invisible') return PowerUseResponse.error('¡El objetivo es invisible!');
         if (error == 'shield_already_active') return PowerUseResponse.error('¡El escudo ya está activo!');
         if (error == 'target_already_protected') return PowerUseResponse.error('¡El objetivo ya está protegido!');
         return PowerUseResponse.error(error?.toString() ?? 'Error desconocido');
      }
      
      // 2. Check for blocked
      if (response['blocked'] == true) {
        return PowerUseResponse.blocked();
      }

      // 3. Check for returned
      if (response['returned'] == true) {
        return PowerUseResponse.reflected(response['returned_by_name'] ?? 'Un rival');
      }

      // 3.1 Check for gifted
      if (response['gifted'] == true) {
        return PowerUseResponse(
            result: PowerUseResultType.success,
            gifted: true,
        );
      }

      // 4. Check for steal fail
      if (response['stolen'] == false && response['reason'] == 'target_no_lives') {
        return PowerUseResponse(
          result: PowerUseResultType.success,
          stealFailed: true,
          stealFailReason: 'target_no_lives',
        );
      }
    }

    // 5. Handle scalars (bool, string, int) or default success
    if (response is bool && response == false) return PowerUseResponse.error('Falló la ejecución del poder');
    
    return PowerUseResponse.success();
  }
}

/// Información de rivales para broadcast de poderes.
class RivalInfo {
  final String gamePlayerId;
  RivalInfo(this.gamePlayerId);
}
