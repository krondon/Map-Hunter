import 'dart:async';
import 'package:flutter/material.dart';

class InvisibilityEffect extends StatefulWidget {
  final DateTime? expiresAt; // Recibe la fecha de fin
  const InvisibilityEffect({super.key, this.expiresAt});

  @override
  State<InvisibilityEffect> createState() => _InvisibilityEffectState();
}

class _InvisibilityEffectState extends State<InvisibilityEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startCountdown(); // Inicia el contador visual
  }

  void _startCountdown() {
    _updateSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateSeconds();
    });
  }

  void _updateSeconds() {
    if (widget.expiresAt == null) return;
    // Calcula la diferencia entre ahora y la expiración en UTC
    final diff = widget.expiresAt!.difference(DateTime.now().toUtc()).inSeconds;
    setState(() {
      _secondsLeft = diff < 0 ? 0 : diff;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = _controller.value;
          return Stack(
            children: [
              // Viñeta púrpura que pulsa
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.4,
                    colors: [
                      Colors.transparent,
                      Colors.deepPurple.withOpacity(0.1 * pulse),
                      Colors.black.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
              // Contador en pantalla
              Positioned(
                top: 80,
                right: 30,
                child: Column(
                  children: [
                    Icon(Icons.visibility_off, color: Colors.purpleAccent, size: 40 + (pulse * 5)),
                    const SizedBox(height: 5),
                    Text(
                      "00:${_secondsLeft.toString().padLeft(2, '0')}", // Formato 00:XX
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                    const Text("SIGILO ACTIVO", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}