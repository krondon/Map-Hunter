import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui';
import '../models/scenario.dart';
import '../providers/event_provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../auth/providers/player_inventory_provider.dart'; // NEW
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/power_interfaces.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../providers/game_request_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'code_finder_screen.dart';
import 'game_request_screen.dart';
import '../../auth/screens/avatar_selection_screen.dart';
import 'event_waiting_screen.dart';
import '../models/event.dart'; // Import GameEvent model
import '../../auth/screens/login_screen.dart';
import '../../layouts/screens/home_screen.dart';
import '../widgets/scenario_countdown.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/services/video_preload_service.dart';
import 'winner_celebration_screen.dart';
import 'spectator_mode_screen.dart'; // ADDED
import '../services/game_access_service.dart'; // NEW
import 'game_mode_selector_screen.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../mappers/scenario_mapper.dart'; // NEW
import '../../../core/enums/user_role.dart';
import '../../social/screens/profile_screen.dart'; // For navigation
import '../../social/screens/wallet_screen.dart'; // For wallet navigation
import 'package:shared_preferences/shared_preferences.dart'; // For prize persistence
import '../../../shared/widgets/loading_indicator.dart';

class ScenariosScreen extends StatefulWidget {
  final bool isOnline;

  const ScenariosScreen({
    super.key,
    this.isOnline = false, // Default to false (Presential)
  });

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _hoverController;
  late Animation<Offset> _hoverAnimation;

  // New Controllers
  late AnimationController _shimmerController;
  late AnimationController _glitchController;

  int _currentPage = 0;
  bool _isLoading = true;
  bool _isProcessing = false; // Prevents double taps
  int _navIndex = 1; // Default to Escenarios (index 1)
  String _selectedFilter = 'active'; // Filter state: 'active' or 'pending'

  // Cache for participant status to show "Entering..." vs "Request Access"
  Map<String, bool> _participantStatusMap = {};

  // Cache for user role to determine button state (Player vs Spectator)
  Map<String, String> _eventRoleMap = {}; // NEW

  // Cache for ban status to show banned button
  Map<String, String?> _banStatusMap = {}; // NEW

  // The default user role for scenario selection
  UserRole get role => UserRole.player;
  bool get isDarkMode => true /* always dark UI */;

  void _showLogoutDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final isDarkMode = playerProvider.isDarkMode;

