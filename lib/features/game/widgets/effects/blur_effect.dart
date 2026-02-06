import 'dart:ui';
import 'package:flutter/material.dart';
import 'effect_timer.dart';

class BlurScreenEffect extends StatefulWidget {
  final DateTime expiresAt;

  const BlurScreenEffect({super.key, required this.expiresAt});

  @override
  State<BlurScreenEffect> createState() => _BlurScreenEffectState();
}

class _BlurScreenEffectState extends State<BlurScreenEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  // Progressive blur: starts clear, gets blurrier over ~4 seconds
  static const double maxBlur = 15.0; // Strong blur effect
  static const Duration blurDuration = Duration(milliseconds: 4000);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: blurDuration,
    )..forward(); // Forward only, no repeat - progressive blur

    // Blur goes from 0 to maxBlur
    _blurAnimation = Tween<double>(begin: 0, end: maxBlur)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_controller);

    // Opacity for overlay tint
    _opacityAnimation = Tween<double>(begin: 0, end: 0.25)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer allows clicks to pass through to the game
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        fit: StackFit.expand, // Force stack to fill the screen
        children: [
          // 1. The visual blur filter
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double blur = _blurAnimation.value;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  color: Colors.black.withOpacity(_opacityAnimation.value * 0.6),
                ),
              );
            },
          ),

          // 2. Timer at Top Center
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: EffectTimer(expiresAt: widget.expiresAt),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
