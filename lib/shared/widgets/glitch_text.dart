import 'dart:math' as math;
import 'package:flutter/material.dart';

class GlitchText extends StatefulWidget {
  final String text;
  final double fontSize;
  final Duration duration;

  const GlitchText({
    super.key,
    required this.text,
    this.fontSize = 46.0,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> with SingleTickerProviderStateMixin {
  late AnimationController _glitchController;

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        final double value = _glitchController.value;
        const Color primaryColor = Color(0xFFFAE500); // Cyberpunk bright yellow

        // Much slower oscillation (10x instead of 40x)
        double offsetX = math.sin(value * 10 * math.pi) * 0.5;
        double offsetY = math.cos(value * 8 * math.pi) * 0.3;

        // Chromatic aberrations breathing much slower (5x instead of 20x)
        double cyanX = offsetX - 1.5 - (math.sin(value * 5 * math.pi) * 2.0);
        double magX = offsetX + 1.5 + (math.cos(value * 5 * math.pi) * 2.0);

        // Softer periodic spikes
        double spike = 0.0;
        if (value > 0.45 && value < 0.50) {
          spike = 3.0 * math.sin((value - 0.45) * 20 * math.pi);
        } else if (value > 0.90 && value < 0.95) {
          spike = -2.0 * math.sin((value - 0.90) * 20 * math.pi);
        }
        offsetX += spike;

        return Stack(
          children: [
            // Cyan Shadow (Rhythmic vibration)
            Transform.translate(
              offset: Offset(cyanX, offsetY),
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00FFFF).withOpacity(0.6),
                  letterSpacing: 1,
                  height: 1.0,
                ),
              ),
            ),
            // Magenta Shadow (Rhythmic vibration)
            Transform.translate(
              offset: Offset(magX, offsetY),
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFF00FF).withOpacity(0.6),
                  letterSpacing: 1,
                  height: 1.0,
                ),
              ),
            ),
            // Primary Yellow Text
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  color: value > 0.98 ? Colors.white : primaryColor,
                  letterSpacing: 1,
                  height: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
