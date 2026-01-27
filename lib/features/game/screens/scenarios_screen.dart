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
    setState(() {
      _isProcessing = true;
    });

    try {
      // Show loading immediately
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Solo verificamos permisos si NO estamos en Windows
      bool shouldCheckLocation = true;
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          shouldCheckLocation = false;
        }
      } catch (e) {
        shouldCheckLocation = true; 
      }

      if (shouldCheckLocation) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            Navigator.pop(context); // Pop loading
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Se requieren permisos de ubicación para participar')),
              );
            }
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          Navigator.pop(context); // Pop loading
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Los permisos de ubicación están denegados permanentemente. Habilítalos en la configuración.')),
            );
          }
          return;
        }

        // Check for Fake GPS
        try {
          final position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
          if (position.isMocked) {
            Navigator.pop(context); // Pop loading
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardBg,
                  title: const Text('⛔ Ubicación Falsa', style: TextStyle(color: Colors.red)),
                  content: const Text(
                    'Se ha detectado el uso de una aplicación de ubicación falsa.\n\nDesactívala para poder jugar.',
                    style: TextStyle(color: Colors.white),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))
                  ],
                ),
              );
            }
            return;
          }
        } catch (e) {
          // Ignore location errors here, let the game handle it later if needed or retry
        }
      }

      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final requestProvider = Provider.of<GameRequestProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);

      if (playerProvider.currentPlayer == null) {
        Navigator.pop(context); // Pop loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Sesión no válida. Por favor reloguea.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // IMPORTANTE: Usar userId para consultas de BD, no player.id (que puede ser gamePlayerId)
      final String userId = playerProvider.currentPlayer!.userId;

      // Loading already shown at start


    try {
      // === GATEKEEPER: Verificar estado del usuario para ESTE evento específico ===
      final participantData = await requestProvider.isPlayerParticipant(userId, scenario.id);
      final isGamePlayer = participantData['isParticipant'] as bool;
      final playerStatus = participantData['status'] as String?;
  
      if (!mounted) {
        Navigator.pop(context); // Dismiss loading if unmounted (though this pop might be wrong if dialog not shown yet? No, dialog IS shown above line 144)
        return; 
      }
      Navigator.pop(context); // Dismiss loading BEFORE logic to keep UI clean
  
      if (isGamePlayer) {
        // Usuario ya es game_player para este evento - verificar si está baneado
        debugPrint('ScenariosScreen: User is game_player for event ${scenario.id}');
        debugPrint('ScenariosScreen: Player status: $playerStatus');
        
        if (playerStatus == 'suspended' || playerStatus == 'banned') {
           // Mostrar diálogo de Acceso Denegado
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: const Text('⛔ Acceso Denegado', style: TextStyle(color: AppTheme.dangerRed)),
              content: const Text(
                'Has sido suspendido de esta competencia por un administrador.',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))
              ],
            ),
          );
          return;
        }
  
        // Fetch clues for the selected event before navigating
        await gameProvider.fetchClues(eventId: scenario.id);
  
        if (!mounted) return;
  
        // Verificar si ya tiene avatar (incluso si ya es participante)
        if (playerProvider.currentPlayer?.avatarId == null || playerProvider.currentPlayer!.avatarId!.isEmpty) {
          debugPrint('ScenariosScreen: Active player but no avatar. Redirecting to selection.');
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => AvatarSelectionScreen(eventId: scenario.id)));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => HomeScreen(eventId: scenario.id)));
        }
      } else {
      try {
        // Usuario NO es game_player - verificar si tiene solicitud
        final request = await requestProvider.getRequestForPlayer(userId, scenario.id);

        if (!mounted) return;

        if (request != null) {
          if (request.isApproved) {
            // Solicitud aprobada - Verificar si ya tiene avatar
            if (playerProvider.currentPlayer?.avatarId == null || playerProvider.currentPlayer!.avatarId!.isEmpty) {
              debugPrint('ScenariosScreen: Approved! Redirecting to Avatar Selection...');
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AvatarSelectionScreen(eventId: scenario.id)));
            } else {
              // Ya tiene avatar - Inicializar y entrar
              debugPrint('ScenariosScreen: Request approved and has avatar, initializing game...');
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              final success = await gameProvider.initializeGameForApprovedUser(userId, scenario.id);
              
              if (!mounted) return;
              Navigator.pop(context); // Dismiss loading

              if (success) {
                await gameProvider.fetchClues(eventId: scenario.id);
                if (!mounted) return;
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => HomeScreen(eventId: scenario.id)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error al inicializar el juego.')),
                );
              }
            }
          } else {
            // Solicitud pendiente o rechazada - ir a pantalla de solicitud
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => GameRequestScreen(
                          eventId: scenario.id,
                          eventTitle: scenario.name,
                      )),
            );
          }
        } else {
          // Sin solicitud - debe encontrar código primero
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => CodeFinderScreen(scenario: scenario)),
          );
        }
      } catch (e) {
        debugPrint('ScenariosScreen: Error in navigation: $e');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error de navegación: $e'), backgroundColor: Colors.red),
           );
        }
      }
    }
    } catch (e, stackTrace) {
      debugPrint('ScenariosScreen: CRITICAL ERROR: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        // Ensure loading is gone if it stuck
        // Note: We popped loading at start of try, so only need to handle crashes BEFORE that pop? 
        // No, we are inside the function. Logic is: Dialog -> Try -> ...
        // If error happens we might need to verify loading state. 
        // For now just show error.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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

    // Convertir Eventos a Escenarios
    final List<Scenario> scenarios = visibleEvents.map((event) {
      String location = '';
      if (event.locationName.isNotEmpty) {
        location = event.locationName;
      }
      else {
        location =
            '${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)}';
      }
      double? latitude = event.latitude;
      double? longitude = event.longitude;

      return Scenario(
        id: event.id,
        name: event.title,
        description: event.description,
        location: location,
        state: location,
        imageUrl: event.imageUrl,
        maxPlayers: event.maxParticipants,
        starterClue: event.clue,
        secretCode: event.pin,
        latitude: latitude,
        longitude: longitude,
        date: event.date,
        isCompleted: event.winnerId != null && event.winnerId!.isNotEmpty,
        type: event.type,
      );
    }).toList();

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
                                                                child: const Text(
                                                                    "SELECCIONAR",
                                                                    style: TextStyle(
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