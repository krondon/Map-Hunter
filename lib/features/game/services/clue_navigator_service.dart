import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clue.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/puzzle_screen.dart';
import '../../mall/screens/mall_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../providers/game_provider.dart';

/// Service for handling clue navigation based on clue type AND app mode.
/// 
/// Navigation logic:
/// - **ONLINE mode**: All clues go directly to PuzzleScreen (minigame).
/// - **PRESENCIAL mode**: ALL clues require QR scan first, then navigate to puzzle.
class ClueNavigatorService {
  
  /// Navigate to the appropriate screen for a clue.
  /// 
  /// This method considers BOTH:
  /// 1. The app mode (online vs presencial from AppModeProvider)
  /// 2. The clue type (OnlineClue vs PhysicalClue)
  static void navigateToClue(BuildContext context, Clue clue) async {
    // Get the app mode - this is the USER's selected mode, not the clue data
    final appMode = Provider.of<AppModeProvider>(context, listen: false);
    final isOnlineMode = appMode.isOnlineMode;
    
    debugPrint('[ClueNavigator] ====================================');
    debugPrint('[ClueNavigator] Navigating to clue: ${clue.title}');
    debugPrint('[ClueNavigator] App Mode: ${isOnlineMode ? "ONLINE" : "PRESENCIAL"}');
    debugPrint('[ClueNavigator] Clue Type: ${clue.runtimeType} (${clue.type})');
    debugPrint('[ClueNavigator] ====================================');

    // === ONLINE MODE ===
    // In online mode, ALL clues go directly to the puzzle/minigame.
    // No GPS, no QR scanning required.
    if (isOnlineMode) {
      _navigateDirectlyToPuzzle(context, clue);
      return;
    }

    // === PRESENCIAL MODE ===
    // In presencial mode, ALL clues need QR validation FIRST.
    // After successful QR scan, navigate to the puzzle.
    await _navigateWithQRValidation(context, clue);
  }

  /// Navigate directly to the puzzle (used in ONLINE mode).
  static void _navigateDirectlyToPuzzle(BuildContext context, Clue clue) {
    try {
      debugPrint('[ClueNavigator] Direct navigation to PuzzleScreen (ONLINE mode)');
      
      // OnlineClue goes to PuzzleScreen
      if (clue is OnlineClue) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PuzzleScreen(clue: clue)),
        );
        return;
      }
      
      // For PhysicalClue in online mode - this shouldn't happen often
      // but handle gracefully by showing info
      debugPrint('[ClueNavigator] WARNING: PhysicalClue in online mode');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta pista requiere presencia física.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: No se pudo cargar el minijuego. $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  /// Navigate with QR validation first (used in PRESENCIAL mode).
  /// Shows QR scanner, validates the code, then navigates to puzzle.
  static Future<void> _navigateWithQRValidation(BuildContext context, Clue clue) async {
    debugPrint('[ClueNavigator] QR Validation required (PRESENCIAL mode)');
    
    // Go to QR Scanner
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(expectedClueId: clue.id),
      ),
    );
    
    // If user cancelled the scanner
    if (scannedCode == null) {
      debugPrint('[ClueNavigator] QR scan cancelled by user');
      return;
    }
    
    debugPrint('[ClueNavigator] QR scanned: $scannedCode');
    
    // Validate the scanned code
    // Expected formats: 
    // - "CLUE:{clueId}" 
    // - "{clueId}" (direct match)
    // - "DEV_SKIP_CODE" (developer bypass)
    final bool isValid = _validateQRCode(scannedCode, clue.id);
    
    if (!isValid) {
      debugPrint('[ClueNavigator] QR code invalid for clue ${clue.id}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El código QR no corresponde a esta pista.'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
      return;
    }
    
    debugPrint('[ClueNavigator] QR validated! Unlocking clue and navigating to puzzle');
    
    // Unlock the clue in GameProvider
    if (context.mounted) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      gameProvider.unlockClue(clue.id);
    }
    
    // Navigate to the puzzle/minigame
    if (context.mounted) {
      if (clue is OnlineClue) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PuzzleScreen(clue: clue)),
        );
      } else if (clue is PhysicalClue) {
        // For physical clues, handle based on their specific type
        _handlePhysicalClueAfterQR(context, clue);
      }
    }
  }
  
  /// Handle physical clue navigation after QR validation.
  static void _handlePhysicalClueAfterQR(BuildContext context, PhysicalClue clue) {
    switch (clue.type) {
      case ClueType.npcInteraction:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MallScreen()),
        );
        break;
      case ClueType.qrScan:
      case ClueType.geolocation:
        // For these types, the QR scan WAS the challenge
        // Show success and mark as complete
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pista desbloqueada correctamente!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        break;
      default:
        debugPrint('[ClueNavigator] Unknown PhysicalClue type: ${clue.type}');
        break;
    }
  }
  
  /// Validate QR code against expected clue ID.
  static bool _validateQRCode(String scannedCode, String clueId) {
    // Developer bypass
    if (scannedCode == 'DEV_SKIP_CODE') {
      debugPrint('[ClueNavigator] Developer bypass accepted');
      return true;
    }
    
    // Direct match with CLUE: prefix
    if (scannedCode.startsWith('CLUE:')) {
      final parts = scannedCode.split(':');
      if (parts.length >= 2) {
        return parts[1] == clueId || scannedCode.contains(clueId);
      }
    }
    
    // Direct ID match
    if (scannedCode == clueId) {
      return true;
    }
    
    // Contains the clue ID somewhere
    if (scannedCode.contains(clueId)) {
      return true;
    }
    
    return false;
  }
}

