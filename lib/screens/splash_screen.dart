import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'login_screen.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  
  final List<String> _loadingPhrases = [
    "Calibrando brújula...",
    "Descifrando mapas antiguos...",
    "Escondiendo tesoros...",
    "Convocando a los espíritus...",
    "Afilando espadas...",
  ];
  
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // Controlador para el logo giratorio
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Controlador para el efecto de pulso (radar)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Cambiar frases cada 800ms
    _cyclePhrases();

    // Navegar después de 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }
  
  void _cyclePhrases() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _phraseIndex = (i + 1) % _loadingPhrases.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fondo de partículas o radar
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarPainter(_pulseController.value),
                  size: Size.infinite,
                );
              },
            ),
            
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Animado
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Círculos externos girando
                    RotationTransition(
                      turns: _controller,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryPurple.withOpacity(0.5),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Icon(
                          Icons.explore,
                          size: 80,
                          color: AppTheme.accentGold,
                        ),
                      ),
                    ),
                    // Brillo central
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGold.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Título
                const Text(
                  'TREASURE HUNT',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                    fontFamily: 'sans-serif',
                  ),
                ),
                
                const Text(
                  'RPG',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.secondaryPink,
                    letterSpacing: 8,
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Frases de carga cambiantes
                SizedBox(
                  height: 30,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _loadingPhrases[_phraseIndex],
                      key: ValueKey<int>(_phraseIndex),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Barra de progreso
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Pintor para el efecto de radar de fondo
class RadarPainter extends CustomPainter {
  final double animationValue;

  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.8;
    
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Dibujar 3 ondas expansivas
    for (int i = 0; i < 3; i++) {
      final double opacity = (1.0 - ((animationValue + i * 0.33) % 1.0)).clamp(0.0, 1.0);
      final double radius = maxRadius * ((animationValue + i * 0.33) % 1.0);
      
      paint.color = AppTheme.primaryPurple.withOpacity(opacity * 0.3);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}
