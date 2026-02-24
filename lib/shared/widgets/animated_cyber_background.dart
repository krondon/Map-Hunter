import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:treasure_hunt_rpg/core/theme/app_theme.dart';

class AnimatedCyberBackground extends StatefulWidget {
  final Widget? child;
  final Color? gridColor;
  final Color? vignetteColor;

  const AnimatedCyberBackground({
    super.key,
    this.child,
    this.gridColor,
    this.vignetteColor,
  });

  @override
  State<AnimatedCyberBackground> createState() => _AnimatedCyberBackgroundState();
}

class _AnimatedCyberBackgroundState extends State<AnimatedCyberBackground>
    with TickerProviderStateMixin {
  late AnimationController _gridController;
  late AnimationController _particleController;
  final List<BackgroundParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Initialize random particles
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
        _particles.add(BackgroundParticle(
          x: random.nextDouble() * 100,
          y: random.nextDouble() * 100,
          size: 1 + random.nextDouble() * 2,
          speed: 0.2 + random.nextDouble() * 0.8,
          opacity: 0.1 + random.nextDouble() * 0.3,
        ));
    }
  }

  @override
  void dispose() {
    _gridController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = true /* always dark UI */;
    final color = widget.gridColor ?? const Color(0xFF6366F1); // Always use dark mode color

    return Stack(
      children: [
        // 0. Background Base
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(-0.8, -0.6),
                radius: 1.5,
                colors: [
                  AppTheme.dSurface1,
                  AppTheme.dSurface0,
                ],
              ),
            ),
          ),
        ),

        // 1. Grid
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _gridController,
            builder: (context, child) {
              return CustomPaint(
                painter: _GridPainter(_gridController.value, color),
              );
            },
          ),
        ),
        
        // 2. Moving Particles
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(_particleController.value, _particles, color),
              );
            },
          ),
        ),

        // 3. Vignette / Subtle Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  (widget.vignetteColor ?? Colors.black).withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),

        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class BackgroundParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  BackgroundParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _GridPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GridPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;
    final double offset = progress * spacing;

    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(
        Offset(0, y + (offset % spacing)),
        Offset(size.width, y + (offset % spacing)),
        paint,
      );
    }
    for (double x = 0; x < size.width + spacing; x += spacing) {
      canvas.drawLine(
        Offset(x + (offset % spacing), 0),
        Offset(x + (offset % spacing), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<BackgroundParticle> particles;
  final Color color;

  _ParticlePainter(this.progress, this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      final x = (p.x / 100) * size.width;
      final y = ((p.y + (progress * p.speed * 100)) % 100 / 100) * size.height;

      canvas.drawCircle(Offset(x, y), p.size, paint);
      
      // Subtle glow
      final glowPaint = Paint()
        ..color = color.withOpacity(p.opacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), p.size * 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
