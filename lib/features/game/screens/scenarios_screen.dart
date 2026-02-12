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
    final isDarkMode = playerProvider.isDarkMode;

    final Color currentSurface =
        isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec =
        isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: currentSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.5)),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout, color: AppTheme.dangerRed),
            const SizedBox(width: 12),
            Text('Cerrar Sesión',
                style:
                    TextStyle(color: currentText, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Estás seguro que deseas cerrar sesión?',
          style: TextStyle(color: currentTextSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: currentTextSec.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
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
            child: const Text('SALIR'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            Provider.of<PlayerProvider>(context, listen: false).isDarkMode
                ? AppTheme.cardBg
                : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            Text('Conócenos',
                style: TextStyle(
                    color: Provider.of<PlayerProvider>(context, listen: false)
                            .isDarkMode
                        ? Colors.white
                        : const Color(0xFF1A1A1D),
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'MapHunter es una experiencia de búsqueda del tesoro con realidad aumentada. '
          '¡Explora, resuelve pistas y compite por premios increíbles!',
          style: TextStyle(
              color:
                  Provider.of<PlayerProvider>(context, listen: false).isDarkMode
                      ? Colors.white70
                      : const Color(0xFF4A4A5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Entendido', style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
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
            Icon(Icons.description_outlined, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text('Términos y Condiciones',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Al utilizar MapHunter, aceptas nuestros términos de servicio y política de privacidad. '
            'Para más información, visita nuestro sitio web.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Entendido', style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
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
            Icon(Icons.support_agent_outlined, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text('Soporte',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '¿Necesitas ayuda? Contáctanos a través de nuestro correo de soporte: soporte@maphunter.com',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Entendido', style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
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
    }
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

                  final success = await requestProvider.joinOnlinePaidEvent(
                      playerProvider.currentPlayer!.userId,
                      scenario.id,
                      scenario.entryFee);

                  // Artificial delay for specific online join action
                  await Future.delayed(const Duration(seconds: 2));

                  if (!mounted) return;
                  Navigator.pop(context);

                  if (success) {
                    playerProvider
                        .updateLocalClovers(userClovers - scenario.entryFee);
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Error procesando el pago.')));
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
            // Caso 1: Tiene saldo suficiente -> Confirmar y Pagar
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
              // Procesar Pago
              setState(() => _isProcessing = true);
              LoadingOverlay.show(context);

              // Usar función apropiada según tipo de evento
              final bool success;
              if (scenario.type == 'online') {
                // Online: Pago + inscripción directa (sin esperar admin)
                success = await requestProvider.joinOnlinePaidEvent(
                    playerProvider.currentPlayer!.userId,
                    scenario.id,
                    entryFee);
              } else {
                // Presencial: Solo pago (luego pasa por flujo de solicitud)
                success = await requestProvider.processEventPayment(
                    playerProvider.currentPlayer!.userId,
                    scenario.id,
                    entryFee);
              }

              if (!mounted) return;
              LoadingOverlay.hide(context); // Close loading overlay

              if (success) {
                // Actualizar saldo localmente para reflejar cambio inmediato
                playerProvider.updateLocalClovers(userClovers - entryFee);
                await playerProvider.refreshProfile();

                // Actualizar mapa de participación
                setState(() {
                  _participantStatusMap[scenario.id] =
                      (scenario.type == 'online');
                });

                // Navegar al flujo correcto según tipo de evento
                if (mounted) {
                  if (scenario.type == 'online') {
                    // Online: Ir directo a la carrera (ya está inscrito)
                    final gameProvider =
                        Provider.of<GameProvider>(context, listen: false);
                    await gameProvider.fetchClues(eventId: scenario.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen(eventId: scenario.id)),
                    );
                  } else {
                    // Presencial: Mostrar termómetro primero -> QR -> Solicitar Acceso
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CodeFinderScreen(scenario: scenario)),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Error procesando el pago. Intenta de nuevo.')),
                );
              }
              setState(() => _isProcessing = false);
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
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDarkMode
                              ? [
                                  const Color(0xFF1A1F3A).withOpacity(0.95),
                                  const Color(0xFF0A0E27).withOpacity(0.95)
                                ]
                              : [
                                  Colors.white.withOpacity(0.98),
                                  const Color(0xFFF0F0F7).withOpacity(0.98)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.secondaryPink.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryPink.withOpacity(0.15),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header area with a subtle glow
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.secondaryPink.withOpacity(0.05),
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
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.secondaryPink,
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
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF2D3436),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No te preocupes, aún puedes vivir la experiencia desde el modo espectador.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white70
                                        : const Color(0xFF636E72),
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Main Button
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
                                      onPressed: () => Navigator.pop(ctx, true),
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

                                // Cancel Button
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white38,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 24),
                                  ),
                                  child: Text(
                                    'VOLVER AL INICIO',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white38
                                          : Colors.grey,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.weekend, 'Local'),
            _buildNavItem(1, Icons.explore, 'Escenarios'),
            _buildNavItem(2, Icons.account_balance_wallet, 'Recargas'),
            _buildNavItem(3, Icons.person, 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _navIndex == index;
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;

    final Color activeColor =
        isDarkMode ? AppTheme.dGoldMain : AppTheme.lBrandMain;
    final Color inactiveColor =
        isDarkMode ? Colors.white54 : const Color(0xFF4A4A5A);
    final Color activeBg = activeColor.withOpacity(0.1);

    return GestureDetector(
      onTap: () {
        setState(() {
          _navIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: activeColor.withOpacity(0.3))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
    final isDarkMode = playerProvider.isDarkMode;

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
            // Fondo con degradado radial dinámico (Compartido para todas las pestañas)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.6),
                    radius: 1.5,
                    colors: [
                      currentBrandDeep,
                      currentBg,
                    ],
                  ),
                ),
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
              style: TextStyle(
                color: Provider.of<PlayerProvider>(context).isDarkMode
                    ? Colors.white70
                    : const Color(0xFF4A4A5A),
                letterSpacing: title == 'Local' ? 2 : 8,
                fontWeight: FontWeight.bold,
                fontSize: title == 'Local' ? 14 : 12,
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
    final isDarkMode = playerProvider.isDarkMode;

    // Colores dinámicos
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
                            child: IconButton(
                              icon: Icon(Icons.logout,
                                  color: currentText, size: 28),
                              onPressed: _showLogoutDialog,
                            ),
                          ),
                          Positioned(
                            right: 0,
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
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
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
                            activeColor: currentAction,
                            textColor: isDarkMode ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip(
                            label: 'Próximos',
                            isActive: _selectedFilter == 'pending',
                            onTap: () =>
                                setState(() => _selectedFilter = 'pending'),
                            activeColor: Colors.blueAccent,
                            textColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildFilterChip(
                            label: 'Finalizados',
                            isActive: _selectedFilter == 'completed',
                            onTap: () =>
                                setState(() => _selectedFilter = 'completed'),
                            activeColor: isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                            textColor: Colors.white,
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
                                                      constraints.maxHeight,
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
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(24.0),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .bottomCenter,
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .end,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        6),
                                                                decoration: BoxDecoration(
                                                                    color: scenario.isCompleted
                                                                        ? AppTheme
                                                                            .dangerRed
                                                                        : Colors
                                                                            .black54,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            20),
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .white24)),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .people,
                                                                        color: Colors
                                                                            .white,
                                                                        size:
                                                                            14),
                                                                    const SizedBox(
                                                                        width:
                                                                            6),
                                                                    Text(
                                                                        scenario.isCompleted
                                                                            ? 'FINALIZADA'
                                                                            : 'MAX ${scenario.maxPlayers}',
                                                                        style: const TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 12)),
                                                                  ],
                                                                ),
                                                              ),

                                                              // POT DISPLAY (NEW)
                                                              if (!scenario
                                                                      .isCompleted &&
                                                                  scenario.entryFee >
                                                                      0)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              8),
                                                                  child:
                                                                      Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            6),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: AppTheme
                                                                          .accentGold
                                                                          .withOpacity(
                                                                              0.3),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                      border: Border.all(
                                                                          color: AppTheme.accentGold.withOpacity(
                                                                              0.8),
                                                                          width:
                                                                              1),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        const Icon(
                                                                            Icons
                                                                                .emoji_events,
                                                                            color:
                                                                                AppTheme.accentGold,
                                                                            size: 14),
                                                                        const SizedBox(
                                                                            width:
                                                                                4),
                                                                        Text(
                                                                          "${(scenario.currentParticipants * scenario.entryFee * 0.70).toStringAsFixed(0)} 🍀",
                                                                          style: const TextStyle(
                                                                              color: Colors.white,
                                                                              fontWeight: FontWeight.w800,
                                                                              fontSize: 12),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              const SizedBox(
                                                                  height: 12),
                                                              Text(
                                                                  scenario.name,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          24,
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
                                                                  height: 10),
                                                              if (scenario.date !=
                                                                      null &&
                                                                  !scenario
                                                                      .isCompleted)
                                                                ScenarioCountdown(
                                                                    targetDate:
                                                                        scenario
                                                                            .date!),
                                                              const SizedBox(
                                                                  height: 10),
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
                                                                SizedBox(
                                                                  width: 250,
                                                                  child: _buildBannedButton(
                                                                      scenario),
                                                                )
                                                              else ...[
                                                                // Show normal buttons
                                                                SizedBox(
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
                                                                            "VER PODIO")
                                                                        : _participantStatusMap[scenario.id] ==
                                                                                true
                                                                            ? const Text(
                                                                                "ENTRAR")
                                                                            : Text(scenario.entryFee == 0
                                                                                ? "INSCRIBETE (GRATIS)"
                                                                                : "INSCRIBETE (${scenario.entryFee} 🍀)"),
                                                                  ),
                                                                ),
                                                                if (!scenario
                                                                    .isCompleted) ...[
                                                                  const SizedBox(
                                                                      height:
                                                                          8),
                                                                  SizedBox(
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
        : (Provider.of<PlayerProvider>(context).isDarkMode
            ? Colors.white24
            : Colors.black12);
    final labelColor = isActive
        ? textColor
        : (Provider.of<PlayerProvider>(context).isDarkMode
            ? Colors.white60
            : Colors.black54);
    final fontWeight = isActive ? FontWeight.bold : FontWeight.normal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
