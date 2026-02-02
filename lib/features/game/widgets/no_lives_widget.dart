import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../mall/screens/mall_screen.dart';

class NoLivesWidget extends StatelessWidget {
  const NoLivesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.heart_broken,
                color: AppTheme.dangerRed, size: 64),
            const SizedBox(height: 20),
            const Text(
              "¡SIN VIDAS!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "No puedes jugar sin vidas.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón Salir
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("SALIR"),
                ),
                const SizedBox(width: 16),
                // Botón Comprar Vidas
                ElevatedButton(
                  onPressed: () async {
                    // Ir a la tienda
                    await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const MallScreen()));
                    
                    // Al regresar, verificar si el contexto sigue montado
                    if (!context.mounted) return;
                    
                    // El puzzle_screen volverá a verificar las vidas
                    // y mostrará el minijuego si ahora tiene vidas
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("COMPRAR VIDAS",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
