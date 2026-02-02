import 'package:flutter/material.dart';

class StealFailedEffect extends StatefulWidget {
  final String message;
  
  const StealFailedEffect({
    super.key,
    this.message = '¡No tiene vidas que robar!',
  });

  @override
  State<StealFailedEffect> createState() => _StealFailedEffectState();
}

class _StealFailedEffectState extends State<StealFailedEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flashOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: 0.0), weight: 32),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween(1.12), weight: 35),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _iconOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 6.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              Container(color: Colors.red.withOpacity(_flashOpacity.value)),
              Center(
                child: Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.translate(
                    offset: Offset(_shake.value, 0),
                    child: Transform.scale(
                      scale: _iconScale.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💔', style: TextStyle(fontSize: 84)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.redAccent, width: 2),
                            ),
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