    _showPremiumExitDialog(
      title: '¿Qué deseas hacer?',
      subtitle: 'Puedes cambiar de modo de juego o cerrar tu sesión.',
      isDarkMode: isDarkMode,
      options: [
        _DialogOption(
          icon: Icons.swap_horiz_rounded,
          label: 'CAMBIAR MODO',
          gradientColors: isDarkMode
              ? [AppTheme.dGoldMain, const Color(0xFFE5A700)]
              : [AppTheme.lBrandMain, const Color(0xFF7B2CBF)],
          textColor: isDarkMode ? Colors.black : Colors.white,
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
              (route) => false,
            );
          },
        ),
        _DialogOption(
          icon: Icons.logout_rounded,
          label: 'CERRAR SESIÓN',
          gradientColors: [AppTheme.dangerRed, const Color(0xFFB71C1C)],
          textColor: Colors.white,
          onTap: () {
            Navigator.pop(context);
            playerProvider.logout();
            // AuthMonitor handles navigation to LoginScreen
          },
        ),
      ],
    );
  }

  /// Reusable premium dialog with glassmorphism and game-style buttons.
  void _showPremiumExitDialog({
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required List<_DialogOption> options,
  }) {
    final Color surfaceColor = isDarkMode
        ? Colors.black.withOpacity(0.75)
        : Colors.white.withOpacity(0.85);
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color textSecColor =
        isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
    final Color accentColor =
        isDarkMode ? AppTheme.dGoldMain : AppTheme.lBrandMain;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accentColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon with glow
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accentColor.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.games_rounded,
                              color: accentColor,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Accent line
                          Container(
                            width: 40,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withOpacity(0.3),
                                  accentColor,
                                  accentColor.withOpacity(0.3)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Subtitle
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: textSecColor,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Option buttons
                          ...options.map((opt) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: opt.gradientColors),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: opt.gradientColors.first
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      icon: Icon(opt.icon, size: 20),
                                      label: Text(opt.label,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              letterSpacing: 1)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: opt.textColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      onPressed: opt.onTap,
                                    ),
                                  ),
                                ),
                              )),
                          // Cancel
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: textSecColor.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    const Color currentOrange = Color(0xFFFF9800);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentOrange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Conócenos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'MapHunter es una experiencia de búsqueda del tesoro con realidad aumentada. ¡Explora, resuelve pistas y compite por premios increíbles!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO',
                      style: TextStyle(
                          color: currentOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    const Color currentOrange = Color(0xFFFF9800);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentOrange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined,
                    color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Términos y Condiciones',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const SingleChildScrollView(
                  child: Text(
                    'Al utilizar MapHunter, aceptas nuestros términos de servicio y política de privacidad. Para más información, visita nuestro sitio web.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO',
                      style: TextStyle(
                          color: currentOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportDialog() {
    const Color currentOrange = Color(0xFFFF9800);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentOrange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentOrange, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_outlined,
                    color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Soporte',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  '¿Necesitas ayuda? Contáctanos a través de nuestro correo de soporte: soporte@maphunter.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO',
                      style: TextStyle(
                          color: currentOrange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print("DEBUG: ScenariosScreen initState");

    _pageController = PageController(viewportFraction: 0.85);

    // 1. Levitation (Hover) Animation
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _hoverAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.05),
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOutSine,
    ));

    // 2. Shimmer Border Animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 3. Glitch Text Animation
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // Occurs every 4 seconds
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Tutorial check
      _checkFirstTime();

      // CLEANUP: Ensure we are disconnected from any previous game
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final powerProvider =
          Provider.of<PowerEffectManager>(context, listen: false);

      debugPrint("🧹 ScenariosScreen: Forcing Game State Cleanup...");
      _cleanupGameState();

      _loadEvents();
      // Empezar a precargar el video del primer avatar para que sea instantáneo
      VideoPreloadService()
          .preloadVideo('assets/escenarios.avatar/explorer_m_scene.mp4');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Precargar imágenes de fondo para transiciones suaves
    precacheImage(
        const AssetImage('assets/images/personajesgrupal.png'), context);
    precacheImage(
        const AssetImage('assets/images/fotogrupalnoche.png'), context);
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTutorial = prefs.getBool('seen_home_tutorial') ?? false;
    if (!hasSeenTutorial) {
      if (mounted) _showTutorial(context);
      await prefs.setBool('seen_home_tutorial', true);
    }
  }

  void _showTutorial(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => CyberTutorialOverlay(
          steps: [
            TutorialStep(
              title: "TABLERO DE MISIONES",
              description:
                  "Aquí verás los eventos y escenarios disponibles según el modo que elegiste. ¡Explóralos todos!",
              icon: Icons.map_outlined,
            ),
            TutorialStep(
              title: "MODOS DE JUEGO",
              description:
                  "En la pestaña 'Modos' podrás elegir entre jugar de forma presencial u online.",
              icon: Icons.sports_esports_outlined,
            ),
            TutorialStep(
              title: "TU CARTERA",
              description:
                  "Gestiona tus tréboles, recarga saldo y canjea tus premios acumulados en este juego.",
              icon: Icons.account_balance_wallet_outlined,
            ),
            TutorialStep(
              title: "TU PERFIL",
              description:
                  "Consulta tus estadísticas, nivel de jugador y personaliza tu avatar para que todos te reconozcan.",
              icon: Icons.person_outline,
            ),
          ],
          onFinish: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// Cleans up any active game session data to prevent ghost effects or state leaks.
  void _cleanupGameState() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final powerProvider =
        Provider.of<PowerEffectManager>(context, listen: false);

    debugPrint("🧹 ScenariosScreen: Forcing Game State Cleanup...");

    // Schedule to avoid frame collision during navigation pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider.resetState();
      playerProvider.clearGameContext();
      powerProvider.startListening(null, forceRestart: true);
    });
  }

  Future<void> _loadEvents() async {
    print("DEBUG: _loadEvents start");
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    await eventProvider.fetchEvents(
        type: widget.isOnline ? 'online' : 'on_site');

    // Load participation status and ban status for each event
    final userId = playerProvider.currentPlayer?.userId;
    if (userId != null) {
      final Map<String, bool> statusMap = {};
      final Map<String, String?> banMap = {}; // NEW
      final Map<String, String> roleMap = {}; // NEW - Role tracking

      for (final event in eventProvider.events) {
        try {
          final data =
              await requestProvider.isPlayerParticipant(userId, event.id);
          statusMap[event.id] = data['isParticipant'] as bool? ?? false;
          banMap[event.id] = data['status'] as String?; // NEW: Track ban status

          // Determine Role
          final status = data['status'] as String?;
          final isParticipant = data['isParticipant'] as bool? ?? false;

          if (status == 'spectator') {
            roleMap[event.id] = 'spectator';
          } else if (isParticipant) {
            roleMap[event.id] = 'player';
          } else {
            roleMap[event.id] = 'none';
          }
        } catch (e) {
          statusMap[event.id] = false;
          banMap[event.id] = null; // NEW
          roleMap[event.id] = 'none';
        }
      }
      if (mounted) {
        setState(() {
          _participantStatusMap = statusMap;
          _banStatusMap = banMap; // NEW
          _eventRoleMap = roleMap; // NEW
        });
      }
    }

    print("DEBUG: _loadEvents end. Mounted: $mounted");
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Show tutorial if first time viewing scenarios
      _showScenariosTutorial();
    }
  }

  void _showScenariosTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial_SCENARIOS') ?? false;
    if (hasSeen) return;

    final steps =
        MasterTutorialContent.getStepsForSection('SCENARIOS', context);
    if (steps.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CyberTutorialOverlay(
          steps: steps,
          onFinish: () {
            Navigator.pop(context);
            prefs.setBool('has_seen_tutorial_SCENARIOS', true);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hoverController.dispose();
    _shimmerController.dispose();
    _glitchController.dispose();
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // REMOVED: Conflicts with Logout transition
    super.dispose();
  }

  Future<void> _onScenarioSelected(Scenario scenario) async {
    final isDarkMode = true /* always dark UI */;
    if (_isProcessing) return;

    if (scenario.isCompleted) {
      // Get playerProvider BEFORE async gap
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // RETRIEVE PRIZE from SharedPreferences for completed events
      final prefs = await SharedPreferences.getInstance();
      final prizeWon = prefs.getInt('prize_won_${scenario.id}');
      debugPrint(
          "🏆 Retrieved prize for completed event ${scenario.id}: $prizeWon");

      // Refresh wallet balance to ensure it's current
      await playerProvider.reloadProfile();
      debugPrint(
          "💰 Wallet refreshed. Balance: ${playerProvider.currentPlayer?.clovers}");

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WinnerCelebrationScreen(
              eventId: scenario.id,
              playerPosition: 0, // Will be corrected by screen if participant
              totalCluesCompleted: 0,
              prizeWon: prizeWon ?? 0, // Pass 0 if null
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Mostrar diálogo de carga
      LoadingOverlay.show(context);

      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final requestProvider =
          Provider.of<GameRequestProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final inventoryProvider =
          Provider.of<PlayerInventoryProvider>(context, listen: false); // NEW

      // CRITICAL: Clear spectator mode flag before checking access as PLAYER
      // This ensures that users who previously viewed as spectators (including unbanned users)
      // can now enter as normal players
      playerProvider.setSpectatorRole(false);

      final accessService = GameAccessService();

      final result = await accessService.checkAccess(
        context: context,
        scenario: scenario,
        playerProvider: playerProvider,
        requestProvider: requestProvider,
        entryFee: (scenario.entryFee > 0) ? scenario.entryFee.toDouble() : null,
        role: role,
      );

      // Artificial delay for better UX (so loading doesn't flicker)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      LoadingOverlay.hide(context); // Close loading overlay

      // DEBUG: Log the access result type
      debugPrint('🔍 GameAccessService returned type: ${result.type}');
      debugPrint('   - Message: ${result.message}');
      debugPrint('   - Role: ${result.role}');
      debugPrint('   - IsReadOnly: ${result.isReadOnly}');
      debugPrint('   - Data: ${result.data}');

      switch (result.type) {
        case AccessResultType.allowed:
          final isParticipant = result.data?['isParticipant'] ?? false;
          final isApproved = result.data?['isApproved'] ?? false;

          if (isParticipant || isApproved) {
            // Check Avatar
            if (playerProvider.currentPlayer?.avatarId == null ||
                playerProvider.currentPlayer!.avatarId!.isEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AvatarSelectionScreen(eventId: scenario.id)));
            } else {
              // Initialize if needed
              bool success = true;
              if (!isParticipant && isApproved) {
                LoadingOverlay.show(context);
                success = await gameProvider.initializeGameForApprovedUser(
                    playerProvider.currentPlayer!.userId, scenario.id);
                if (mounted) LoadingOverlay.hide(context);
              }

              if (success) {
                // CLEANUP: Prevent Inventory Leak
                if (gameProvider.currentEventId != scenario.id) {
                  debugPrint(
                      '🚫 Event Switch: Cleaning up old state for ${scenario.id}...');
                  inventoryProvider
                      .resetEventState(); // Clean inventory lists (Provider)
                  playerProvider
                      .clearCurrentInventory(); // Clean active inventory (Player model)
                }

                await gameProvider.fetchClues(eventId: scenario.id);
                if (mounted) {
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => HomeScreen(eventId: scenario.id)))
                      .then((_) {
                    _cleanupGameState();
                  });
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Error al inicializar el juego.')));
              }
            }
          }
          break;

        case AccessResultType.deniedPermissions:
        case AccessResultType.deniedForever:
        case AccessResultType.fakeGps:
        case AccessResultType.sessionInvalid:
        case AccessResultType.suspended:
          if (result.message != null) {
            if (result.type == AccessResultType.fakeGps ||
                result.type == AccessResultType.suspended) {
              _showErrorDialog(result.message!,
                  title: result.type == AccessResultType.suspended
                      ? '⛔ Acceso Denegado'
                      : '⛔ Ubicación Falsa');
            } else {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(result.message!)));
            }
          }
          break;

        case AccessResultType.bannedSpectator:
          // CRITICAL: Clear game context to prevent power effects
          // This sets gamePlayerId = null, which triggers the hard gate in SabotageOverlay
          playerProvider.clearGameContext();

          // Navigate directly to spectator mode for banned users
          await gameProvider.fetchClues(eventId: scenario.id);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpectatorModeScreen(eventId: scenario.id),
              ),
            );
          }
          break;

        case AccessResultType.requestPendingOrRejected:
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => GameRequestScreen(
                      eventId: scenario.id,
                      eventTitle: scenario.name,
                    )),
          );
          break;

        case AccessResultType.needsCode:
          if (scenario.type == 'online') {
            // Online event: Skip CodeFinderScreen entirely
            if (scenario.entryFee > 0) {
              // Online PAID: Handle payment first
              final userClovers = playerProvider.currentPlayer?.clovers ?? 0;
              if (userClovers >= scenario.entryFee) {
                // Has enough -> Confirm payment
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('💰 Evento de Pago',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    content: Text(
                        'Este evento cuesta ${scenario.entryFee} 🍀.\n\nTu saldo: $userClovers 🍀',
                        style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar',
                              style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('PAGAR Y ENTRAR'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() => _isProcessing = true);
                  LoadingOverlay.show(context);

                  final result = await requestProvider.joinOnlinePaidEvent(
                      playerProvider.currentPlayer!.userId,
                      scenario.id,
                      scenario.entryFee);

                  // Artificial delay for specific online join action
                  await Future.delayed(const Duration(seconds: 2));

                  if (!mounted) return;
                  LoadingOverlay.hide(context);

                  final success = result['success'] == true;
                  if (success) {
                    final newBalance = (result['new_balance'] as num?)?.toInt();
                    if (newBalance != null) {
                      playerProvider.updateLocalClovers(newBalance);
                    } else {
                      playerProvider
                          .updateLocalClovers(userClovers - scenario.entryFee);
                    }
                    await playerProvider.refreshProfile();
                    setState(() {
                      _participantStatusMap[scenario.id] = true;
                    });

                    await gameProvider.fetchClues(eventId: scenario.id);
                    if (mounted) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  HomeScreen(eventId: scenario.id)));
                    }
                  } else {
                    final error = result['error'] ?? 'Error desconocido';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(error == 'PAYMENT_FAILED'
                            ? 'Saldo insuficiente al procesar el pago.'
                            : 'Error procesando el pago.')));
                  }
                  setState(() => _isProcessing = false);
                }
              } else {
                // Insufficient funds
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardBg,
                    title: const Text('Saldo Insuficiente',
                        style: TextStyle(
                            color: AppTheme.dangerRed,
                            fontWeight: FontWeight.bold)),
                    content: Text(
                        'Este evento cuesta ${scenario.entryFee} 🍀.\nSolo tienes $userClovers 🍀.',
                        style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar')),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple),
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('IR A BILLETERA'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WalletScreen()));
                        },
                      ),
                    ],
                  ),
                );
              }
            } else {
              // Online FREE: Join directly and enter game
              LoadingOverlay.show(context);

              try {
                // Create game_player record for free online event
                await requestProvider.joinFreeOnlineEvent(
                    playerProvider.currentPlayer!.userId, scenario.id);

                // Artificial delay for specific online join action
                await Future.delayed(const Duration(seconds: 2));

                setState(() {
                  _participantStatusMap[scenario.id] = true;
                });

                await gameProvider.fetchClues(eventId: scenario.id);
                if (mounted) {
                  LoadingOverlay.hide(context); // Close loading
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen(eventId: scenario.id)));
                }
              } catch (e) {
                if (mounted)
                  LoadingOverlay.hide(
                      context); // Close loading despite error so we can show snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al ingresar: $e')));
              }
            }
          } else {
            // Presencial event: Show CodeFinderScreen (thermometer + QR)
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => CodeFinderScreen(scenario: scenario)),
            );
          }
          break;

        case AccessResultType.needsAvatar:
          // Should be handled in allowed logic usually, but if separated:
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AvatarSelectionScreen(eventId: scenario.id)));
          break;

        case AccessResultType.approvedWait:
          break;

        case AccessResultType.needsPayment:
          final entryFee = (result.data?['entryFee'] as num?)?.toInt() ?? 0;
          final userClovers = playerProvider.currentPlayer?.clovers ?? 0;

          if (userClovers >= entryFee) {
            if (scenario.type == 'online') {
              // ── ONLINE PAID: Atomic payment + join via RPC ──
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardBg,
                  title: const Text('Confirmar Inscripción',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text(
                    'Este evento tiene un costo de $entryFee 🍀.\n\n'
                    'Tu saldo: $userClovers 🍀\n'
                    'Despues del pago: ${userClovers - entryFee} 🍀',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('PAGAR Y ENTRAR'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                setState(() => _isProcessing = true);
                LoadingOverlay.show(context);

                final joinResult = await requestProvider.joinOnlinePaidEvent(
                    playerProvider.currentPlayer!.userId,
                    scenario.id,
                    entryFee);

                if (!mounted) return;
                LoadingOverlay.hide(context);

                if (joinResult['success'] == true) {
                  final newBalance =
                      (joinResult['new_balance'] as num?)?.toInt();
                  if (newBalance != null) {
                    playerProvider.updateLocalClovers(newBalance);
                  } else {
                    playerProvider.updateLocalClovers(userClovers - entryFee);
                  }
                  await playerProvider.refreshProfile();

                  setState(() {
                    _participantStatusMap[scenario.id] = true;
                  });

                  if (mounted) {
                    final gameProvider =
                        Provider.of<GameProvider>(context, listen: false);
                    await gameProvider.fetchClues(eventId: scenario.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen(eventId: scenario.id)),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(joinResult['error'] == 'PAYMENT_FAILED'
                            ? 'Saldo insuficiente al procesar.'
                            : 'Error al inscribirse. Intenta de nuevo.')),
                  );
                }
                setState(() => _isProcessing = false);
              }
            } else {
              // ── ON-SITE PAID: Navigate directly to CodeFinder ──
              // Payment warning and request submission will happen AFTER scanning the QR code.
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CodeFinderScreen(scenario: scenario)),
              );
            }
          } else {
            // Caso 2: Saldo Insuficiente -> Redirigir Wallet
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.cardBg,
                title: const Text('Saldo Insuficiente',
                    style: TextStyle(
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold)),
                content: Text(
                  'Este evento cuesta $entryFee 🍀.\n'
                  'Solo tienes $userClovers 🍀 disponibles.',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('IR A BILLETERA'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                ],
              ),
            );
          }
          break;

        case AccessResultType.spectatorAllowed:
          // Si el usuario quería entrar como jugador (rol default) pero el servicio
          // devolvió espectador, significa que el evento está lleno (u otra razón).
          // Mostramos diálogo de confirmación.
          if (role == UserRole.player) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppTheme.secondaryPink.withOpacity(0.5),
                            width: 1),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF151517),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppTheme.secondaryPink, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryPink.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header area with a subtle glow (Restaurado)
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryPink
                                        .withOpacity(0.05),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(22)),
                                  ),
                                ),
                                Column(
                                  children: [
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.secondaryPink,
                                            AppTheme.secondaryPink
                                                .withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.secondaryPink
                                                .withOpacity(0.4),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.group_off_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            Text(
                              '¡EVENTO LLENO!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Content
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 30),
                              child: Column(
                                children: [
                                  Text(
                                    result.message ??
                                        'El cupo de jugadores activos (${scenario.maxPlayers}) ha sido alcanzado.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No te preocupes, aún puedes vivir la experiencia desde el modo espectador.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Main Button (Restaurado con degradado original)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppTheme.secondaryPink,
                                            Color(0xFFFF4081)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.secondaryPink
                                                .withOpacity(0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.visibility_rounded,
                                                color: Colors.white),
                                            SizedBox(width: 12),
                                            Text(
                                              'MODO ESPECTADOR',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Cancel Button (Restaurado)
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white38,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 24),
                                    ),
                                    child: const Text(
                                      'VOLVER AL INICIO',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );

            if (confirm != true) return;
          }

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SpectatorModeScreen(eventId: scenario.id),
            ),
          );
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('ScenariosScreen: CRITICAL ERROR: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _onSpectatorSelected(Scenario scenario) async {
    if (_isProcessing) return;

    if (scenario.isCompleted) {
      // Direct navigation to results screen for finished events
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WinnerCelebrationScreen(
              eventId: scenario.id,
              playerPosition: 0,
              totalCluesCompleted: 0,
              prizeWon: 0,
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // Diálogo de carga
      LoadingOverlay.show(context);

      // 1. Set role to spectator (local)
      playerProvider.setSpectatorRole(true);

      // 2. Join as ghost player
      await playerProvider.joinAsSpectator(scenario.id);

      if (!mounted) return;
      LoadingOverlay.hide(context); // Close loading overlay

      // 3. Navigate to Spectator Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpectatorModeScreen(eventId: scenario.id),
        ),
      );
    } catch (e) {
      debugPrint('Error joining spectator mode: $e');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted)
        setState(() {
          _isProcessing = false;
        });
    }
  }

  void _showErrorDialog(String msg, {String title = 'Atención'}) {
    // FORCED TO TRUE: Scenarios screen is always dark
    const isDarkMode = true;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentCard =
        isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: currentCard,
              title: Text(title,
                  style: const TextStyle(
                      color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
              content: Text(
                msg,
                style: TextStyle(color: currentText),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Entendido',
                        style: TextStyle(
                            color: isDarkMode
                                ? AppTheme.dGoldMain
                                : AppTheme.lBrandMain)))
              ],
            ));
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
                  child: const Icon(Icons.construction, color: purpleAccent, size: 32),
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
                  'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
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

  Widget _buildBottomNavBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withOpacity(0.4),
            border: const Border(
              top: BorderSide(
                color: AppTheme.dGoldMain,
                width: 1.0, // Moderately thicker as requested
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 4, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.sports_esports_outlined, 'Modos'),
                  _buildNavItem(1, Icons.explore_outlined, 'Escenarios'),
                  _buildNavItem(
                      2, Icons.account_balance_wallet_outlined, 'Wallet'),
                  _buildNavItem(3, Icons.person_outline, 'Perfil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _navIndex == index;
    final activeColor = AppTheme.dGoldMain;

    if (isSelected) {
      // SELECTED STATE - Restored Cyberpunk Style
      return GestureDetector(
        onTap: () {
          setState(() => _navIndex = index);
        },
        child: Container(
          width: 85,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: activeColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
            border: Border.all(
              color: activeColor,
              width: 1.0, // Matching line thickness
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: activeColor,
                size: 20,
                shadows: [
                  Shadow(color: activeColor.withOpacity(0.8), blurRadius: 8)
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    fontFamily: 'Avenir',
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(color: activeColor.withOpacity(0.5), blurRadius: 4)
                    ]),
              ),
            ],
          ),
        ),
      );
    } else {
      // UNSELECTED STATE
      return GestureDetector(
        onTap: () {
          setState(() => _navIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.transparent,
          child: Icon(
            icon,
            color: Colors.white70,
            size: 22,
          ),
        ),
      );
    }
  }

  /// Builds a custom button for banned users that navigates to spectator mode
  Widget _buildBannedButton(Scenario scenario) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withOpacity(0.9),
            Colors.orange.shade800.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.shade300.withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          // CRITICAL: Navigate directly without validation flow
          final playerProvider =
              Provider.of<PlayerProvider>(context, listen: false);
          final gameProvider =
              Provider.of<GameProvider>(context, listen: false);

          // Clear game context to prevent power effects
          playerProvider.clearGameContext();

          // Fetch clues for spectator view
          await gameProvider.fetchClues(eventId: scenario.id);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SpectatorModeScreen(eventId: scenario.id),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              "🚫 SUSPENDIDO - OBSERVAR",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: ScenariosScreen build. isLoading: $_isLoading");
    final eventProvider = Provider.of<EventProvider>(context);
    final appMode = Provider.of<AppModeProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    // FORCED TO TRUE: Always use dark mode colors in scenarios section (including dialogs)
    final isDarkMode = true; // Previously: playerProvider.isDarkMode;

    // Colores según el modo
    final Color currentBg =
        isDarkMode ? AppTheme.dSurface0 : AppTheme.lSurface0;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);

    // Filtrar eventos según el modo seleccionado
    List<GameEvent> visibleEvents = eventProvider.events;
    if (appMode.isOnlineMode) {
      visibleEvents = visibleEvents.where((e) => e.type == 'online').toList();
    } else if (appMode.isPresencialMode) {
      // Presencial: Todo lo que NO sea online (o explícitamente presencial si hubiera ese tipo)
      visibleEvents = visibleEvents.where((e) => e.type != 'online').toList();
    }

    // APLICAR FILTRO DE ESTADO (Active vs Pending vs Completed)
    visibleEvents = visibleEvents.where((e) {
    if (_selectedFilter == 'completed') return e.status == 'completed';
    if (e.status == 'completed') return false;
    if (_selectedFilter == 'active') return e.status == 'active';
    if (_selectedFilter == 'pending') return e.status == 'pending';
    return false;
  }).toList();

  if (_selectedFilter == 'completed') {
    visibleEvents = visibleEvents.skip(visibleEvents.length > 5 ? visibleEvents.length - 5 : 0).toList();
  }

    // Convertir Eventos a Escenarios usando Mapper
    final List<Scenario> scenarios = ScenarioMapper.fromEvents(visibleEvents);

    final Color currentBrandDeep =
        isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        _showPremiumExitDialog(
          title: '¿Qué deseas hacer?',
          subtitle: 'Puedes cambiar de modo de juego o salir de la aplicación.',
          isDarkMode: isDarkMode,
          options: [
            _DialogOption(
              icon: Icons.swap_horiz_rounded,
              label: 'CAMBIAR MODO',
              gradientColors: isDarkMode
                  ? [AppTheme.dGoldMain, const Color(0xFFE5A700)]
                  : [AppTheme.lBrandMain, const Color(0xFF7B2CBF)],
              textColor: isDarkMode ? Colors.black : Colors.white,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const GameModeSelectorScreen()),
                  (route) => false,
                );
              },
            ),
            _DialogOption(
              icon: Icons.exit_to_app_rounded,
              label: 'SALIR DE LA APP',
              gradientColors: [AppTheme.dangerRed, const Color(0xFFB71C1C)],
              textColor: Colors.white,
              onTap: () {
                Navigator.pop(context);
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
      child: AnimatedCyberBackground(
        child: Stack(
          children: [
            // Fondo con imagen dinámica (Diferente para Día y Noche)
            Positioned.fill(
              child: Image.asset(
                playerProvider.isDarkMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // Overlay oscuro para mejorar legibilidad sobre la imagen
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
            Scaffold(
              backgroundColor:
                  Colors.transparent, // Transparente para ver el fondo animado
              extendBody: true,
              bottomNavigationBar: SafeArea(
                bottom: true,
                child: _buildBottomNavBar(),
              ),
              body: IndexedStack(
                index: _navIndex,
                children: [
                   _buildLocalSection(),
                  _buildScenariosContent(scenarios),
                  const WalletScreen(hideScaffold: true),
                  const ProfileScreen(hideScaffold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const Text(
            "MODOS",
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.dGoldMain,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "¿Cómo deseas jugar hoy?",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 40),
          _buildModeCard(
            title: "MODO PRESENCIAL",
            description: "Aventura real con GPS y códigos QR.",
            icon: Icons.location_on_outlined,
            color: AppTheme.dGoldMain,
            onTap: () {
              context.read<AppModeProvider>().setMode(GameMode.presencial);
              setState(() => _navIndex = 1);
              _loadEvents();
            },
          ),
          const SizedBox(height: 16),
          _buildModeCard(
            title: "MODO ONLINE",
            description: "Juega desde cualquier lugar con PIN.",
            icon: Icons.wifi,
            color: const Color(0xFF00F0FF),
            onTap: () {
              context.read<AppModeProvider>().setMode(GameMode.online);
              setState(() => _navIndex = 1);
              _loadEvents();
            },
          ),
          const SizedBox(height: 16),
          _buildModeCard(
            title: "MODO LOCAL",
            description: "Juega en casa con amigos. Próximamente.",
            icon: Icons.home_outlined,
            color: const Color(0xFF9D4EDD),
            onTap: () => _showComingSoonDialog("Modo Local"),
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
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(4), // Space for double border effect
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF150826).withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: color.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.1),
                      border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6), size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonContent(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, color: AppTheme.accentGold, size: 80),
          const SizedBox(height: 24),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.accentGold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
              "PRÓXIMAMENTE",
              style: TextStyle(
                color: Colors.white70,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => setState(() => _navIndex = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
            ),
            child: const Text('VOLVER A ESCENARIOS'),
          ),
        ],
      ),
    );
  }

  Widget _buildScenariosContent(List<Scenario> scenarios) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    // FORCED TO TRUE: Always use dark mode colors in scenarios/simulator section
    final isDarkMode = true; // Previously: playerProvider.isDarkMode;

    // Colores dinámicos (ahora siempre serán los del modo oscuro)
    final Color currentSurface =
        isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec =
        isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
    final Color currentBrand =
        isDarkMode ? AppTheme.dBrandMain : AppTheme.lBrandMain;
    final Color currentBrandDeep =
        isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;
    final Color currentAction =
        isDarkMode ? AppTheme.dGoldMain : AppTheme.lBrandMain;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          return RefreshIndicator(
            onRefresh: _loadEvents,
            color: currentAction,
            backgroundColor: currentSurface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: viewportConstraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Custom AppBar
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, MediaQuery.of(context).padding.top + 20, 20, 0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(height: 50), // Reduced header space
                          // Removed "Búsqueda del tesoro" from here to move it lower
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerTheme: DividerThemeData(
                                  color: currentText.withOpacity(0.1),
                                  thickness: 1,
                                ),
                              ),
                              child: PopupMenuButton<String>(
                                icon: Icon(Icons.menu,
                                    color: currentText, size: 28),
                                color: currentSurface.withOpacity(0.95),
                                elevation: 15,
                                offset: const Offset(0, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: currentAction, width: 1.5),
                                ),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'profile':
                                      setState(() {
                                        _navIndex = 3;
                                      });
                                      break;
                                    case 'about':
                                      _showAboutDialog();
                                      break;
                                    case 'terms':
                                      _showTermsDialog();
                                      break;
                                    case 'support':
                                      _showSupportDialog();
                                      break;
                                    case 'logout':
                                      _showLogoutDialog();
                                      break;
                                    case 'tutorial':
                                      _showTutorial(context);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                      value: 'profile',
                                      child: Row(children: [
                                        Icon(Icons.person, color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Perfil',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'about',
                                      child: Row(children: [
                                        Icon(Icons.info_outline,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Conócenos',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'terms',
                                      child: Row(children: [
                                        Icon(Icons.description_outlined,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Términos',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'support',
                                      child: Row(children: [
                                        Icon(Icons.support_agent_outlined,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Soporte',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                  PopupMenuItem(
                                      value: 'tutorial',
                                      child: Row(children: [
                                        Icon(Icons.help_outline,
                                            color: currentBrand),
                                        const SizedBox(width: 12),
                                        Text('Guía de Juego',
                                            style:
                                                TextStyle(color: currentText))
                                      ])),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 10,
                            child: GestureDetector(
                              onTap: _showLogoutDialog,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.dangerRed.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.dangerRed,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppTheme.dangerRed.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: AppTheme.dangerRed,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Center(
                      child: Image.asset(
                        'assets/images/logo4.1.png',
                        height: 140, // Reduced size
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced spacer

                    Center(
                      child: Text(
                        "Búsqueda del tesoro ☘️",
                        style: TextStyle(
                          fontSize: 14,
                          color: currentTextSec,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        '¡Embárcate en una emocionante búsqueda del tesoro resolviendo pistas intrigantes para descubrir el gran premio oculto!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: currentText,
                            fontSize: 15,
                            height: 1.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ),

                    const SizedBox(height: 8), // Gap between both texts

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Center(
                        child: Text(
                          "ELIGE TU AVENTURA",
                          style: TextStyle(
                              color: currentAction,
                              fontSize: 18, // Reduced size
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),

                    const SizedBox(
                        height: 5), // Small gap between text and filters

                    // CONTROLES DE FILTRO
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterChip(
                            label: 'En Curso',
                            isActive: _selectedFilter == 'active',
                            onTap: () =>
                                setState(() => _selectedFilter = 'active'),
                            activeColor:
                                AppTheme.dGoldMain, // Forzado a dorado oscuro
                            textColor: Colors.black, // Negro sobre dorado
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip(
                            label: 'Próximos',
                            isActive: _selectedFilter == 'pending',
                            onTap: () =>
                                setState(() => _selectedFilter = 'pending'),
                            activeColor: Colors.blueAccent,
                            textColor: Colors.white, // Blanco sobre azul
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip(
                            label: 'Finalizados',
                            isActive: _selectedFilter == 'completed',
                            onTap: () =>
                                setState(() => _selectedFilter = 'completed'),
                            activeColor:
                                Colors.grey.shade700, // Forzado a gris oscuro
                            textColor: Colors.white, // Blanco sobre gris
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _isLoading
                              ? const Center(child: LoadingIndicator())
                              : scenarios.isEmpty
                                  ? Center(
                                      child: Text(
                                          "No hay competencias disponibles",
                                          style:
                                              TextStyle(color: currentTextSec)))
                                  : ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(dragDevices: {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.mouse
                                      }),
                                      child: PageView.builder(
                                        controller: _pageController,
                                        onPageChanged: (index) => setState(
                                            () => _currentPage = index),
                                        itemCount: scenarios.length,
                                        itemBuilder: (context, index) {
                                          final scenario = scenarios[index];
                                          return AnimatedBuilder(
                                            animation: _pageController,
                                            builder: (context, child) {
                                              double value = 1.0;
                                              if (_pageController
                                                  .position.haveDimensions) {
                                                value = (_pageController.page! -
                                                        index)
                                                    .abs();
                                                value = (1 - (value * 0.3))
                                                    .clamp(0.0, 1.0);
                                              } else {
                                                value = index == _currentPage
                                                    ? 1.0
                                                    : 0.7;
                                              }
                                              return Align(
                                                alignment: Alignment
                                                    .bottomCenter, // Pushes the card towards the dots
                                                child: Container(
                                                  margin: EdgeInsets
                                                      .zero, // Removed margin to lower it more
                                                  child: SizedBox(
                                                    height: Curves.easeOut
                                                            .transform(value) *
                                                        constraints.maxHeight *
                                                        1.0, // Occupy 100% of available height
                                                    width: Curves.easeOut
                                                            .transform(value) *
                                                        360, // Slightly wider to match new height
                                                    child: child,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: GestureDetector(
                                              onTap: () {
                                                // Don't intercept tap if user is banned - let the banned button handle it
                                                if (_banStatusMap[
                                                            scenario.id] !=
                                                        'banned' &&
                                                    _banStatusMap[
                                                            scenario.id] !=
                                                        'suspended') {
                                                  _onScenarioSelected(scenario);
                                                }
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10),
                                                decoration: BoxDecoration(
                                                    color: currentSurface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                    boxShadow: [
                                                      BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(
                                                                  isDarkMode
                                                                      ? 0.5
                                                                      : 0.2),
                                                          blurRadius: 20,
                                                          offset: const Offset(
                                                              0, 10))
                                                    ]),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      scenario.imageUrl.isNotEmpty &&
                                                              scenario.imageUrl
                                                                  .startsWith(
                                                                      'http')
                                                          ? Image.network(
                                                              scenario.imageUrl,
                                                              fit: (scenario.type == 'online')
                                                                  ? BoxFit
                                                                      .contain
                                                                  : BoxFit
                                                                      .cover,
                                                              errorBuilder: (c, e, s) => Image.asset(
                                                                  'assets/images/logo4.1.png',
                                                                  fit: BoxFit
                                                                      .contain))
                                                          : Image.asset(
                                                              'assets/images/logo4.1.png',
                                                              fit: BoxFit.contain),
                                                      Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                            begin: Alignment
                                                                .topCenter,
                                                            end: Alignment
                                                                .bottomCenter,
                                                            colors: [
                                                              Colors
                                                                  .transparent,
                                                              Colors.black
                                                                  .withOpacity(
                                                                      isDarkMode
                                                                          ? 0.6
                                                                          : 0.4),
                                                              Colors.black
                                                                  .withOpacity(
                                                                      isDarkMode
                                                                          ? 0.9
                                                                          : 0.7)
                                                            ],
                                                            stops: const [
                                                              0.3,
                                                              0.7,
                                                              1.0
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Align(
                                                        alignment: Alignment
                                                            .bottomCenter,
                                                        child:
                                                            SingleChildScrollView(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(24.0),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                  scenario.name,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          18.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold)),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                  scenario
                                                                      .description,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white70,
                                                                      fontSize:
                                                                          12),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis),
                                                              const SizedBox(
                                                                  height: 12),
                                                              Center(
                                                                child:
                                                                    SingleChildScrollView(
                                                                  scrollDirection:
                                                                      Axis.horizontal,
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8),
                                                                  clipBehavior:
                                                                      Clip.none,
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      // MODIFIED: Prioritize Status 'active'
                                                                      if (scenario
                                                                              .status ==
                                                                          'active')
                                                                        Container(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal: 8,
                                                                              vertical: 4),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                AppTheme.successGreen.withOpacity(0.8),
                                                                            borderRadius:
                                                                                BorderRadius.circular(20),
                                                                            border:
                                                                                Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                                                          ),
                                                                          child:
                                                                              const Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              Icon(Icons.play_circle_fill, color: Colors.white, size: 14),
                                                                              SizedBox(width: 4),
                                                                              Text(
                                                                                'EN CURSO',
                                                                                style: TextStyle(
                                                                                  color: Colors.white,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: 10,
                                                                                  letterSpacing: 0.5,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        )
                                                                      else if (scenario.date !=
                                                                              null &&
                                                                          !scenario
                                                                              .isCompleted)
                                                                        ScenarioCountdown(
                                                                            targetDate:
                                                                                scenario.date!),

                                                                      if (scenario.date !=
                                                                              null &&
                                                                          !scenario
                                                                              .isCompleted)
                                                                        const SizedBox(
                                                                            width:
                                                                                8),

                                                                      // BADGE: MAX PLAYERS
                                                                      Container(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                8,
                                                                            vertical:
                                                                                4),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: scenario.isCompleted
                                                                              ? AppTheme.dangerRed.withOpacity(0.8)
                                                                              : Colors.black.withOpacity(0.6),
                                                                          borderRadius:
                                                                              BorderRadius.circular(20),
                                                                          border: Border.all(
                                                                              color: Colors.white.withOpacity(0.2),
                                                                              width: 1),
                                                                        ),
                                                                        child:
                                                                            Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.min,
                                                                          children: [
                                                                            const Icon(Icons.people_outline,
                                                                                color: Colors.white,
                                                                                size: 14),
                                                                            const SizedBox(width: 4),
                                                                            Text(
                                                                              scenario.isCompleted ? 'FINALIZADA' : 'MÁX: ${scenario.maxPlayers}',
                                                                              style: const TextStyle(
                                                                                color: Colors.white,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 10,
                                                                                letterSpacing: 0.5,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),

                                                                      // BADGE: POT / PRIZE (BOTÍN)
                                                                      if (!scenario
                                                                              .isCompleted &&
                                                                          scenario.entryFee >
                                                                              0)
                                                                        const SizedBox(
                                                                            width:
                                                                                8),

                                                                      if (!scenario
                                                                              .isCompleted &&
                                                                          scenario.entryFee >
                                                                              0)
                                                                        Container(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal: 8,
                                                                              vertical: 4),
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            gradient:
                                                                                LinearGradient(
                                                                              colors: [
                                                                                AppTheme.accentGold.withOpacity(0.4),
                                                                                AppTheme.accentGold.withOpacity(0.1),
                                                                              ],
                                                                            ),
                                                                            borderRadius:
                                                                                BorderRadius.circular(20),
                                                                            border:
                                                                                Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 1),
                                                                            boxShadow: [
                                                                              BoxShadow(
                                                                                color: AppTheme.accentGold.withOpacity(0.2),
                                                                                blurRadius: 8,
                                                                                spreadRadius: -2,
                                                                              )
                                                                            ],
                                                                          ),
                                                                          child:
                                                                              Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              const Icon(Icons.workspace_premium, color: AppTheme.accentGold, size: 14),
                                                                              const SizedBox(width: 4),
                                                                              Text(
                                                                                "BOTÍN: ${(scenario.currentParticipants * scenario.entryFee * 0.70).toStringAsFixed(0)} 🍀",
                                                                                style: const TextStyle(
                                                                                  color: AppTheme.accentGold,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: 10,
                                                                                  letterSpacing: 0.5,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      const SizedBox(
                                                                          width:
                                                                              8), // Extra space at the end to prevent clipping
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 10),
                                                              // CONDITIONAL BUTTON RENDERING based on event status and user role
                                                              if (scenario.isCompleted)
                                                                // 0. COMPLETED -> ALL users see "VER PODIO" (no matter their role)
                                                                Center(
                                                                  child: SizedBox(
                                                                    width: 250,
                                                                    child: ElevatedButton(
                                                                      onPressed: () =>
                                                                          _onScenarioSelected(scenario),
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: AppTheme.accentGold,
                                                                        foregroundColor: Colors.black,
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(20))),
                                                                      child: const Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          Icon(Icons.emoji_events, size: 18),
                                                                          SizedBox(width: 8),
                                                                          Text('VER PODIO',
                                                                              style: TextStyle(
                                                                                  fontWeight: FontWeight.bold)),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                              else if (_banStatusMap[
                                                                          scenario
                                                                              .id] ==
                                                                      'banned' ||
                                                                  _banStatusMap[
                                                                          scenario
                                                                              .id] ==
                                                                      'suspended')
                                                                // 1. BANNED/SUSPENDED -> Show Red Button
                                                                Center(
                                                                  child:
                                                                      SizedBox(
                                                                    width: 250,
                                                                    child: _buildBannedButton(
                                                                        scenario),
                                                                  ),
                                                                )
                                                              else if (_eventRoleMap[
                                                                      scenario
                                                                          .id] ==
                                                                  'spectator')
                                                                // 2. SPECTATOR -> Show "MODO ESPECTADOR" Main Button
                                                                Center(
                                                                  child:
                                                                      SizedBox(
                                                                    width: 250,
                                                                    child:
                                                                        ElevatedButton(
                                                                      onPressed:
                                                                          () =>
                                                                              _onSpectatorSelected(scenario),
                                                                      style: ElevatedButton
                                                                          .styleFrom(
                                                                        backgroundColor:
                                                                            Colors.transparent, // Glass style
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                        side: const BorderSide(
                                                                            color:
                                                                                Colors.white60,
                                                                            width: 1.5),
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(20)),
                                                                        elevation:
                                                                            0,
                                                                      ),
                                                                      child:
                                                                          const Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          Icon(Icons
                                                                              .visibility),
                                                                          SizedBox(
                                                                              width: 8),
                                                                          Text(
                                                                              "MODO ESPECTADOR",
                                                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                              else
                                                                // 3. PLAYER OR NONE -> Show Standard Logic
                                                                Column(
                                                                  children: [
                                                                    // Main Action Button (Enter/Register)
                                                                    Center(
                                                                      child:
                                                                          SizedBox(
                                                                        width:
                                                                            250,
                                                                        child:
                                                                            ElevatedButton(
                                                                          onPressed: () =>
                                                                              _onScenarioSelected(scenario),
                                                                          style: ElevatedButton.styleFrom(
                                                                              backgroundColor: currentAction,
                                                                              foregroundColor: (isDarkMode && currentAction == AppTheme.dGoldMain) ? Colors.black : Colors.white,
                                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                                                                          child: scenario.isCompleted
                                                                              ? const Text("VER PODIO", style: TextStyle(fontWeight: FontWeight.bold))
                                                                              : _participantStatusMap[scenario.id] == true
                                                                                  ? const Text("ENTRAR", style: TextStyle(fontWeight: FontWeight.bold)) // Already Player
                                                                                  : Text(scenario.entryFee == 0 ? "INSCRIBETE (GRATIS)" : "INSCRIBETE (${scenario.entryFee} 🍀)", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                        ),
                                                                      ),
                                                                    ),

                                                                    // Spectator Link (Only if NOT a participant yet)
                                                                    if (!scenario
                                                                            .isCompleted &&
                                                                        _participantStatusMap[scenario.id] !=
                                                                            true) ...[
                                                                      const SizedBox(
                                                                          height:
                                                                              8),
                                                                      Center(
                                                                        child:
                                                                            SizedBox(
                                                                          width:
                                                                              250,
                                                                          child:
                                                                              TextButton(
                                                                            onPressed: () =>
                                                                                _onSpectatorSelected(scenario),
                                                                            style:
                                                                                TextButton.styleFrom(
                                                                              foregroundColor: Colors.white,
                                                                              side: const BorderSide(color: Colors.white30),
                                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                                              backgroundColor: Colors.black26,
                                                                            ),
                                                                            child:
                                                                                const Row(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                Icon(Icons.visibility, size: 16),
                                                                                SizedBox(width: 8),
                                                                                Text("MODO ESPECTADOR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                        },
                      ),
                    ),
                    // PAGE INDICATOR (DOTS)
                    if (scenarios.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 5, top: 10), // Lowered dots
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(scenarios.length, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: _currentPage == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? currentAction
                                    : currentAction.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
    required Color textColor,
  }) {
    // Determine colors based on state
    final backgroundColor = isActive ? activeColor : Colors.transparent;
    final borderColor = isActive
        ? activeColor
        : Colors
            .white24; // Siempre usar color claro para el borde ya que el fondo es oscuro
    final labelColor = isActive
        ? textColor
        : Colors
            .white60; // Siempre usar color claro para el texto ya que el fondo es oscuro
    final fontWeight = isActive ? FontWeight.bold : FontWeight.normal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontWeight: fontWeight,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Simple data class for premium dialog options.
class _DialogOption {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color textColor;
  final VoidCallback onTap;

  const _DialogOption({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.textColor,
    required this.onTap,
  });
}
