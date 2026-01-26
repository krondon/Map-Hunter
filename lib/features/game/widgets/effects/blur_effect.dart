import 'dart:ui';
import 'package:flutter/material.dart';
import 'effect_timer.dart';

class BlurScreenEffect extends StatefulWidget {
  final DateTime? expiresAt;
  const BlurScreenEffect({super.key, this.expiresAt});

  @override
  State<BlurScreenEffect> createState() => _BlurScreenEffectState();
}

class _BlurScreenEffectState extends State<BlurScreenEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  // Progressive blur: starts clear, gets blurrier over ~4 seconds
  static const double maxBlur = 12.0; // Strong blur effect
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
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double blur = _blurAnimation.value;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  decoration: BoxDecoration(
                    // White haze overlay that also fades in
                    color: Colors.white.withOpacity(_opacityAnimation.value),
                  ),
                ),
              );
            },
          ),
          if (widget.expiresAt != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: EffectTimer(expiresAt: widget.expiresAt!),
              ),
            ),
        ],
      ),
    );
  }
}
