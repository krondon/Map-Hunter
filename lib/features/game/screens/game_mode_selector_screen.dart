import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../auth/providers/player_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'scenarios_screen.dart';
import 'game_request_screen.dart'; // Mantener import por si se usa en futuro

class GameModeSelectorScreen extends StatefulWidget {
  const GameModeSelectorScreen({super.key});

  @override
  State<GameModeSelectorScreen> createState() => _GameModeSelectorScreenState();
}

class _GameModeSelectorScreenState extends State<GameModeSelectorScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial_MODE_SELECTOR') ?? false;

    if (!hasSeen && mounted) {
      final steps = MasterTutorialContent.getStepsForSection('MODE_SELECTOR', context);
      if (steps.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CyberTutorialOverlay(
              steps: steps,
              onFinish: () async {
                Navigator.pop(context);
                await prefs.setBool('has_seen_tutorial_MODE_SELECTOR', true);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.dSurface0 : AppTheme.lSurface0,
      body: Stack(
        children: [
           // BACKGROUND (Mismo que Login)
           Positioned.fill(
            child: isDarkMode
                ? Opacity(
                    opacity: 0.7,
                    child: Image.asset(
                      'assets/images/hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  )
                : Stack(
                    children: [
                      Image.asset(
                        'assets/images/loginclaro.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ],
                  ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // HEADER
                Column(
                  children: [
                    Text(
                      "SELECCIONA TU MODO",
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dGoldMain, // Amarillo/Dorado consistente
                        letterSpacing: 1.5,
                        shadows: [
                          BoxShadow(
                            color: AppTheme.dGoldMain.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2
                          )
                        ]
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "¿Cómo deseas participar hoy?",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Colors.white70, // Siempre claro por el fondo oscuro/imagen
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const Spacer(flex: 3),
                
                // CARDS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // MODO PRESENCIAL
                      _buildModeCard(
                        title: "MODO PRESENCIAL",
                        description: "Vive la aventura en el mundo real. Requiere GPS y escanear códigos QR en ubicaciones físicas.",
                        icon: Icons.location_on_outlined,
                        color: AppTheme.dGoldMain, // Dorado
                        onTap: () {
                           // Navegar a escenarios (flujo normal)
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const ScenariosScreen()));
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // MODO ONLINE
                      _buildModeCard(
                        title: "MODO ONLINE",
                        description: "Participa desde cualquier lugar. Acceso mediante código PIN y multijuegos digitales.",
                        icon: Icons.wifi,
                        color: AppTheme.neonGreen, // Cyan/Verde Neón
                        onTap: () {
                           // Navegar a escenarios o input de PIN
                           // Por ahora dirigimos a ScenariosScreen que maneja ambos o filtrado
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const ScenariosScreen()));
                        }, 
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 4),
                
                // FOOTER - BOTÓN VOLVER
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: TextButton.icon(
                    onPressed: () async {
                      // Logout and go to Login
                      await context.read<PlayerProvider>().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                    label: const Text(
                      "Volver", 
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'Orbitron'
                      )
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: Colors.white.withOpacity(0.1))
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Efecto Blur (Glassmorphism)
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0F).withOpacity(0.6), // Fondo oscuro semi-transparente
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withOpacity(0.6), 
                width: 1.5
              ), 
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Alinear arriba si el texto es largo
              children: [
                // Icon Circle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                    border: Border.all(color: color.withOpacity(0.2), width: 1),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow (Centrada verticalmente)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20), // Ajuste visual
                    Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
