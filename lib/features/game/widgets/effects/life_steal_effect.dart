import 'package:flutter/material.dart';

class LifeStealEffect extends StatefulWidget {
  final String? casterName;

  const LifeStealEffect({super.key, this.casterName});

  @override
  State<LifeStealEffect> createState() => _LifeStealEffectState();
}

class _LifeStealEffectState extends State<LifeStealEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _travel;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _travel = Tween<Offset>(
      begin: const Offset(-0.15, 0.2),
      end: const Offset(0.2, -0.25),
    ).chain(CurveTween(curve: Curves.easeInOutCubic))
     .animate(_controller);

    _opacity = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _controller.reverse();
        });
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
      ignoring: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  color: Colors.red.withOpacity(0.08 * _opacity.value + 0.02),
                );
              },
            ),
          ),
          Center(
            child: SlideTransition(
              position: _travel,
              child: FadeTransition(
                opacity: _opacity,
                child: Transform.scale(
                  scale: 0.9 + (_controller.value * 0.3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🧛',
                        style: TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.casterName != null && widget.casterName!.isNotEmpty
                            ? '¡${widget.casterName} te ha robado una vida!'
                            : '¡Te robaron una vida!',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
