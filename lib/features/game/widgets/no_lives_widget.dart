import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../mall/screens/mall_screen.dart';

class NoLivesWidget extends StatefulWidget {
  const NoLivesWidget({super.key});

  @override
  State<NoLivesWidget> createState() => _NoLivesWidgetState();
}

class _NoLivesWidgetState extends State<NoLivesWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late AnimationController _shakeController;
  late AnimationController _particleController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    // Pulse glow loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Entry animations
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryController,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _entryController,
          curve: const Interval(0.3, 0.8, curve: Curves.easeOut)),
    );

    // Shake effect on entry
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );

    // Floating particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Start entry sequence
    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _shakeController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    _shakeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_entryController, _pulseController, _shakeController, _particleController]),
      builder: (context, _) {
        final shakeOffset = sin(_shakeAnim.value * pi * 6) *
            (1 - _shakeAnim.value) *
            12;

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                AppTheme.dangerRed.withOpacity(0.15 * _pulseAnim.value),
                Colors.black,
                Colors.black,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Floating broken heart particles
              ..._buildFloatingParticles(),

              // Main content
              Center(
                child: Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated heart icon with glow
                        Transform.scale(
                          scale: _scaleAnim.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow ring
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.dangerRed
                                          .withOpacity(0.3 * _pulseAnim.value),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              // Outer ring
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.dangerRed
                                        .withOpacity(0.3 * _pulseAnim.value),
                                    width: 2,
                                  ),
                                ),
                              ),
                              // Inner circle
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.dangerRed.withOpacity(0.1),
                                  border: Border.all(
                                    color: AppTheme.dangerRed
                                        .withOpacity(0.6 * _pulseAnim.value),
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.heart_broken,
                                  color: AppTheme.dangerRed,
                                  size: 44,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title with glitch-like styling
                        Transform.translate(
                          offset: Offset(0, _slideAnim.value),
                          child: Column(
                            children: [
                              const Text(
                                "GAME OVER",
                                style: TextStyle(
                                  color: AppTheme.dangerRed,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Orbitron',
                                  letterSpacing: 4,
                                  decoration: TextDecoration.none,
                                  shadows: [
                                    Shadow(
                                      color: AppTheme.dangerRed,
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 80,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppTheme.dangerRed.withOpacity(_pulseAnim.value),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        Transform.translate(
                          offset: Offset(0, _slideAnim.value * 1.2),
                          child: const Text(
                            "¡Te has quedado sin vidas!",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Transform.translate(
                          offset: Offset(0, _slideAnim.value * 1.4),
                          child: Text(
                            "Compra vidas en la tienda para seguir jugando",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Buttons with double-border cyberpunk style
                        Transform.translate(
                          offset: Offset(0, _slideAnim.value * 1.6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              children: [
                                // Primary: Comprar Vidas
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppTheme.accentGold.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.accentGold.withOpacity(0.9),
                                          AppTheme.accentGold,
                                        ],
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const MallScreen()),
                                          );
                                          if (!context.mounted) return;
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.shopping_cart,
                                                  color: Colors.black,
                                                  size: 20),
                                              SizedBox(width: 10),
                                              Text(
                                                "COMPRAR VIDAS",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Secondary: Salir
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1D),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: () => Navigator.of(context).pop(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.exit_to_app,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                  size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                "SALIR",
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFloatingParticles() {
    final random = Random(42);
    return List.generate(12, (i) {
      final startX = random.nextDouble();
      final startY = random.nextDouble();
      final size = 6.0 + random.nextDouble() * 10;
      final speed = 0.5 + random.nextDouble() * 0.5;
      final phase = random.nextDouble() * 2 * pi;

      return AnimatedBuilder(
        animation: _particleController,
        builder: (context, _) {
          final t = (_particleController.value * speed + phase) % 1.0;
          final x = startX * MediaQuery.of(context).size.width;
          final y = MediaQuery.of(context).size.height * (1.0 - t);
          final opacity = sin(t * pi) * 0.4 * _fadeAnim.value;

          return Positioned(
            left: x + sin(t * pi * 3 + phase) * 30,
            top: y,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Icon(
                i % 3 == 0
                    ? Icons.heart_broken
                    : (i % 3 == 1 ? Icons.favorite : Icons.close),
                color: AppTheme.dangerRed,
                size: size,
              ),
            ),
          );
        },
      );
    });
  }
}
