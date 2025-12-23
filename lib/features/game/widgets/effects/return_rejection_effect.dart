import 'package:flutter/material.dart';

class ReturnRejectionEffect extends StatefulWidget {
  final String? returnedBy;

  const ReturnRejectionEffect({super.key, this.returnedBy});

  @override
  State<ReturnRejectionEffect> createState() => _ReturnRejectionEffectState();
}

class _ReturnRejectionEffectState extends State<ReturnRejectionEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.1).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 60),
    ]).animate(_controller);

    _shake = Tween<double>(begin: -6.0, end: 6.0).chain(CurveTween(curve: Curves.elasticIn)).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: size.width * 0.85,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.cyanAccent, width: 3), // Cyan para efecto espejo
            boxShadow: [
              BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5),
              BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 0)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de Espejo / Reflejo
              Stack(
                alignment: Alignment.center,
                children: [
                   const Icon(Icons.shield, color: Colors.cyanAccent, size: 90),
                   Icon(Icons.u_turn_left, color: Colors.black.withOpacity(0.8), size: 50),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "¡ESPEJO ACTIVADO!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(color: Colors.blue, blurRadius: 10, offset: Offset(0,0))
                  ]
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white24, indent: 40, endIndent: 40),
              ),
              const Text(
                "Tu hechizo rebotó contra:",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                widget.returnedBy?.toUpperCase() ?? "UN RIVAL",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.purpleAccent, blurRadius: 15)
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "¡AHORA SUFRES TU PROPIO EFECTO!",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}