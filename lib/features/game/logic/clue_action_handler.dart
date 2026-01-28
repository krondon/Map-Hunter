import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../screens/puzzle_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/clue_finder_screen.dart';
import '../../mall/screens/mall_screen.dart';
import '../../../core/theme/app_theme.dart';

/// ClueActionHandler: External action handler following SRP.
/// 
/// This class centralizes all clue-related navigation logic,
/// keeping the Clue model pure (free of Flutter/BuildContext dependencies).
/// 
/// Decision Logic:
/// - [OnlineClue]: Auto-unlock (bypass) and navigate directly to PuzzleScreen.
/// - [PhysicalClue]: Navigate based on type (QR Scanner, Geolocation Radar, NPC/Mall).
class ClueActionHandler {
  
  /// Main entry point - handles navigation based on clue type.
  /// 
  /// This method unifies both branches (Online and Presencial) into a single
  /// decision point while preserving visual transitions.
  static void handle(BuildContext context, Clue clue) {
    // Branch 1: Online Clue (Minigame) - Direct bypass to puzzle
    if (clue is OnlineClue) {
      _handleOnlineClue(context, clue);
      return;
    }

    // Branch 2: Physical Clue - Location-based interactions
    if (clue is PhysicalClue) {
      _handlePhysicalClue(context, clue);
      return;
    }

    // Fallback: Use ClueType enum for edge cases
    _handleByClueType(context, clue);
  }

  /// Handles OnlineClue: Auto-unlock and navigate to PuzzleScreen.
  /// 
  /// The "Online Mode Bypass" logic - no QR scan needed, 
  /// player goes directly to the puzzle/minigame.
  static void _handleOnlineClue(BuildContext context, OnlineClue clue) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PuzzleScreen(clue: clue),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(context, 'Error al cargar el minijuego: $e');
    }
  }

  /// Handles PhysicalClue: Navigation based on specific physical type.
  /// 
  /// Routes to appropriate screen:
  /// - QR Scan -> QRScannerScreen
  /// - Geolocation -> ClueFinderScreen (Radar)
  /// - NPC Interaction -> MallScreen
  static void _handlePhysicalClue(BuildContext context, PhysicalClue clue) {
    switch (clue.type) {
      case ClueType.qrScan:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRScannerScreen(expectedClueId: clue.id),
          ),
        );
        break;

      case ClueType.geolocation:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClueFinderScreen(clue: clue),
          ),
        );
        break;

      case ClueType.npcInteraction:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MallScreen()),
        );
        break;

      default:
        debugPrint('[ClueActionHandler] Unknown PhysicalClue type: ${clue.type}');
        _showErrorSnackBar(context, 'Tipo de pista no reconocido.');
        break;
    }
  }

  /// Fallback handler using ClueType enum directly.
  /// 
  /// Used when polymorphic type checking fails (unlikely with proper factory).
  static void _handleByClueType(BuildContext context, Clue clue) {
    switch (clue.type) {
      case ClueType.minigame:
        // Attempt to navigate to puzzle with base clue data
        try {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PuzzleScreen(clue: clue as OnlineClue),
            ),
          );
        } catch (e) {
          _showErrorSnackBar(context, 'Error: Tipo de minijuego inválido.');
        }
        break;

      case ClueType.qrScan:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRScannerScreen(expectedClueId: clue.id),
          ),
        );
        break;

      case ClueType.geolocation:
        // Cannot navigate without PhysicalClue casting for coordinates
        _showErrorSnackBar(context, 'Error: Datos de ubicación no disponibles.');
        break;

      case ClueType.npcInteraction:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MallScreen()),
        );
        break;
    }
  }

  /// Helper: Shows error feedback to user.
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
