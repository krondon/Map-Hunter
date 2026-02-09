import 'package:flutter/material.dart';
import 'effect_timer.dart';

class FreezeEffect extends StatefulWidget {
  final DateTime? expiresAt;
  const FreezeEffect({super.key, this.expiresAt});

  @override
  State<FreezeEffect> createState() => _FreezeEffectState();
}

class _FreezeEffectState extends State<FreezeEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: isDarkMode 
                ? [Colors.blue.withOpacity(0.3), Colors.blue.shade900.withOpacity(0.8)]
                : [Colors.blue.withOpacity(0.1), Colors.blue.shade200.withOpacity(0.6)],
              radius: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // 1. PUNTOS DE NIEVE CAYENDO (Animados)
              ...List.generate(40, (index) {
                final speed = (index % 5 + 2) * 1.5;
                final startX = (index * 17) % size.width;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = (_controller.value * speed + (index * 0.1)) % 1.0;
                    return Positioned(
                      top: (progress * size.height) - 10,
                      left: startX + (index % 2 == 0 ? 5 : -5) * (index % 3),
                      child: Container(
                        width: 2 + (index % 3).toDouble(),
                        height: 2 + (index % 3).toDouble(),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.6) : Colors.blueAccent.withOpacity(0.4),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.white.withOpacity(isDarkMode ? 0.8 : 0.4), blurRadius: 4),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),

              // 2. ICONOS DE COPOS DE NIEVE ESTÁTICOS (Distribuidos)
              _StaticSnowflake(top: size.height * 0.1, left: size.width * 0.15, size: 40, opacity: 0.3),
              _StaticSnowflake(top: size.height * 0.12, right: size.width * 0.2, size: 55, opacity: 0.2),
              _StaticSnowflake(top: size.height * 0.4, left: size.width * 0.05, size: 30, opacity: 0.25),
              _StaticSnowflake(top: size.height * 0.35, right: size.width * 0.1, size: 45, opacity: 0.15),
              _StaticSnowflake(bottom: size.height * 0.2, left: size.width * 0.1, size: 50, opacity: 0.2),
              _StaticSnowflake(bottom: size.height * 0.15, right: size.width * 0.15, size: 35, opacity: 0.3),
              _StaticSnowflake(bottom: size.height * 0.4, right: size.width * 0.05, size: 25, opacity: 0.2),

              // 3. CONTENIDO CENTRAL
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono central con rotación muy lenta (casi estática)
                    Icon(
                      Icons.ac_unit_rounded,
                      color: isDarkMode ? Colors.white : Colors.blue.shade900,
                      size: 110,
                      shadows: [
                        Shadow(blurRadius: 30, color: Colors.blueAccent, offset: const Offset(0, 0)),
                        if (isDarkMode) const Shadow(blurRadius: 15, color: Colors.white, offset: Offset(0, 0)),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.blue.shade900.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        "¡CONGELADO!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.blue.shade900,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          decoration: TextDecoration.none,
                          shadows: [
                            Shadow(color: isDarkMode ? Colors.blue : Colors.blueAccent.withOpacity(0.3), blurRadius: 15),
                          ],
                        ),
                      ),
                    ),
                    if (widget.expiresAt != null) ...[
                      const SizedBox(height: 48),
                      EffectTimer(
                        expiresAt: widget.expiresAt!,
                        backgroundColor: isDarkMode ? Colors.blue.shade900.withOpacity(0.6) : Colors.white.withOpacity(0.8),
                        borderColor: Colors.blueAccent.withOpacity(0.5),
                        iconColor: isDarkMode ? Colors.cyanAccent : Colors.blue.shade900,
                        textColor: isDarkMode ? Colors.white : Colors.blue.shade900,
                      ),
                    ],
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

class _StaticSnowflake extends StatelessWidget {
  final double? top, bottom, left, right;
  final double size;
  final double opacity;

  const _StaticSnowflake({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Icon(
        Icons.ac_unit_rounded,
        color: Colors.white.withOpacity(opacity),
        size: size,
      ),
    );
  }
}
