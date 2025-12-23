import 'package:flutter/material.dart';

class ReturnSuccessEffect extends StatefulWidget {
  final String attackerName;
  final String? powerSlug;
  const ReturnSuccessEffect({
    super.key, 
    required this.attackerName, 
    this.powerSlug
  });

  @override
  State<ReturnSuccessEffect> createState() => _ReturnSuccessEffectState();
}

class _ReturnSuccessEffectState extends State<ReturnSuccessEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    
    // Slide in from right + Fade
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getPowerName(String? slug) {
    if (slug == null) return "un hechizo";
    switch(slug) {
      case 'black_screen': return "PANTALLA NEGRA";
      case 'freeze': return "CONGELAMIENTO";
      case 'life_steal': return "ROBO DE VIDA";
      case 'blur_screen': return "VISIÓN BORROSA";
      case 'invisibility': return "INVISIBILIDAD";
      default: return "un hechizo";
    }
  }

  @override
  Widget build(BuildContext context) {
    final powerName = _getPowerName(widget.powerSlug);

    // Usamos SafeArea + Align para posicionarlo "al costado" (arriba a la derecha o izquierda)
    // Sin bloquear el resto de la pantalla.
    return Positioned(
      top: 60, // Un poco abajo para no tapar headers si los hay
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.2, 0), // Entra desde la derecha
          end: Offset.zero,
        ).animate(_scale),
        child: FadeTransition(
          opacity: _scale,
          child: Container(
            width: 280, // Ancho fijo para tarjeta compacta
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "¡REBOTE EXITOSO!",
                        style: TextStyle(
                          color: Colors.cyanAccent.shade100,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: "Has devuelto ",
                      ),
                      TextSpan(
                        text: powerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const TextSpan(
                        text: " a ",
                      ),
                      TextSpan(
                        text: widget.attackerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const TextSpan(
                        text: ".",
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "¡Sigue jugando!",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}