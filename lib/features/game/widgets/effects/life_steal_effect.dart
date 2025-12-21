import 'package:flutter/material.dart';

class LifeStealEffect extends StatefulWidget {
  final String casterName;

  const LifeStealEffect({super.key, required this.casterName});

  @override
  State<LifeStealEffect> createState() => _LifeStealEffectState();
}

class _LifeStealEffectState extends State<LifeStealEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _flashOpacity;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500), // Duración total
    );

    // 1. Efecto de Flash Inicial (rápido)
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.7), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 70),
    ]).animate(_controller);

    // 2. Escala del texto con rebote
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween(1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.0), weight: 20),
    ]).animate(_controller);

    // 3. Sacudida (Shake) leve
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 85),
    ]).animate(_controller);

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
        builder: (context, child) {
          return Stack(
            children: [
              // Capa de Flash Rojo
              Container(
                color: Colors.red.withOpacity(_flashOpacity.value),
              ),
              
              // Animación Central
              Center(
                child: Transform.translate(
                  offset: Offset(_shake.value, 0),
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icono de impacto
                        const Text('💔', style: TextStyle(fontSize: 80)),
                        const SizedBox(height: 20),
                        
                        // Mensaje Principal
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              // Busca esta parte en el mensaje principal:
                                  Text(
                                    widget.casterName.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900, // <--- Cambia .black por .w900
                                    ),
                                  ),
                              const Text(
                                '¡TE HA ROBADO UNA VIDA!',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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