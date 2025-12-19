import 'package:flutter/material.dart';

class PowerGestureWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback onSwipeUp;

  const PowerGestureWrapper({
    super.key, 
    required this.child, 
    required this.onSwipeUp
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        // Si la velocidad es negativa, el movimiento fue hacia ARRIBA
        if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
          onSwipeUp();
        }
      },
      child: child,
    );
  }
}