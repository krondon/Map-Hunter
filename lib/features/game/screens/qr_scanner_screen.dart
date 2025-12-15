import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _isProcessing = false;
  
  void _simulateScan() {
    if (_isProcessing) return;

    setState(() { 
      _isScanning = false;
      _isProcessing = true; 
    });
    
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      
      try {
        gameProvider.unlockClue(widget.clueId);
        
        final clue = gameProvider.clues.firstWhere((c) => c.id == widget.clueId);
        
        if (clue.type.toString().contains('minigame') || clue.puzzleType != PuzzleType.riddle) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PuzzleScreen(clue: clue),
            ),
          );
        } else {
          final success = await gameProvider.completeCurrentClue("SCANNED", clueId: widget.clueId);
          
          if (success && mounted) {
             final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
             // CORRECCIÓN: Refrescar perfil en lugar de sumar manualmente
             await playerProvider.refreshProfile();
             
             if (mounted) _showSuccessDialog();
          }
        }
      } catch (e) {
        debugPrint("Error en escaneo: $e");
        setState(() => _isProcessing = false);
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 60, color: AppTheme.successGreen),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Ubicación Confirmada!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
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
        elevation: 0,
        title: const Text('Escanear QR', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.grey[900],
                  child: Center(
                    child: Icon(
                      Icons.camera_alt_outlined, 
                      size: 80, 
                      color: Colors.white.withOpacity(0.1)
                    ),
                  ),
                ),
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isProcessing 
                        ? AppTheme.successGreen 
                        : (_isScanning ? AppTheme.accentGold : AppTheme.successGreen),
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_isScanning ? AppTheme.accentGold : AppTheme.successGreen).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isScanning)
                        Container(
                          width: 260,
                          height: 2,
                          color: AppTheme.accentGold.withOpacity(0.5),
                        ),
                      if (!_isScanning)
                         const Icon(Icons.check_circle, size: 80, color: AppTheme.successGreen),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isProcessing 
                        ? 'Procesando...' 
                        : (_isScanning ? 'Apunta al código QR' : '¡Escaneado!'),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "MODO DESARROLLADOR",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isScanning && !_isProcessing) ? _simulateScan : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      ),
                      elevation: 0,
                    ),
                    icon: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.qr_code_scanner),
                    label: Text(
                      _isProcessing ? 'VERIFICANDO...' : 'SIMULAR ESCANEO QR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}