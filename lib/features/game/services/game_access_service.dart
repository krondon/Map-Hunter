import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/scenario.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/enums/entry_types.dart';

enum AccessResultType {
  allowed,
  deniedPermissions,
  deniedForever,
  fakeGps,
  sessionInvalid,
  suspended,
  needsAvatar, 
  approvedWait,
  requestPendingOrRejected,
  needsCode,
  // --- NEW: Wallet & Spectator Support ---
  needsPayment,      // User needs to pay entry fee
  spectatorAllowed,  // User can observe but not play
}

class GameAccessResult {
  final AccessResultType type;
  final String? message;
  final Map<String, dynamic>? data;
  final UserRole? role;
  final bool isReadOnly;

  GameAccessResult(
    this.type, {
    this.message,
    this.data,
    this.role,
    this.isReadOnly = false,
  });

  /// Create a spectator access result.
  factory GameAccessResult.spectator({String? message}) => GameAccessResult(
    AccessResultType.spectatorAllowed,
    message: message,
    role: UserRole.spectator,
    isReadOnly: true,
  );

  /// Create a player access result.
  factory GameAccessResult.player({Map<String, dynamic>? data}) => GameAccessResult(
    AccessResultType.allowed,
    data: data,
    role: UserRole.player,
    isReadOnly: false,
  );
}

class GameAccessService {
  
  /// Checks all conditions (Location, FakeGPS, Auth, Session, Participation) 
  /// and returns a decision on what to do next.
  /// 
  /// For ONLINE events, location validation is completely bypassed.
  /// For ON-SITE events, full location/GPS checks are performed.
  /// 
  /// [role] - The role the user wants to enter as. Spectators bypass participation checks.
  /// [entryFee] - Optional entry fee amount for paid events.
  Future<GameAccessResult> checkAccess({
    required BuildContext context,
    required Scenario scenario,
    required PlayerProvider playerProvider,
    required GameRequestProvider requestProvider,
    UserRole role = UserRole.player,
    double? entryFee,
  }) async {
    
    // --- SPECTATOR FAST PATH ---
    // Spectators bypass most validation - they just want to watch
    if (role == UserRole.spectator) {
      return _checkSpectatorAccess(
        playerProvider: playerProvider,
        scenario: scenario,
      );
    }

    // --- PLAYER PATH (existing logic) ---
    
    // 1. Location Checks - ONLY for on-site (presencial) events
    final bool isOnlineEvent = scenario.type == 'online';
    bool shouldCheckLocation = !isOnlineEvent; // Skip entirely for online events
    
    // Additionally skip for desktop platforms (development)
    if (shouldCheckLocation) {
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          shouldCheckLocation = false;
        }
      } catch (e) {
        // On web or unknown platform, keep the original decision
      }
    }

    if (shouldCheckLocation) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return GameAccessResult(AccessResultType.deniedPermissions, message: 'Se requieren permisos de ubicación para participar');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return GameAccessResult(AccessResultType.deniedForever, message: 'Los permisos de ubicación están denegados permanentemente.');
      }

      // Check for Fake GPS
      try {
        final position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
        if (position.isMocked) {
           return GameAccessResult(AccessResultType.fakeGps, message: 'Se ha detectado el uso de una aplicación de ubicación falsa.');
        }
      } catch (e) {
        // Ignore location errors here for now, proceed
      }
    }

    // 2. Auth Session Check
    if (playerProvider.currentPlayer == null) {
       return GameAccessResult(AccessResultType.sessionInvalid, message: 'Sesión no válida.');
    }
    
    final String userId = playerProvider.currentPlayer!.userId;

    // 3. Payment Check (if event requires entry fee)
    if (entryFee != null && entryFee > 0) {
      // For now, we return needsPayment - WalletProvider will handle actual check
      // This is a placeholder until wallet integration is complete
      return GameAccessResult(
        AccessResultType.needsPayment,
        message: 'Este evento requiere una inscripción de ${entryFee.toStringAsFixed(2)} 🍀',
        data: {'entryFee': entryFee},
      );
    }

    // 4. Participant Status (Gatekeeper)
    try {
      final participantData = await requestProvider.isPlayerParticipant(userId, scenario.id);
      final isGamePlayer = participantData['isParticipant'] as bool;
      final playerStatus = participantData['status'] as String?;

      if (isGamePlayer) {
        // User is ALREADY a participant
        if (playerStatus == 'suspended' || playerStatus == 'banned') {
           return GameAccessResult(AccessResultType.suspended, message: 'Has sido suspendido de esta competencia por un administrador.');
        }
        
        // Allowed to enter (check Avatar next logic is UI flow, but access is granted)
        return GameAccessResult.player(data: {'isParticipant': true});
      } else {
        // User is NOT a participant yet
        final request = await requestProvider.getRequestForPlayer(userId, scenario.id);
        
        if (request != null) {
          if (request.isApproved) {
            return GameAccessResult.player(data: {'isParticipant': false, 'isApproved': true});
          } else {
            return GameAccessResult(AccessResultType.requestPendingOrRejected);
          }
        } else {
          return GameAccessResult(AccessResultType.needsCode);
        }
      }

    } catch (e) {
       return GameAccessResult(AccessResultType.sessionInvalid, message: 'Error verificando estado: $e');
    }
  }

  /// Spectator-specific access check.
  /// 
  /// Spectators can watch any event they have basic access to.
  /// They bypass GPS, participation, and payment checks.
  Future<GameAccessResult> _checkSpectatorAccess({
    required PlayerProvider playerProvider,
    required Scenario scenario,
  }) async {
    // 1. Auth Session Check (spectators still need to be logged in)
    if (playerProvider.currentPlayer == null) {
      return GameAccessResult(
        AccessResultType.sessionInvalid,
        message: 'Debes iniciar sesión para observar.',
      );
    }

    final String userId = playerProvider.currentPlayer!.userId;

    // 2. Check if user is banned from the event
    // Even spectators shouldn't be allowed if banned
    // This could be expanded with a repository call if needed

    debugPrint('[GameAccessService] Spectator access granted for user $userId');

    return GameAccessResult.spectator(
      message: 'Modo Espectador - Solo lectura',
    );
  }

  /// Check if a scenario requires payment.
  bool scenarioRequiresPayment(Scenario scenario, EntryType entryType) {
    return entryType == EntryType.paid;
  }
}

