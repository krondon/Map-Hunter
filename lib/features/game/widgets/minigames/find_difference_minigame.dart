import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../game_over_dialog.dart';

class FindDifferenceMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const FindDifferenceMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<FindDifferenceMinigame> createState() => _FindDifferenceMinigameState();
}

class _FindDifferenceMinigameState extends State<FindDifferenceMinigame> {
  final Random _random = Random();
  
  // Game Logic
  late List<_DistractorItem> _distractors;
  late IconData _targetIcon;
  late Offset _targetPosition;
  late bool _targetInTopImage;
  
  // State
  Timer? _timer;
  int _secondsRemaining = 40;
  bool _isGameOver = false;
  int _localAttempts = 3;

  @override
  void initState() {
    super.initState();
    _generateGame();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generateGame() {
    final icons = [
      Icons.star_outline, Icons.ac_unit, Icons.wb_sunny_outlined, Icons.pets_outlined,
      Icons.favorite_outline, Icons.flash_on_outlined, Icons.filter_vintage_outlined,
      Icons.camera_outlined, Icons.brush_outlined, Icons.anchor_outlined, 
      Icons.eco_outlined, Icons.lightbulb_outline, Icons.extension_outlined,
    ];

    // Pick 30 random distractors to populate the field
    icons.shuffle();
    _distractors = List.generate(30, (index) {
      return _DistractorItem(
        icon: icons[index % icons.length],
        position: Offset(0.05 + _random.nextDouble() * 0.9, 0.05 + _random.nextDouble() * 0.9),
        rotation: _random.nextDouble() * pi * 2,
        size: 15.0 + _random.nextDouble() * 10,
      );
    });

    // Pick a random target icon that looks like the distractors
    _targetIcon = icons[_random.nextInt(icons.length)];
    _targetPosition = Offset(0.1 + _random.nextDouble() * 0.8, 0.1 + _random.nextDouble() * 0.8);
    _targetInTopImage = _random.nextBool();
    
    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause timer

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleFailure("Tiempo agotado");
      }
    });
  }

  void _handleTap(bool isTop) {
    if (_isGameOver) return;
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return; // Ignore input if frozen

    if (isTop == _targetInTopImage) {
      _winGame();
    } else {
      setState(() {
        _localAttempts--;
      });
      if (_localAttempts <= 0) {
        _handleFailure("Demasiados errores");
      }
    }
  }

  void _winGame() {
    _timer?.cancel();
    _isGameOver = true;
    widget.onSuccess();
  }

  void _handleFailure(String reason) async {
    _timer?.cancel();
    _isGameOver = true;
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
      // USAR HELPER CENTRALIZADO
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      
      if (!mounted) return;
      
      // Verificar estado FINAL (Usando valor definitivo)
      if (newLives <= 0) {
         _showGameOverDialog();
      } else {
         _showTryAgainDialog(reason);
      }
    }
  }

  void _showTryAgainDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("INTENTO FALLIDO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(reason, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _secondsRemaining = 40;
                _localAttempts = 3;
                _isGameOver = false;
                _generateGame();
                _startTimer();
              });
            },
            child: const Text("REINTENTAR", style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameOverDialog(
        reason: "No has encontrado las diferencias a tiempo.",
        onExit: () => Navigator.popUntil(context, (route) => route.isFirst),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Header Minimalista
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ANOMALÍA DETECTADA", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    Text(
                      "Encuentra el icono que sobra y toca ese cuadro", 
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  "00:$_secondsRemaining",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),

          // Paneles compactos
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    _buildCompactPanel(isTop: true, maxHeight: constraints.maxHeight * 0.45),
                    const SizedBox(height: 16),
                    _buildCompactPanel(isTop: false, maxHeight: constraints.maxHeight * 0.45),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          
          // Intentos sutiles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _localAttempts ? AppTheme.accentGold : Colors.white10,
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPanel({required bool isTop, required double maxHeight}) {
    bool hasTarget = isTop == _targetInTopImage;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleTap(isTop),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Stack(
            children: [
              // Distractors
              ..._distractors.map((d) => Positioned(
                left: d.position.dx * (MediaQuery.of(context).size.width - 80),
                top: d.position.dy * maxHeight,
                child: Opacity(
                  opacity: 0.3,
                  child: Transform.rotate(
                    angle: d.rotation,
                    child: Icon(d.icon, color: Colors.white, size: d.size),
                  ),
                ),
              )),
              
              // Target (Now visually identical to distractors)
              if (hasTarget)
                Positioned(
                  left: _targetPosition.dx * (MediaQuery.of(context).size.width - 80),
                  top: _targetPosition.dy * maxHeight,
                  child: Opacity(
                    opacity: 0.3,
                    child: Icon(_targetIcon, color: Colors.white, size: 22),
                  ),
                ),
                
              // Label sutil
              Positioned(
                top: 12,
                left: 12,
                child: Text(
                  isTop ? "A" : "B",
                  style: const TextStyle(color: Colors.white10, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistractorItem {
  final IconData icon;
  final Offset position;
  final double rotation;
  final double size;

  _DistractorItem({
    required this.icon,
    required this.position,
    required this.rotation,
    required this.size,
  });
}