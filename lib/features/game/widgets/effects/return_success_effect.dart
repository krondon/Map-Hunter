import 'package:flutter/material.dart';

class ReturnSuccessEffect extends StatefulWidget {
  const ReturnSuccessEffect({super.key});

  @override
  State<ReturnSuccessEffect> createState() => _ReturnSuccessEffectState();
}

class _ReturnSuccessEffectState extends State<ReturnSuccessEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulse = Tween<double>(begin: 0.0, end: 1.5).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _pulse,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple.withOpacity(0.2),
            border: Border.all(color: Colors.purpleAccent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.replay_circle_filled, color: Colors.white, size: 80),
              SizedBox(height: 10),
              Text(
            "¡ATAQUE DEVUELTO!", 
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w900, // CAMBIADO: w900 en lugar de black
              fontSize: 22, 
              letterSpacing: 1.5,
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}