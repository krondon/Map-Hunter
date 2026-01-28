import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/clue_finder_screen.dart';
import '../screens/puzzle_screen.dart';
import '../../mall/screens/mall_screen.dart';
import '../../../core/theme/app_theme.dart';

class ClueNavigatorService {
  static void navigateToClue(BuildContext context, Clue clue) async {
    // Handling based on ClueType or specific class checks
    // We can use the 'type' field from Clue
    
    // Check if it's an online clue first (minigame)
    // Polymorphism check via type
    if (clue is OnlineClue) {
       _navigateToOnlineClue(context, clue);
       return;
    }

    if (clue is PhysicalClue) {
       _navigateToPhysicalClue(context, clue);
       return;
    }

    // Fallback if type matching fails but we have enum type
    switch (clue.type) {
      case ClueType.minigame:
        if (clue is OnlineClue) {
          _navigateToOnlineClue(context, clue);
        }
        break;
      case ClueType.qrScan:
      case ClueType.geolocation:
      case ClueType.npcInteraction:
         // Should be covered by PhysicalClue check, but just in case
         // We might not have casting if it was instantiated as base (unlikely with factory)
         _handleGenericPhysicalType(context, clue);
         break;
    }
  }

  static void _navigateToOnlineClue(BuildContext context, OnlineClue clue) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PuzzleScreen(clue: clue)),
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

  static void _navigateToPhysicalClue(BuildContext context, PhysicalClue clue) async {
    switch (clue.type) {
      case ClueType.qrScan:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QRScannerScreen(expectedClueId: clue.id)),
        );
        break;
      case ClueType.geolocation:
        await Navigator.push(
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
        debugPrint("ClueNavigatorService: Unknown PhysicalClue type: ${clue.type}");
        break;
    }
  }

  static void _handleGenericPhysicalType(BuildContext context, Clue clue) {
      // Fallback for cases where it might not be cast to PhysicalClue but has physical types
      if (clue.type == ClueType.qrScan) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => QRScannerScreen(expectedClueId: clue.id)));
      } else if (clue.type == ClueType.npcInteraction) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => const MallScreen()));
      }
  }
}
