import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class GeolocationScreen extends StatefulWidget {
  final String clueId;
  
  const GeolocationScreen({super.key, required this.clueId});

  @override
  State<GeolocationScreen> createState() => _GeolocationScreenState();
}

class _GeolocationScreenState extends State<GeolocationScreen> with SingleTickerProviderStateMixin {
  double _currentDistance = 500; // meters
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    // Simulate getting closer
    _simulateApproach();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  void _simulateApproach() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _currentDistance = math.max(0, _currentDistance - 100);
        });
        
        if (_currentDistance > 0) {
          _simulateApproach();
        } else {
          _onTargetReached();
        }
      }
    });
  }
  
  void _onTargetReached() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    final clue = gameProvider.clues.firstWhere((c) => c.id == widget.clueId);
    
    playerProvider.addExperience(clue.xpReward);
    playerProvider.addCoins(clue.coinReward);
    playerProvider.updateStats('speed', 5);
    gameProvider.completeCurrentClue();
    
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
                Icons.location_on,
                size: 60,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Ubicación Encontrada!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '+5 Velocidad',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
  
  String _getProximityText() {
    if (_currentDistance > 300) return '❄️ FRÍO';
    if (_currentDistance > 100) return '🌡️ TIBIO';
    if (_currentDistance > 50) return '🔥 CALIENTE';
    return '🎯 ¡MUY CERCA!';
  }
  
  Color _getProximityColor() {
    if (_currentDistance > 300) return Colors.blue;
    if (_currentDistance > 100) return Colors.orange;
    if (_currentDistance > 50) return Colors.red;
    return AppTheme.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda por Ubicación'),
        backgroundColor: AppTheme.darkBg,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulse animation circle
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 200 + (_pulseController.value * 50),
                    height: 200 + (_pulseController.value * 50),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getProximityColor().withOpacity(0.5),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getProximityColor().withOpacity(0.2),
                          border: Border.all(
                            color: _getProximityColor(),
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          Icons.navigation,
                          size: 80,
                          color: _getProximityColor(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 50),
              
              // Proximity indicator
              Text(
                _getProximityText(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _getProximityColor(),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Distance
              Text(
                '${_currentDistance.toInt()} metros',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white70,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Hint
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: AppTheme.accentGold),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sigue las indicaciones de temperatura',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
