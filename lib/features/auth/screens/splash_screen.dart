import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'dart:async';
import 'login_screen.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late AnimationController _shimmerTitleController;

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

    // Controlador para el brillo del texto
    _shimmerTitleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
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
    _shimmerTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo (La que subiste)
          Image.asset(
            'assets/images/intro_bg.png',
            fit: BoxFit.cover,
          ),
          
          // Overlay oscuro sutil para legibilidad
          Container(
            color: Colors.black.withOpacity(0.4),
          ),

          // Fondo de partículas o radar (opcional, lo mantenemos sobre la imagen)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                painter: RadarPainter(_pulseController.value),
                size: Size.infinite,
              );
            },
          ),

          Stack(
            alignment: Alignment.center,
            children: [

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo de MapHunter central
                Image.asset(
                  'assets/images/logo4.1.png',
                  height: 250,
                  fit: BoxFit.contain,
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
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
      final double opacity =
          (1.0 - ((animationValue + i * 0.33) % 1.0)).clamp(0.0, 1.0);
      final double radius = maxRadius * ((animationValue + i * 0.33) % 1.0);

      paint.color = AppTheme.primaryPurple.withOpacity(opacity * 0.3);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}

class _GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _GlitchText({required this.text, required this.style});

  @override
  State<_GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<_GlitchText> with SingleTickerProviderStateMixin {
  late AnimationController _glitchController;
  late String _displayText;
  final String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
  Timer? _decodeTimer;
  int _decodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _displayText = '';
    // Start Decoding
    _startDecoding();

    // Glitch Animation
    _glitchController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000)
    )..repeat();
  }

  void _startDecoding() {
    _decodeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_decodeIndex >= widget.text.length) {
        timer.cancel();
        setState(() => _displayText = widget.text);
        return;
      }

      setState(() {
        _displayText = String.fromCharCodes(Iterable.generate(widget.text.length, (index) {
          if (index < _decodeIndex) return widget.text.codeUnitAt(index);
          return _chars.codeUnitAt(math.Random().nextInt(_chars.length));
        }));
        _decodeIndex++;
      });
    });
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _decodeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        final double glitchValue = _glitchController.value;
        // Glitch trigger occasionally
        final bool isGlitching = glitchValue > 0.90 && glitchValue < 0.95;
        
        double offsetX = 0;
        double offsetY = 0;
        
        if (isGlitching) {
          offsetX = (math.Random().nextDouble() - 0.5) * 5;
          offsetY = (math.Random().nextDouble() - 0.5) * 5;
        }

        return Stack(
          children: [
             // Red Channel
            if (isGlitching)
              Transform.translate(
                offset: Offset(offsetX + 2, offsetY),
                child: Text(
                  _displayText,
                  style: widget.style.copyWith(color: Colors.red.withOpacity(0.8)),
                ),
              ),
            // Blue Channel
            if (isGlitching)
              Transform.translate(
                offset: Offset(offsetX - 2, offsetY),
                child: Text(
                  _displayText,
                  style: widget.style.copyWith(color: Colors.blue.withOpacity(0.8)),
                ),
              ),
            // Main Text
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Text(
                _displayText,
                style: widget.style,
              ),
            ),
          ],
        );
      },
    );
  }
}
