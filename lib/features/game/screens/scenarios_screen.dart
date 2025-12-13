import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'dart:ui';
import '../models/scenario.dart';
import '../providers/event_provider.dart'; // Import EventProvider
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'code_finder_screen.dart';
import 'game_request_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../layouts/screens/home_screen.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    // Cargar eventos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    await Provider.of<EventProvider>(context, listen: false).fetchEvents();
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
      // Fetch clues for the selected event before navigating
      await Provider.of<GameProvider>(context, listen: false)
          .fetchClues(eventId: scenario.id);

      if (!mounted) return;

      Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => HomeScreen(eventId: scenario.id) 
      )
    );
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
    final eventProvider = Provider.of<EventProvider>(context);

    // Convertir Eventos a Escenarios
    final List<Scenario> scenarios = eventProvider.events.map((event) {
      // Compatibilidad con eventos antiguos y nuevos
      String location = '';
      // 1. Prioridad: Mostrar el nombre del lugar si existe
      if (event.locationName.isNotEmpty) {
        location = event.locationName;
      } 
      // 2. Si no hay nombre, mostramos las coordenadas numéricas
      else {
        // Convertimos latitud y longitud a texto con 4 decimales
        location = '${event.location.latitude.toStringAsFixed(4)}, ${event.location.longitude.toStringAsFixed(4)}';
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
                                    // Initial state
                                    value = index == _currentPage ? 1.0 : 0.7;
                                  }

                                  return Center(
                                    child: SizedBox(
                                      height: Curves.easeOut.transform(value) *
                                          450, // Responsive height
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
                                          // VERIFICACIÓN: Solo intentamos cargar si la URL no está vacía y empieza con http
                                (scenario.imageUrl.isNotEmpty && scenario.imageUrl.startsWith('http'))
                                    ? Image.network(
                                                  scenario.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[800],
                                                      child: const Icon(
                                                    Icons.broken_image,
                                                    size: 50,
                                                    color: Colors.white54),
                                                    );
                                                  },
                                                  loadingBuilder: (context, child,
                                                loadingProgress) {
                                                   if (loadingProgress == null)
                                                return child;
                                                   return Container(
                                                     color: Colors.black26,
                                                     child: const Center(
                                                    
                                                child:
                                                        CircularProgressIndicator(
                                                            color: AppTheme
                                                                .accentGold)),
                                                   );
                                                  },
                                                )
                                    // SI LA URL ESTÁ VACÍA, MOSTRAMOS UN PLACEHOLDER
                                    : Container(
                                        color: Colors.grey[900],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.image_not_supported, size: 50, color: Colors.white24),
                                            SizedBox(height: 8),
                                            Text("Sin imagen", style: TextStyle(color: Colors.white24, fontSize: 12)),
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
                                                        color: AppTheme
                                                            .secondaryPink,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                        scenario.state
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
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
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.location_on,
                                                        color: Colors.white70,
                                                        size: 16),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      scenario.location,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 14,
                                                        shadows: [
                                                          Shadow(
                                                            offset:
                                                                Offset(0, 1),
                                                            blurRadius: 2,
                                                            color: Colors.black,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                                                          8, // Added elevation for tactile feel
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
