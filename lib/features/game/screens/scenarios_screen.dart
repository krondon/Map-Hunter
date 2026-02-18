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
  const ScenariosScreen({super.key});

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

  // Cache for ban status to show banned button
  Map<String, String?> _banStatusMap = {}; // NEW

  // The default user role for scenario selection
  UserRole get role => UserRole.player;
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  void _showLogoutDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentRed.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentRed.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentRed, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentRed.withOpacity(0.1),
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
                    border: Border.all(color: currentRed, width: 2),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: currentRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¿Estás seguro que deseas cerrar sesión?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await playerProvider.logout();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SALIR', style: TextStyle(fontWeight: FontWeight.bold)),
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
                const Text('Conócenos', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'MapHunter es una experiencia de búsqueda del tesoro con realidad aumentada. ¡Explora, resuelve pistas y compite por premios increíbles!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO', style: TextStyle(color: currentOrange, fontWeight: FontWeight.bold)),
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
                const Icon(Icons.description_outlined, color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Términos y Condiciones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                  child: const Text('ENTENDIDO', style: TextStyle(color: currentOrange, fontWeight: FontWeight.bold)),
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
                const Icon(Icons.support_agent_outlined, color: currentOrange, size: 40),
                const SizedBox(height: 16),
                const Text('Soporte', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  '¿Necesitas ayuda? Contáctanos a través de nuestro correo de soporte: soporte@maphunter.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ENTENDIDO', style: TextStyle(color: currentOrange, fontWeight: FontWeight.bold)),
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
    precacheImage(const AssetImage('assets/images/personajesgrupal.png'), context);
    precacheImage(const AssetImage('assets/images/fotogrupalnoche.png'), context);
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
              title: "TABERNA Y LOCALES",
              description:
                  "En la pestaña 'Local' podrás ver comercios aliados, ofertas exclusivas y puntos de interés cercanos.",
              icon: Icons.storefront_outlined,
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

    await eventProvider.fetchEvents();

    // Load participation status and ban status for each event
    final userId = playerProvider.currentPlayer?.userId;
    if (userId != null) {
      final Map<String, bool> statusMap = {};
      final Map<String, String?> banMap = {}; // NEW
      for (final event in eventProvider.events) {
        try {
          final data =
              await requestProvider.isPlayerParticipant(userId, event.id);
          statusMap[event.id] = data['isParticipant'] as bool? ?? false;
          banMap[event.id] = data['status'] as String?; // NEW: Track ban status
        } catch (e) {
          statusMap[event.id] = false;
          banMap[event.id] = null; // NEW
        }
      }
      if (mounted) {
        setState(() {
          _participantStatusMap = statusMap;
          _banStatusMap = banMap; // NEW
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

    final steps = MasterTutorialContent.getStepsForSection('SCENARIOS', context);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
              playerPosition: 0,
              totalCluesCompleted: 0,
              prizeWon: prizeWon, // PASS RETRIEVED PRIZE
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
                      playerProvider.updateLocalClovers(userClovers - scenario.entryFee);
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
                  final newBalance = (joinResult['new_balance'] as num?)?.toInt();
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
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.5), width: 1),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF151517),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.secondaryPink, width: 2),
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
                                    color: AppTheme.secondaryPink.withOpacity(0.05),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                                            AppTheme.secondaryPink.withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.secondaryPink.withOpacity(0.4),
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
                              padding: const EdgeInsets.symmetric(horizontal: 30),
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
                                            color: AppTheme.secondaryPink.withOpacity(0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.visibility_rounded, color: Colors.white),
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
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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

    setState(() {
      _isProcessing = true;
    });

    try {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // Diálogo de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.construction, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text(
              'Próximamente',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
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
            color: const Color(0xFF000000).withOpacity(0.3), // More transparent
            border: const Border(
              top: BorderSide(
                color: AppTheme.dGoldMain, 
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.storefront_outlined, 'Local'),
                  _buildNavItem(1, Icons.explore_outlined, 'Escenarios'),
                  _buildNavItem(2, Icons.account_balance_wallet_outlined, 'Wallet'),
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
      // SELECTED STATE - Glowing "Tab" Shape
      return GestureDetector(
        onTap: () {
          setState(() => _navIndex = index);
        },
        child: Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: activeColor.withOpacity(0.1), // Sutil fondo dorado
            // Forma de "pestaña" o "tab" con esquinas superiores muy redondeadas
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
            border: Border.all(
              color: activeColor, 
              width: 1.5, // Borde principal brillante
            ),
            boxShadow: [
              // Glow amarillo fuerte exterior
              BoxShadow(
                color: activeColor.withOpacity(0.6), 
                blurRadius: 15,
                spreadRadius: 2,
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
                size: 24,
                shadows: [
                  Shadow(
                    color: activeColor.withOpacity(0.8),
                    blurRadius: 8
                  )
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label, 
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  fontFamily: 'Avenir', 
                  letterSpacing: 0.5,
                  shadows: [
                     Shadow(
                      color: activeColor.withOpacity(0.5),
                      blurRadius: 4
                    )
                  ]
                ),
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
          padding: const EdgeInsets.all(12),
          color: Colors.transparent, // Hitbox
          child: Icon(
            icon,
            color: Colors.white, // Blanco puro para alto contraste como en la foto
            size: 26,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 4
              )
            ],
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
      if (e.status == 'completed') return false; // Hide completed in other tabs
      if (_selectedFilter == 'active') return e.status == 'active';
      if (_selectedFilter == 'pending') return e.status == 'pending';
      return false;
    }).toList();

    // Convertir Eventos a Escenarios usando Mapper
    final List<Scenario> scenarios = ScenarioMapper.fromEvents(visibleEvents);

    final Color currentBrandDeep =
        isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDarkMode ? AppTheme.dSurface1 : Colors.white,
            title: Text('¿Salir de MapHunter?',
                style: TextStyle(color: currentText)),
            content: Text(
              '¿Estás seguro que deseas salir de la aplicación?',
              style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('SALIR'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
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
                  _buildComingSoonContent('Local'),
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
          Text(
              title == 'Local'
                  ? "UN MODO DE JUEGO PARA JUGAR EN CASA"
                  : "PRÓXIMAMENTE",
              style: const TextStyle(
                color: Colors.white70, // Always use dark mode color
                letterSpacing: 2, // Simplified: was conditional
                fontWeight: FontWeight.bold,
                fontSize: 14, // Simplified: was conditional
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
                          Padding(
                            padding: const EdgeInsets.only(top: 30.0),
                            child: Center(
                              child: Image.asset(
                                isDarkMode
                                    ? 'assets/images/maphunter_titulo.png'
                                    : 'assets/images/logocopia2.png',
                                height: 65,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -20,
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
                          Positioned(
                            left: 0,
                            top: -24,
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
                            top: -24,
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
                                        color: AppTheme.dangerRed.withOpacity(0.3),
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

                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
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

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Center(
                        child: Text(
                          "ELIGE TU AVENTURA",
                          style: TextStyle(
                              color: currentAction,
                              fontSize: 22,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

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
                            activeColor: AppTheme.dGoldMain, // Forzado a dorado oscuro
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
                            activeColor: Colors.grey.shade700, // Forzado a gris oscuro
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
                                                return Center(
                                                  child: SizedBox(
                                                    height: Curves.easeOut
                                                            .transform(value) *
                                                        constraints.maxHeight * 0.88, // Increased height factor
                                                    width: Curves.easeOut
                                                            .transform(value) *
                                                        340,
                                                    child: child,
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
                                                        scenario.imageUrl.isNotEmpty && scenario.imageUrl.startsWith('http')
                                                            ? Image.network(
                                                                scenario.imageUrl,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (c, e, s) => Container(
                                                                    color: isDarkMode
                                                                        ? Colors.grey[
                                                                            800]
                                                                        : Colors.grey[
                                                                            200],
                                                                    child: Icon(Icons.broken_image,
                                                                        color:
                                                                            currentTextSec)))
                                                            : Container(
                                                                color: isDarkMode
                                                                    ? Colors
                                                                        .grey[900]
                                                                    : Colors.grey[100],
                                                                child: Icon(Icons.image_not_supported, color: currentTextSec.withOpacity(0.5))),
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
                                                          alignment: Alignment.bottomCenter,
                                                          child: SingleChildScrollView(
                                                            padding: const EdgeInsets.all(24.0),
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                    scenario.name,
                                                                    style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 22,
                                                                        fontWeight: FontWeight.bold)),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                    scenario.description,
                                                                    style: const TextStyle(
                                                                        color: Colors.white70,
                                                                        fontSize: 12),
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis),
                                                                const SizedBox(height: 12),
                                                                Center(
                                                                  child: SingleChildScrollView(
                                                                    scrollDirection: Axis.horizontal,
                                                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                                                    clipBehavior: Clip.none,
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        if (scenario.date != null && !scenario.isCompleted)
                                                                          ScenarioCountdown(targetDate: scenario.date!),
                                                                        
                                                                        if (scenario.date != null && !scenario.isCompleted)
                                                                          const SizedBox(width: 8),
                                                                        
                                                                        // BADGE: MAX PLAYERS
                                                                        Container(
                                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                          decoration: BoxDecoration(
                                                                            color: scenario.isCompleted ? AppTheme.dangerRed.withOpacity(0.8) : Colors.black.withOpacity(0.6),
                                                                            borderRadius: BorderRadius.circular(20),
                                                                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                                                                          ),
                                                                          child: Row(
                                                                            mainAxisSize: MainAxisSize.min,
                                                                            children: [
                                                                              const Icon(Icons.people_outline, color: Colors.white, size: 14),
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
                                                                        if (!scenario.isCompleted && scenario.entryFee > 0)
                                                                          const SizedBox(width: 8),
                                                                        
                                                                        if (!scenario.isCompleted && scenario.entryFee > 0)
                                                                          Container(
                                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                            decoration: BoxDecoration(
                                                                              gradient: LinearGradient(
                                                                                colors: [
                                                                                  AppTheme.accentGold.withOpacity(0.4),
                                                                                  AppTheme.accentGold.withOpacity(0.1),
                                                                                ],
                                                                              ),
                                                                              borderRadius: BorderRadius.circular(20),
                                                                              border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 1),
                                                                              boxShadow: [
                                                                                BoxShadow(
                                                                                  color: AppTheme.accentGold.withOpacity(0.2),
                                                                                  blurRadius: 8,
                                                                                  spreadRadius: -2,
                                                                                )
                                                                              ],
                                                                            ),
                                                                            child: Row(
                                                                              mainAxisSize: MainAxisSize.min,
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
                                                                        const SizedBox(width: 8), // Extra space at the end to prevent clipping
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 12),
                                                                // CONDITIONAL BUTTON RENDERING based on banned status
                                                                if (_banStatusMap[
                                                                            scenario
                                                                                .id] ==
                                                                        'banned' ||
                                                                    _banStatusMap[
                                                                            scenario
                                                                                .id] ==
                                                                        'suspended')
                                                                  // Show banned button
                                                                  Center(
                                                                    child: SizedBox(
                                                                      width: 250,
                                                                      child: _buildBannedButton(
                                                                          scenario),
                                                                    ),
                                                                  )
                                                                else ...[
                                                                  // Show normal buttons
                                                                  Center(
                                                                    child: SizedBox(
                                                                      width: 250,
                                                                      child:
                                                                          ElevatedButton(
                                                                        onPressed: () =>
                                                                            _onScenarioSelected(
                                                                                scenario),
                                                                        style: ElevatedButton.styleFrom(
                                                                            backgroundColor:
                                                                                currentAction,
                                                                            foregroundColor: (isDarkMode && currentAction == AppTheme.dGoldMain)
                                                                                ? Colors
                                                                                    .black
                                                                                : Colors
                                                                                    .white,
                                                                            shape: RoundedRectangleBorder(
                                                                                borderRadius:
                                                                                    BorderRadius.circular(20))),
                                                                        child: scenario
                                                                                .isCompleted
                                                                            ? const Text(
                                                                                "VER PODIO", style: TextStyle(fontWeight: FontWeight.bold))
                                                                            : _participantStatusMap[scenario.id] ==
                                                                                    true
                                                                                ? const Text(
                                                                                    "ENTRAR", style: TextStyle(fontWeight: FontWeight.bold))
                                                                                : Text(scenario.entryFee == 0
                                                                                    ? "INSCRIBETE (GRATIS)"
                                                                                    : "INSCRIBETE (${scenario.entryFee} 🍀)", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (!scenario.isCompleted &&
                                                                      _participantStatusMap[scenario.id] != true) ...[
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Center(
                                                                      child: SizedBox(
                                                                        width: 250,
                                                                        child:
                                                                            TextButton(
                                                                          onPressed:
                                                                              () =>
                                                                                  _onSpectatorSelected(scenario),
                                                                          style: TextButton
                                                                              .styleFrom(
                                                                            foregroundColor:
                                                                                Colors.white,
                                                                            side: const BorderSide(
                                                                                color:
                                                                                    Colors.white30),
                                                                            shape: RoundedRectangleBorder(
                                                                                borderRadius:
                                                                                    BorderRadius.circular(20)),
                                                                            backgroundColor:
                                                                                Colors.black26,
                                                                          ),
                                                                          child:
                                                                              const Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                                Icon(
                                                                                    Icons.visibility,
                                                                                    size: 16),
                                                                                SizedBox(
                                                                                    width: 8),
                                                                                Text(
                                                                                    "MODO ESPECTADOR",
                                                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
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
                          padding: const EdgeInsets.only(bottom: 20, top: 10),
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
        : Colors.white24; // Siempre usar color claro para el borde ya que el fondo es oscuro
    final labelColor = isActive
        ? textColor
        : Colors.white60; // Siempre usar color claro para el texto ya que el fondo es oscuro
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
