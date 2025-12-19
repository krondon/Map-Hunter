import 'package:flutter/material.dart';

class FreezeEffect extends StatelessWidget {
  const FreezeEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true, // Bloquea todos los toques en la pantalla
      child: Container(
        // Color azul traslúcido tipo hielo
        color: Colors.blue.withOpacity(0.35),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de nieve con sombra para que resalte
              const Icon(
                Icons.ac_unit,
                color: Colors.white,
                size: 100,
                shadows: [Shadow(blurRadius: 20, color: Colors.blueAccent)],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  "¡CONGELADO!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}