import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';

// --- WRAPPER ---
class FindDifferenceWrapper extends StatelessWidget {
  final Clue clue;
  const FindDifferenceWrapper({super.key, required this.clue});

  @override
  Widget build(BuildContext context) {
    return FindDifferenceMinigame(
      clue: clue,
      onSuccess: () {
        Provider.of<GameProvider>(context, listen: false).completeCurrentClue("WIN", clueId: clue.id);
        Navigator.pop(context);
      },
      onFailure: () {
        // Opcional: Manejar fallo si es necesario fuera del widget
      },
    );
  }
}

// --- MINIGAME LOGIC ---

class FindDifferenceMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;
  final VoidCallback? onFailure;

  const FindDifferenceMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
    this.onFailure,
  });

  @override
  State<FindDifferenceMinigame> createState() => _FindDifferenceMinigameState();
}

class _FindDifferenceMinigameState extends State<FindDifferenceMinigame> {
  // Configuración del juego
  final int _numberOfDistractors = 40; // Cantidad de iconos de fondo
  final Random _random = Random();
  
  // Estado del nivel
  late IconData _targetIcon;
  late Color _targetColor;
  late Offset _targetPosition;
  late bool _targetInTopImage; // Si true, el objetivo está arriba. Si false, abajo.
  
  // Distractores (comunes a ambas imágenes)
  late List<_DistractorItem> _distractors;
  
