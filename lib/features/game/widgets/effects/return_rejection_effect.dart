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
            border: Border.all(color: Colors.redAccent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
              BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 15, offset: const Offset(-5, -5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 85),
              const SizedBox(height: 20),
              const Text(
                "¡ATAQUE RECHAZADO!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white24, indent: 40, endIndent: 40),
              ),
              Text(
                "Tu poder ha sido devuelto por:",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                widget.returnedBy?.toUpperCase() ?? "UN RIVAL",
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.purpleAccent, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.bolt, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "HAS RECIBIDO TU PROPIO EFECTO",
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
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