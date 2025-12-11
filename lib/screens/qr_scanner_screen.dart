import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../models/clue.dart';
import 'puzzle_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final String clueId;
  
  const QRScannerScreen({super.key, required this.clueId});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanning = true;
  
  void _simulateScan() {
    setState(() {
      _isScanning = false;
    });
    
    // Simulate successful scan
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;

      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final clue = gameProvider.clues.firstWhere((c) => c.id == widget.clueId);
      
      // Si la pista tiene acertijo o puzzle, ir a la pantalla de puzzle
      if (clue.riddleQuestion != null || clue.puzzleType != PuzzleType.riddle) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PuzzleScreen(clue: clue),
          ),
        );
      } else {
        // Si no tiene acertijo, completar normalmente
        final success = await gameProvider.completeCurrentClue("SCANNED");
        if (success && mounted) {
          _showSuccessDialog();
        }
      }
    });
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Pista Completada!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Has ganado recompensas',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Escanear QR'),
      ),
      body: Stack(
        children: [
          // Camera simulation
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isScanning ? AppTheme.primaryPurple : AppTheme.successGreen,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Icon(
                      _isScanning ? Icons.qr_code_scanner : Icons.check_circle,
                      size: 100,
                      color: _isScanning ? Colors.white54 : AppTheme.successGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  _isScanning
                      ? 'Coloca el código QR dentro del marco'
                      : '¡Código detectado!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Scan button (simulation)
          if (_isScanning)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _simulateScan,
                  icon: const Icon(Icons.camera),
                  label: const Text('SIMULAR ESCANEO'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