  // Timer & Vidas
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _startNewLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewLevel() {
    setState(() {
      _secondsRemaining = 60;
      _isGameOver = false;
      
      // 1. Definir objetivo
      _targetIcon = _getRandomIcon();
      _targetColor = AppTheme.accentGold; // El objetivo siempre destaca o tiene color específico? 
      // El usuario dijo "que en las dos imagenes tenga los mismos iconos y en una imagen este el icono que buscamos"
      // Vamos a hacerlo un color distinto pero sutil, o el mismo color que el resto para que sea difícil?
      // "Find the difference" suele ser visual. Hagámoslo del color de los distractores para que sea reto visual por forma,
      // O un color especial si el usuario quiere buscar ESE icono específico.
      // Asumiremos color brillante para que coincida con "el icono que buscamos" mostrado en UI.
      
      _targetInTopImage = _random.nextBool(); // Aleatorio en cuál aparece

      // 2. Generar posiciones
      // Generamos distractores fijos para ambas imágenes
      _distractors = List.generate(_numberOfDistractors, (index) {
        return _DistractorItem(
          icon: _getRandomIcon(),
          color: Colors.white.withOpacity(0.3 + _random.nextDouble() * 0.4),
          position: Offset(_random.nextDouble(), _random.nextDouble()),
          size: 20 + _random.nextDouble() * 20,
          rotation: _random.nextDouble() * 2 * pi,
        );
      });

      // Posición del objetivo (asegurar que no esté muy cerca de bordes)
      _targetPosition = Offset(
        0.1 + _random.nextDouble() * 0.8,
        0.1 + _random.nextDouble() * 0.8,
      );
      
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _handleGameOver("¡Se acabó el tiempo!");
        }
      });
    });
  }

  void _handleTap(bool isTopImage, TapUpDetails details, BoxConstraints constraints) {
    if (_isGameOver) return;

    // Verificar si tocó cerca del objetivo
    // Solo es válido si tocó en la imagen CORRECTA (donde está el objetivo)
    if (isTopImage != _targetInTopImage) {
        // Tocó la imagen donde NO está el objetivo (o sea, es un falso positivo si buscamos el extra)
        // El usuario dijo: "en una imagen este el icono que buscamos". 
        // Si el usuario toca donde DEBERIA estar pero no está, es error?
        // Asumamos que el usuario debe tocar EL ICONO.
        _handleMistake();
        return;
    }

    // Convertir coordenadas relativas
    final double dx = details.localPosition.dx / constraints.maxWidth;
    final double dy = details.localPosition.dy / constraints.maxHeight;
    final Offset tapPos = Offset(dx, dy);
    
    // Distancia simple
    final double distance = (tapPos - _targetPosition).distance;
    
    // Umbral de acierto (ajustar según dificultad)
    if (distance < 0.1) { // ~10% de la pantalla
      _handleWin();
    } else {
      _handleMistake();
    }
  }

  void _handleWin() {
    _timer?.cancel();
    widget.onSuccess();
  }

  void _handleMistake() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.loseLife();

    if (playerProvider.currentPlayer != null && playerProvider.currentPlayer!.lives <= 0) {
      _handleGameOver("¡Te quedaste sin vidas!");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Ups! Ese no es.", style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _handleGameOver(String reason) {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡Fallaste!", style: TextStyle(color: AppTheme.dangerRed)),
        content: Text(reason, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar dialog
              Navigator.pop(context); // Salir minijuego
            },
            child: const Text("Salir"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold),
            onPressed: () {
              Navigator.pop(context); // Cerrar dialog
              // Reiniciar vidas si es necesario manualmente o confiar en el provider
              Provider.of<PlayerProvider>(context, listen: false).resetLives(); 
              _startNewLevel();
            },
            child: const Text("Reintentar", style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  IconData _getRandomIcon() {
    final icons = [
      Icons.star, Icons.ac_unit, Icons.access_alarm, Icons.directions_bike,
      Icons.flight, Icons.music_note, Icons.wb_sunny, Icons.pets,
      Icons.language, Icons.cake, Icons.emoji_events, Icons.extension,
      Icons.face, Icons.favorite, Icons.fingerprint, Icons.fire_extinguisher,
      Icons.flash_on, Icons.filter_vintage, Icons.camera_alt, Icons.brush,
    ];
    return icons[_random.nextInt(icons.length)];
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        // --- HEADER INFORMATIVO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black45,
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Objetivo
              Row(
                children: [
                   const Text("BUSCA:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                   const SizedBox(width: 8),
                   Container(
                     padding: const EdgeInsets.all(4),
                     decoration: BoxDecoration(
                       color: AppTheme.accentGold.withOpacity(0.2),
                       shape: BoxShape.circle,
                       border: Border.all(color: AppTheme.accentGold)
                     ),
                     child: Icon(_targetIcon, color: AppTheme.accentGold, size: 24),
                   ),
                ],
              ),
              
              // Tiempo central
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white24)
                ),
                child: Text(
                  "$minutes:$seconds",
                  style: TextStyle(
                    color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace'
                  ),
                ),
              ),

              // Vidas
              Consumer<PlayerProvider>(
                builder: (context, player, _) => Row(
                  children: List.generate(3, (index) => Icon(
                    index < (player.currentPlayer?.lives ?? 0) ? Icons.favorite : Icons.favorite_border,
                    color: AppTheme.dangerRed,
                    size: 18,
                  )),
                ),
              ),
            ],
          ),
        ),

        // --- ÁREA DE JUEGO (SPLIT SCREEN) ---
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Dividimos el espacio en 2
              return Column(
                children: [
                  // IMAGEN 1 (ARRIBA)
                  Expanded(
                    child: _buildGamePanel(
                      context: context, 
                      isTop: true, 
                      showTarget: _targetInTopImage
                    ),
                  ),
                  
                  // SEPARADOR VISUAL
                  Container(
                    height: 4,
                    width: double.infinity,
                    color: AppTheme.accentGold,
                    alignment: Alignment.center,
                    child: const Text("VS", style: TextStyle(color: Colors.black, fontSize: 3, fontWeight: FontWeight.bold)), // Decorativo
                  ),

                  // IMAGEN 2 (ABAJO)
                  Expanded(
                    child: _buildGamePanel(
                      context: context, 
                      isTop: false, 
                      showTarget: !_targetInTopImage
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGamePanel({required BuildContext context, required bool isTop, required bool showTarget}) {
    return Container(
      width: double.infinity,
      color: isTop ? const Color(0xFF1A1A2E) : const Color(0xFF16213E), // Ligeramente distintos fondos para diferenciar? O idénticos?
      // Mejor idénticos para que sea "encuentra diferencia" real.
      // color: const Color(0xFF1E1E1E), 
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) => _handleTap(isTop, details, constraints),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                 // Fondo estático o patrón (opcional)
                 Positioned.fill(child: Container(color: const Color(0xFF1E1E1E))),

                 // 1. Distractores (Idénticos en ambos paneles)
                 ..._distractors.map((d) => Positioned(
                   left: d.position.dx * constraints.maxWidth,
                   top: d.position.dy * constraints.maxHeight,
                   child: Transform.rotate(
                     angle: d.rotation,
                     child: Icon(
                       d.icon,
                       color: d.color,
                       size: d.size,
                     ),
                   ),
                 )),

                 // 2. Objetivo (Solo si showTarget == true)
                 if (showTarget)
                   Positioned(
                     left: _targetPosition.dx * constraints.maxWidth,
                     top: _targetPosition.dy * constraints.maxHeight,
                     child: TweenAnimationBuilder(
                       tween: Tween<double>(begin: 0.8, end: 1.2),
                       duration: const Duration(milliseconds: 1000),
                       builder: (context, val, child) {
                          return Transform.scale(
                            scale: val, // Sutil palpito? No, mejor estático si es difícil.
                            // Si lo hacemos muy obvio es fácil. 
                            // El original "Find Object" era difícil.
                            // Hagámoslo estático pero con el color del objetivo.
                            // scale: 1.0, 
                            child: Icon(
                              _targetIcon,
                              color: _targetColor,
                              size: 32, // Un poco más grande o igual?
                            ),
                          );
                       },
                       onEnd: () {}, // Loop animation manually if needed
                     ),
                   ),
                   
                 // Indicador visual de qué panel es (opcional)
                 Positioned(
                   top: 8,
                   left: 8,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     color: Colors.black26,
                     child: Text(isTop ? "IMG A" : "IMG B", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                   ),
                 ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DistractorItem {
  final IconData icon;
  final Color color;
  final Offset position;
  final double size;
  final double rotation;

  _DistractorItem({
    required this.icon,
    required this.color,
    required this.position,
    required this.size,
    required this.rotation,
  });
}
