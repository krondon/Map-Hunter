import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/scenario.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart';

enum AccessResultType {
  allowed,
  deniedPermissions,
  deniedForever,
  fakeGps,
  sessionInvalid,
  suspended,
  needsAvatar, 
  approvedWait, // Request approved but maybe needs loading? Actually 'allowed' covers entering. 
  // We need to distinguish "Enter Game" vs "Go to Request Screen" vs "Go to Code Finder"
  requestPendingOrRejected, // Go to GameRequestScreen
  needsCode, // Go to CodeFinderScreen
}

class GameAccessResult {
  final AccessResultType type;
  final String? message;
  final Map<String, dynamic>? data;

  GameAccessResult(this.type, {this.message, this.data});
}

class GameAccessService {
  
  /// Checks all conditions (Location, FakeGPS, Auth, Session, Participation) 
  /// and returns a decision on what to do next.
  Future<GameAccessResult> checkAccess({
    required BuildContext context, // Start using context only for Providers lookup if needed, or pass providers
    required Scenario scenario,
    required PlayerProvider playerProvider,
    required GameRequestProvider requestProvider,
  }) async {
    
    // 1. Location Checks (Platform specific)
    bool shouldCheckLocation = true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        shouldCheckLocation = false;
      }
    } catch (e) {
      shouldCheckLocation = true; 
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

    // 3. Participant Status (Gatekeeper)
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
        return GameAccessResult(AccessResultType.allowed, data: {'isParticipant': true});
      } else {
        // User is NOT a participant yet
        final request = await requestProvider.getRequestForPlayer(userId, scenario.id);
        
        if (request != null) {
          if (request.isApproved) {
            return GameAccessResult(AccessResultType.allowed, data: {'isParticipant': false, 'isApproved': true});
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
}
