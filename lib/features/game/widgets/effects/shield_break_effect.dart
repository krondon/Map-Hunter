import 'package:flutter/material.dart';

class ShieldBreakEffect extends StatefulWidget {
  final VoidCallback? onComplete;

  const ShieldBreakEffect({super.key, this.onComplete});

  @override
  State<ShieldBreakEffect> createState() => _ShieldBreakEffectState();
}

class _ShieldBreakEffectState extends State<ShieldBreakEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnim = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward().then((_) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: const Icon(
                  Icons.shield_outlined,
                  size: 150,
                  color: Colors.cyanAccent,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
