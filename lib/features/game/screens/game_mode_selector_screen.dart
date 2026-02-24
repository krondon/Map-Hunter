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
import '../../../core/providers/app_mode_provider.dart'; // IMPORT AGREGADO
import '../../game/providers/power_effect_provider.dart';

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
      final steps =
          MasterTutorialContent.getStepsForSection('MODE_SELECTOR', context);
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
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Precargar ambas imágenes de fondo para transiciones suaves
    precacheImage(const AssetImage('assets/images/hero.png'), context);
    precacheImage(const AssetImage('assets/images/loginclaro.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = true /* always dark UI */;
    final isNightImage = Provider.of<PlayerProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.dSurface0,
      body: Stack(
        children: [
          // BACKGROUND (Mismo que Login)

          // BACKGROUND (Mismo que Login)
          Positioned.fill(
            child: isNightImage
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
                          color:
                              AppTheme.dGoldMain, // Amarillo/Dorado consistente
                          letterSpacing: 1.5,
                          shadows: [
                            BoxShadow(
                                color: AppTheme.dGoldMain.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2)
                          ]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "¿Cómo deseas participar hoy?",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Colors
                            .white70, // Siempre claro por el fondo oscuro/imagen
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
                        description:
                            "Vive la aventura en el mundo real. Requiere GPS y escanear códigos QR en ubicaciones físicas.",
                        icon: Icons.location_on_outlined,
                        color: AppTheme.dGoldMain, // Dorado
                        onTap: () {
                          // ACTUALIZAR PROVIDER GLOBAL
                          context
                              .read<AppModeProvider>()
                              .setMode(GameMode.presencial);

                          // Navegar a escenarios (flujo normal)
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ScenariosScreen(isOnline: false)));
                        },
                      ),

                      const SizedBox(height: 24),

                      // MODO ONLINE
                      _buildModeCard(
                        title: "MODO ONLINE",
                        description:
                            "Participa desde cualquier lugar. Acceso mediante código PIN y multijuegos digitales.",
                        icon: Icons.wifi,
                        color: const Color(0xFF00F0FF), // Azul Cyber / Cyan
                        onTap: () {
                          // ACTUALIZAR PROVIDER GLOBAL
                          context
                              .read<AppModeProvider>()
                              .setMode(GameMode.online);

                          // Navegar a escenarios o input de PIN
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ScenariosScreen(isOnline: true)));
                        },
                      ),

                      const SizedBox(height: 24),

                      // MODO LOCAL
                      _buildModeCard(
                        title: "MODO LOCAL",
                        description:
                            "Juega en casa con amigos. Un modo diseñado para disfrutar sin desplazamientos.",
                        icon: Icons.home_outlined,
                        color: const Color(0xFF9D4EDD), // Morado Cyber
                        onTap: () {
                          _showComingSoonDialog("Modo Local");
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 4),

                // FOOTER - BOTÓN VOLVER
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(
                            4), // Espacio para el efecto de doble borde
                        decoration: BoxDecoration(
                            color: const Color(0xFF9D4EDD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(34),
                            border: Border.all(
                              color: const Color(0xFF9D4EDD).withOpacity(0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9D4EDD).withOpacity(0.1),
                                blurRadius: 15,
                                spreadRadius: 1,
                              )
                            ]),
                        child: TextButton.icon(
                          onPressed: _showLogoutDialog,
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                          label: const Text("Volver",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Orbitron',
                                letterSpacing: 1.0,
                              )),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0D0D0F)
                                .withOpacity(0.6), // Glassy background
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: const BorderSide(
                                    color: Color(0xFF9D4EDD), // Morado sólido
                                    width: 2.0)),
                            elevation: 0,
                          ),
                        ),
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

  void _showLogoutDialog() {
    const Color purpleAccent = Color(0xFF9D4EDD);
    const Color dangerRed = Color(0xFFFF4B4B);
    const Color cardBg = Color(0xFF0D0D0F);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: purpleAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: purpleAccent.withOpacity(0.4), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: purpleAccent.withOpacity(0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: purpleAccent.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: dangerRed.withOpacity(0.5), width: 1.5),
                    color: dangerRed.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      color: dangerRed, size: 30),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  '¿CERRAR SESIÓN?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle
                const Text(
                  '¿Estás seguro de que deseas salir? Tendrás que iniciar sesión de nuevo para jugar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                // Action Buttons
                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Confirm Logout
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await context.read<PlayerProvider>().logout();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login', (route) => false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'SALIR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(String featureName) {
    const Color purpleAccent = Color(0xFF9D4EDD);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: purpleAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: purpleAccent.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: purpleAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: purpleAccent.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: purpleAccent, width: 2),
                    color: purpleAccent.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.construction,
                      color: purpleAccent, size: 32),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Próximamente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'El "$featureName" estará listo muy pronto. ¡Estamos trabajando para brindarte la mejor experiencia!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ENTENDIDO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          filter: ImageFilter.blur(
              sigmaX: 10, sigmaY: 10), // Efecto Blur (Glassmorphism)
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(5), // Espacio para el borde interno
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0F)
                  .withOpacity(0.6), // Fondo oscuro semi-transparente
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.6), width: 1.5),

              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.2), // Trazado "tech" interno
                  width: 1.0,
                ),
                color: color.withOpacity(0.02), // Sutil tinte interno
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Alinear arriba si el texto es largo
                children: [
                  // Icon Circle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.1),
                        border:
                            Border.all(color: color.withOpacity(0.2), width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1)
                        ]),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),

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
                              shadows: [
                                Shadow(
                                    color: color.withOpacity(0.6),
                                    blurRadius: 8)
                              ]),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),


                  // Arrow
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Icon(Icons.arrow_forward_ios,
                        color: color.withOpacity(0.5), size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
