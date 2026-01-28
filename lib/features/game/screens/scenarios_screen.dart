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
import '../services/game_access_service.dart'; // NEW
import '../mappers/scenario_mapper.dart'; // NEW


class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _hoverController;
  late Animation<Offset> _hoverAnimation;
  
  // New Controllers
  late AnimationController _shimmerController;
  late AnimationController _glitchController;
  
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isProcessing = false; // Prevents double taps

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
        duration: const Duration(milliseconds: 2000), // Occurs every 2 seconds roughly
    )..repeat();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
      // Empezar a precargar el video del primer avatar para que sea instantáneo
      VideoPreloadService().preloadVideo('assets/escenarios.avatar/explorer_m_scene.mp4');
    });
  }

  Future<void> _loadEvents() async {
    print("DEBUG: _loadEvents start");
    await Provider.of<EventProvider>(context, listen: false).fetchEvents();
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
    super.dispose();
  }




  Future<void> _onScenarioSelected(Scenario scenario) async {
    if (_isProcessing) return;

    if (scenario.isCompleted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WinnerCelebrationScreen(
            eventId: scenario.id,
            playerPosition: 0,
            totalCluesCompleted: 0,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final requestProvider = Provider.of<GameRequestProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);

      final accessService = GameAccessService();

      final result = await accessService.checkAccess(
        context: context,
        scenario: scenario,
        playerProvider: playerProvider,
        requestProvider: requestProvider,
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

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
                showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()));
                success = await gameProvider.initializeGameForApprovedUser(
                    playerProvider.currentPlayer!.userId, scenario.id);
                if (mounted) Navigator.pop(context);
              }

              if (success) {
                await gameProvider.fetchClues(eventId: scenario.id);
                if (mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen(eventId: scenario.id)));
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
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => CodeFinderScreen(scenario: scenario)),
          );
          break;
          
        case AccessResultType.needsAvatar:
           // Should be handled in allowed logic usually, but if separated:
           Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarSelectionScreen(eventId: scenario.id)));
           break;
          
        case AccessResultType.approvedWait: 
           break;

        case AccessResultType.needsPayment:
          // User needs to pay entry fee before joining
          final entryFee = result.data?['entryFee'] ?? 0.0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Se requiere inscripción de ${entryFee.toStringAsFixed(2)} 🍀'),
              backgroundColor: Colors.orange,
            ),
          );
          break;

        case AccessResultType.spectatorAllowed:
          // Spectator mode - navigate to read-only game view
          // TODO: Implement SpectatorScreen when Phase 2 is complete
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modo Espectador - Próximamente'),
              backgroundColor: Colors.blue,
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

  void _showErrorDialog(String msg, {String title = 'Atención'}) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Text(title,
                  style: const TextStyle(color: AppTheme.dangerRed)),
              content: Text(
                msg,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Entendido'))
              ],
            ));
  }



  @override
  Widget build(BuildContext context) {
    print("DEBUG: ScenariosScreen build. isLoading: $_isLoading");
    final eventProvider = Provider.of<EventProvider>(context);
    final appMode = Provider.of<AppModeProvider>(context);

    // Filtrar eventos según el modo seleccionado
    List<GameEvent> visibleEvents = eventProvider.events;
    if (appMode.isOnlineMode) {
      visibleEvents = visibleEvents.where((e) => e.type == 'online').toList();
    } else if (appMode.isPresencialMode) {
      // Presencial: Todo lo que NO sea online (o explícitamente presencial si hubiera ese tipo)
      visibleEvents = visibleEvents.where((e) => e.type != 'online').toList();
    }

    // Convertir Eventos a Escenarios usando Mapper
    final List<Scenario> scenarios = ScenarioMapper.fromEvents(visibleEvents);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: const Text('¿Salir de MapHunter?', style: TextStyle(color: Colors.white)),
            content: const Text(
              '¿Estás seguro que deseas salir de la aplicación?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
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
      child: Scaffold(
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Stack(
            children: [
             RefreshIndicator(
            onRefresh: _loadEvents,
            color: AppTheme.accentGold,
            backgroundColor: AppTheme.cardBg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Custom AppBar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.logout,
                                      color: Colors.white),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppTheme.cardBg,
                                        title: const Text('Cerrar Sesión',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        content: const Text(
                                          '¿Estás seguro que deseas cerrar sesión?',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancelar',
                                                style: TextStyle(
                                                    color: Colors.white54)),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await Provider.of<PlayerProvider>(
                                                      context,
                                                      listen: false)
                                                  .logout();
                                            },
                                            child: const Text('Salir',
                                                style: TextStyle(
                                                    color: AppTheme.dangerRed)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Escenarios',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Explanation Card - Catchy & Dopamine
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: SlideTransition(
                            position: _hoverAnimation,
                            child: AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                return Container(
                                  padding: const EdgeInsets.all(2.0), // Border width
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22), // Outer radius slightly larger
                                    gradient: SweepGradient(
                                      colors: const [
                                        AppTheme.accentGold, 
                                        Colors.white, 
                                        AppTheme.accentGold, 
                                        Colors.transparent, 
                                        AppTheme.accentGold
                                      ],
                                      stops: const [0.0, 0.2, 0.4, 0.5, 1.0],
                                      transform: GradientRotation(_shimmerController.value * 2 * 3.14159),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentGold.withOpacity(0.3 + 0.2 * 
                                            (0.5 - (0.5 - _shimmerController.value).abs())), // Pulsing shadow
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryPurple.withOpacity(0.9),
                                          Colors.deepPurple.shade900,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.diamond, // Diamond = Treasure
                                          color: AppTheme.accentGold, size: 28),
                                      const SizedBox(width: 8),
                                      Transform.rotate(
                                        angle: 3.14 / 1, // Rotate to look like a sword down or up
                                        child: const Icon(Icons.colorize, // Looks like a dagger/sword
                                            color: AppTheme.accentGold, size: 28),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: AnimatedBuilder(
                                          animation: _glitchController,
                                          builder: (context, child) {
                                            // Glitch logic: if value > 0.95, offset randomly
                                            double offsetX = 0;
                                            double offsetY = 0;
                                            Color color = AppTheme.accentGold;
                                            
                                            if (_glitchController.value > 0.90) {
                                              offsetX = (DateTime.now().millisecondsSinceEpoch % 3) - 1.5;
                                              offsetY = (DateTime.now().millisecondsSinceEpoch % 2) - 1.0;
                                              // Occasionally change color
                                              if (_glitchController.value > 0.98) {
                                                  color = Colors.cyanAccent;
                                              }
                                            }
                                            
                                            return Transform.translate(
                                              offset: Offset(offsetX, offsetY),
                                              child: Text(
                                                "Misión de Exploración",
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: color,
                                                  letterSpacing: 0.5,
                                                  shadows: _glitchController.value > 0.90 ? [
                                                      const Shadow(color: Colors.red, offset: Offset(-2, 0)),
                                                      const Shadow(color: Colors.blue, offset: Offset(2, 0)),
                                                  ] : [],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "¡Embárcate en una emocionante búsqueda del tesoro! Pon a prueba tus habilidades resolviendo pistas intrigantes y desafiantes para descubrir el gran premio oculto. ¿Estás listo para la aventura? ¡El tesoro te espera!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Title for Selection
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            "Elige tu campo de batalla",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Scenarios Carousel - Expanded to fit remaining space
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.accentGold))
                              : scenarios.isEmpty
                                  ? const Center(
                                      child: Text("No hay competencias disponibles",
                                          style: TextStyle(color: Colors.white)))
                                  : ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(
                                        dragDevices: {
                                          PointerDeviceKind.touch,
                                          PointerDeviceKind.mouse,
                                        },
                                      ),
                                      child: PageView.builder(
                                        controller: _pageController,
                                        onPageChanged: (index) {
                                          setState(() {
                                            _currentPage = index;
                                          });
                                        },
                                        itemCount: scenarios.length,
                                        itemBuilder: (context, index) {
                                          final scenario = scenarios[index];
                                          return AnimatedBuilder(
                                            animation: _pageController,
                                            builder: (context, child) {
                                              double value = 1.0;
                                              if (_pageController
                                                  .position.haveDimensions) {
                                                value = _pageController.page! -
                                                    index;
                                                value =
                                                    (1 - (value.abs() * 0.3))
                                                        .clamp(0.0, 1.0);
                                              } else {
                                                value = index == _currentPage
                                                    ? 1.0
                                                    : 0.7;
                                              }
                                              
                                              // Use LayoutBuilder to be responsive inside the carousel item
                                              return Center(
                                                child: SizedBox(
                                                  height: Curves.easeOut
                                                          .transform(value) *
                                                      400, // Reduced base height
                                                  width: Curves.easeOut
                                                          .transform(value) *
                                                      350,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _onScenarioSelected(scenario),
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                      blurRadius: 20,
                                                      offset:
                                                          const Offset(0, 10),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      // Background Image
                                                      (scenario.imageUrl
                                                                  .isNotEmpty &&
                                                              scenario.imageUrl
                                                                  .startsWith(
                                                                      'http'))
                                                          ? Image.network(
                                                              scenario.imageUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) {
                                                                return Container(
                                                                  color: Colors
                                                                      .grey[800],
                                                                  child: const Icon(
                                                                      Icons
                                                                          .broken_image,
                                                                      size: 50,
                                                                      color: Colors
                                                                          .white54),
                                                                );
                                                              },
                                                            )
                                                          : Container(
                                                              color: Colors
                                                                  .grey[900],
                                                              child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: const [
                                                                  Icon(
                                                                      Icons
                                                                          .image_not_supported,
                                                                      size: 50,
                                                                      color: Colors
                                                                          .white24),
                                                                  SizedBox(
                                                                      height:
                                                                          8),
                                                                  Text(
                                                                      "Sin imagen",
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .white24,
                                                                          fontSize:
                                                                              12)),
                                                                ],
                                                              ),
                                                            ),

                                                      // Gradient Overlay
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
                                                                      0.6),
                                                              Colors.black
                                                                  .withOpacity(
                                                                      0.9),
                                                            ],
                                                            stops: const [
                                                              0.3,
                                                              0.7,
                                                              1.0
                                                            ],
                                                          ),
                                                        ),
                                                      ),

                                                      // Content
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(24.0),
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            // State Tag
                                                            Row(
                                                              children: [
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                      horizontal: 12, vertical: 6),
                                                                  decoration: BoxDecoration(
                                                                    color: scenario.isCompleted 
                                                                        ? AppTheme.dangerRed.withOpacity(0.9)
                                                                        : Colors.black54,
                                                                    borderRadius: BorderRadius.circular(20),
                                                                    border: Border.all(
                                                                        color: Colors.white24),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      Icon(
                                                                          scenario.isCompleted 
                                                                              ? Icons.emoji_events
                                                                              : Icons.people,
                                                                          color: Colors.white,
                                                                          size: 14),
                                                                      const SizedBox(
                                                                          width:
                                                                              6),
                                                                      Text(
                                                                        scenario.isCompleted 
                                                                            ? 'FINALIZADA'
                                                                            : 'MAX ${scenario.maxPlayers}',
                                                                        style: const TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 12,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                                height: 12),

                                                            Text(
                                                              scenario.name,
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 24,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              scenario
                                                                  .description,
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 12,
                                                              ),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            const SizedBox(
                                                                height: 10),

                                                            if (scenario.date !=
                                                                    null &&
                                                                !scenario
                                                                    .isCompleted)
                                                              Center(
                                                                  child: ScenarioCountdown(
                                                                      targetDate:
                                                                          scenario.date!)),

                                                            const SizedBox(
                                                                height: 10),
                                                            SizedBox(
                                                              width: double
                                                                  .infinity,
                                                              child:
                                                                  ElevatedButton(
                                                                onPressed: () {
                                                                  _onScenarioSelected(
                                                                      scenario);
                                                                },
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .accentGold,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .black,
                                                                  elevation: 8,
                                                                ),
                                                                child: Text(
                                                                    scenario.isCompleted ? "VER PODIO" : "SELECCIONAR",
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold)),
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
                                          );
                                        },
                                      ),
                                    ),
                        ),
                        // Bottom spacing
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
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