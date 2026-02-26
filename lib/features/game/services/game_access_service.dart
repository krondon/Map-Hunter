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
  bannedSpectator,   // User is banned but can spectate
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
        requestProvider: requestProvider,
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

    // 3. Participant Status (Gatekeeper) - CHECK FIRST
    try {
      final participantData = await requestProvider.isPlayerParticipant(userId, scenario.id);
      final isGamePlayer = participantData['isParticipant'] as bool;
      final playerStatus = participantData['status'] as String?;

      bool shouldCheckJoin = !isGamePlayer;

      if (isGamePlayer) {
        // User is ALREADY in the event
        if (playerStatus == 'suspended' || playerStatus == 'banned') {
           // NEW: Allow banned users to spectate
           return GameAccessResult(
             AccessResultType.bannedSpectator,
             message: 'Estás suspendido de esta competencia. Solo puedes observar.',
             role: UserRole.spectator,
             isReadOnly: true,
           );
        }

        if (playerStatus == 'spectator') {
          // Si el usuario es espectador pero quiere entrar como JUGADOR (role == player),
          // permitimos que continúe hacia la validación de cupo (upgrade).
          if (role == UserRole.spectator) {
             return GameAccessResult.spectator(message: 'Continuando como espectador');
          }
          // Intencional: Fallthrough para permitir upgrade
          shouldCheckJoin = true; 
        } else {
          // Allowed to enter as a player (active, pending, etc handled here or elsewhere?)
          // Usually 'active' or 'pending' (pending might be restricted but checking here implies access if returning player)
          // Wait, if pending, do we allow 'player' result? 
          // The old logic returned 'player' for anything not spectator/banned/suspended.
          return GameAccessResult.player(data: {'isParticipant': true});
        }
      } 
      
      if (shouldCheckJoin) {
        // --- LIMITE DE PARTICIPANTES ---
        // Verificamos el conteo real en DB para evitar inconsistencias si el usuario no ha refrescado la pantalla
        final realCount = await requestProvider.getParticipantCount(scenario.id);
        if (realCount >= scenario.maxPlayers) {
          // Si ya era espectador, vuelve a espectador. Si es nuevo, va a espectador.
          return GameAccessResult.spectator(
            message: 'El máximo de jugadores (${scenario.maxPlayers}) ya fue alcanzado. Entrando como espectador.'
          );
        }

        // User is NOT a participant yet (or upgrading from spectator)
        final request = await requestProvider.getRequestForPlayer(userId, scenario.id);
        
        if (request != null) {
          if (request.isApproved) {
            // Request is Approved - Allow entry (skip payment check as usually approval implies payment/permission)
            return GameAccessResult.player(data: {'isParticipant': false, 'isApproved': true});
          } else {
            return GameAccessResult(AccessResultType.requestPendingOrRejected);
          }
        }
        // If no request exists, proceed to payment check or code check
      }

    } catch (e) {
       return GameAccessResult(AccessResultType.sessionInvalid, message: 'Error verificando estado: $e');
    }

    // 4. Payment Check (if event requires entry fee AND user is not a participant)
    if (entryFee != null && entryFee > 0) {
      return GameAccessResult(
        AccessResultType.needsPayment,
        message: 'Este evento requiere una inscripción de ${entryFee.toStringAsFixed(2)} tréboles',
        data: {'entryFee': entryFee},
      );
    }
    
    // 5. If no payment needed, but no request found -> Needs Code (or just explicit join for free events)
    return GameAccessResult(AccessResultType.needsCode);
  }

  /// Spectator-specific access check.
  /// 
  /// Spectators can watch any event they have basic access to.
  /// They bypass GPS, participation, and payment checks.
  Future<GameAccessResult> _checkSpectatorAccess({
    required PlayerProvider playerProvider,
    required GameRequestProvider requestProvider,
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

    // 2. Check if user is ALREADY a participant (Active Player)
    // If they are a player, they should NOT be in spectator mode.
    // However, if they are 'banned' or 'suspended', they ARE allowed to spectate (existing logic).
    
    try {
      final participantData = await requestProvider.isPlayerParticipant(userId, scenario.id);
      final isParticipant = participantData['isParticipant'] as bool;
      final status = participantData['status'] as String?;

      if (isParticipant) {
        // If suspended or banned, allow spectator (readonly)
        if (status == 'suspended' || status == 'banned') {
           // Allow flow to continue to spectatorAllowed
        } else {
           // Active player trying to spectate -> Redirect to Player Mode
           debugPrint('[GameAccessService] User $userId is active player. Redirecting to player mode.');
           return GameAccessResult.player(
              data: {'isParticipant': true}, 
           );
        }
      }
    } catch (e) {
      debugPrint('Error checking participant status for spectator: $e');
    }

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

