import 'package:flutter/material.dart';

/// A red flash overlay that briefly shows when the player loses a life.
/// It watches the `lives` value and triggers a red flash animation
/// whenever lives decrease.
class LossFlashOverlay extends StatefulWidget {
  final int lives;

  const LossFlashOverlay({super.key, required this.lives});

  @override
  State<LossFlashOverlay> createState() => _LossFlashOverlayState();
}

class _LossFlashOverlayState extends State<LossFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  int _previousLives = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0, // Start at end (opacity = 0.0, invisible)
    );
    _opacityAnimation = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _previousLives = widget.lives;
  }

  @override
  void didUpdateWidget(covariant LossFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only flash when lives decrease (not on first build)
    if (_previousLives > 0 && widget.lives < _previousLives) {
      _controller.forward(from: 0.0);
    }
    _previousLives = widget.lives;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        if (_opacityAnimation.value <= 0.0) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.red.withOpacity(_opacityAnimation.value),
            ),
          ),
        );
      },
    );
  }
}
