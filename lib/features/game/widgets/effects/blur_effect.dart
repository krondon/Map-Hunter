import 'dart:ui';
import 'package:flutter/material.dart';

class BlurScreenEffect extends StatefulWidget {
  const BlurScreenEffect({super.key});

  @override
  State<BlurScreenEffect> createState() => _BlurScreenEffectState();
}

class _BlurScreenEffectState extends State<BlurScreenEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.05, end: 0.18)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double blur = 3 + (_controller.value * 3);
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(_opacity.value),
                  ],
                  radius: 1.2,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(_opacity.value),
                  width: 1.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
