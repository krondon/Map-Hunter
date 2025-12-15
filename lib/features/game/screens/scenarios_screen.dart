import 'dart:io' show Platform; 
import 'package:flutter/foundation.dart' show kIsWeb; 

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'dart:ui';
import '../models/scenario.dart';
import '../providers/event_provider.dart'; 
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'code_finder_screen.dart';
import 'game_request_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../layouts/screens/home_screen.dart';
import '../services/penalty_service.dart'; // IMPORT AGREGADO

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = true;
  final PenaltyService _penaltyService = PenaltyService(); // INSTANCIA SERVICIO

  @override
  void initState() {
    super.initState();
    print("DEBUG: ScenariosScreen initState");
    _pageController = PageController(viewportFraction: 0.85);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
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
    super.dispose();
  }

  Future<void> _onScenarioSelected(Scenario scenario) async {
    
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Los permisos de ubicación están denegados permanentemente. Habilítalos en la configuración.')),
          );
        }
        return;
      }
    }

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    if (playerProvider.currentPlayer == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final isParticipant = await requestProvider.isPlayerParticipant(
        playerProvider.currentPlayer!.id, scenario.id);

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading

    if (isParticipant) {
      // --- INICIO LEAVER BUSTER CHECK ---
      // 1. Verificar si está baneado antes de entrar al mapa
      final banEnd = await _penaltyService.attemptStartGame();
      
      if (!mounted) return;

      if (banEnd != null) {
        // Usuario castigado
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: const Text('⛔ Acceso Denegado', style: TextStyle(color: AppTheme.dangerRed)),
            content: Text(
              'Has sido penalizado por abandonar una partida en curso.\n\nPodrás volver a jugar a las: ${banEnd.hour.toString().padLeft(2, '0')}:${banEnd.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))
            ],
          ),
        );
        return; // DETENER NAVEGACIÓN
      } else {
        // 2. Si no está baneado, marcamos finish legally INMEDIATAMENTE
        // porque el mapa (HomeScreen) es zona segura.
        await _penaltyService.markGameFinishedLegally();
      }
      // --- FIN LEAVER BUSTER CHECK ---

      // Fetch clues for the selected event before navigating
      await Provider.of<GameProvider>(context, listen: false)
          .fetchClues(eventId: scenario.id);

      if (!mounted) return;

      Navigator.push(context,
          MaterialPageRoute(builder: (_) => HomeScreen(eventId: scenario.id)));
    } else {
      // Check if there is already a request
      final request = await requestProvider.getRequestForPlayer(
          playerProvider.currentPlayer!.id, scenario.id);

      if (!mounted) return;

      if (request != null) {
        // Already requested, go to status screen
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => GameRequestScreen(
                    eventId: scenario.id,
                    eventTitle: scenario.name,
                  )),
        );
      } else {
        // New user, must find code first
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => CodeFinderScreen(scenario: scenario)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: ScenariosScreen build. isLoading: $_isLoading");
    final eventProvider = Provider.of<EventProvider>(context);

    // Convertir Eventos a Escenarios
    final List<Scenario> scenarios = eventProvider.events.map((event) {
      String location = '';
      if (event.locationName.isNotEmpty) {
        location = event.locationName;
      }
      else {
        location =
            '${event.location.latitude.toStringAsFixed(4)}, ${event.location.longitude.toStringAsFixed(4)}';
      }
      double? latitude;
      double? longitude;
      try {
        latitude = (event as dynamic).latitude;
        longitude = (event as dynamic).longitude;
      } catch (_) {
        latitude = null;
        longitude = null;
      }
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
      );
    }).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
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

              // Explanation Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.2),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.map, color: AppTheme.accentGold),
                              SizedBox(width: 10),
                              Text(
                                "Misión de Exploración",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentGold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Participa en una búsqueda de tesoro donde tendrás que resolver pistas para encontrar el objetivo utilizando tus habilidades.",
                            style:
                                TextStyle(color: Colors.white70, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title for Selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Elige tu campo de batalla",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                ),
              ),

              const SizedBox(height: 20),

              // Scenarios Carousel
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accentGold))
                    : scenarios.isEmpty
                        ? const Center(
                            child: Text("No hay competencias disponibles",
                                style: TextStyle(color: Colors.white)))
                        : PageView.builder(
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
                                  if (_pageController.position.haveDimensions) {
                                    value = _pageController.page! - index;
                                    value = (1 - (value.abs() * 0.3))
                                        .clamp(0.0, 1.0);
                                  } else {
                                    value = index == _currentPage ? 1.0 : 0.7;
                                  }

                                  return Center(
                                    child: SizedBox(
                                      height: Curves.easeOut.transform(value) *
                                          450, 
                                      width:
                                          Curves.easeOut.transform(value) * 400,
                                      child: child,
                                    ),
                                  );
                                },
                                child: GestureDetector(
                                  onTap: () => _onScenarioSelected(scenario),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Background Image
                                          (scenario.imageUrl.isNotEmpty &&
                                                  scenario.imageUrl
                                                      .startsWith('http'))
                                              ? Image.network(
                                                  scenario.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[800],
                                                      child: const Icon(
                                                          Icons.broken_image,
                                                          size: 50,
                                                          color:
                                                              Colors.white54),
                                                    );
                                                  },
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      color: Colors.black26,
                                                      child: const Center(
                                                          child: CircularProgressIndicator(
                                                              color: AppTheme
                                                                  .accentGold)),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: Colors.grey[900],
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: const [
                                                      Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 50,
                                                          color:
                                                              Colors.white24),
                                                      SizedBox(height: 8),
                                                      Text("Sin imagen",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white24,
                                                              fontSize: 12)),
                                                    ],
                                                  ),
                                                ),

                                          // Gradient Overlay
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.6),
                                                  Colors.black.withOpacity(0.9),
                                                ],
                                                stops: const [0.3, 0.7, 1.0],
                                              ),
                                            ),
                                          ),

                                          // Content
                                          Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // State Tag
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black54,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        border: Border.all(
                                                            color:
                                                                Colors.white24),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                              Icons.people,
                                                              color: Colors
                                                                  .white70,
                                                              size: 12),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'MAX ${scenario.maxPlayers}',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),

                                                Text(
                                                  scenario.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    shadows: [
                                                      Shadow(
                                                        offset: Offset(0, 2),
                                                        blurRadius: 4,
                                                        color: Colors.black,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const SizedBox(height: 16),
                                                Text(
                                                  scenario.description,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                    shadows: [
                                                      Shadow(
                                                        offset: Offset(0, 1),
                                                        blurRadius: 2,
                                                        color: Colors.black,
                                                      ),
                                                    ],
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 20),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      // Immediate visual feedback or navigation
                                                      _onScenarioSelected(
                                                          scenario);
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          AppTheme.accentGold,
                                                      foregroundColor:
                                                          Colors.black,
                                                      elevation:
                                                          8, 
                                                    ),
                                                    child: const Text(
                                                        "SELECCIONAR",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}