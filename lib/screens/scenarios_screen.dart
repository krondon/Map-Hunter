import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/scenario.dart';
import '../theme/app_theme.dart';
import 'code_finder_screen.dart';
import 'game_request_screen.dart';
import 'login_screen.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<Scenario> _scenarios = [
    const Scenario(
      id: 'millenium',
      name: 'Centro Comercial Millenium',
      description: 'Una arquitectura moderna con múltiples niveles y escondites secretos.',
      location: 'Los Dos Caminos, Caracas',
      state: 'Miranda',
      imageUrl: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&q=80&w=800', // Reliable modern architecture image
      maxPlayers: 50,
      starterClue: 'Busca donde el agua fluye hacia arriba y la gente camina sobre el aire.',
      secretCode: '1234',
    ),
    const Scenario(
      id: 'lider',
      name: 'Centro Comercial Líder',
      description: 'Grandes espacios y laberintos comerciales ideales para una búsqueda.',
      location: 'La California, Caracas',
      state: 'Miranda',
      imageUrl: 'https://images.unsplash.com/photo-1524230507669-5ff97982bb5e?auto=format&fit=crop&q=80&w=800',
      maxPlayers: 40,
      starterClue: 'Encuentra el pilar que sostiene el cielo artificial.',
      secretCode: '5678',
    ),
    const Scenario(
      id: 'guarenas',
      name: 'Ciudad de Guarenas',
      description: 'Explora los alrededores y descubre pistas en la ciudad satélite.',
      location: 'Guarenas, Edo. Miranda',
      state: 'Miranda',
      imageUrl: 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&q=80&w=800',
      maxPlayers: 100,
      starterClue: 'Donde el camino se divide en tres, el centro tiene la respuesta.',
      secretCode: '9012',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onScenarioSelected(Scenario scenario) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CodeFinderScreen(scenario: scenario)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          MaterialPageRoute(builder: (_) => const LoginScreen()), // Use deferred import if circular dependency, but here it is fine usually or use named routes
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
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                            style: TextStyle(color: Colors.white70, height: 1.5),
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
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = _scenarios[index];
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - index;
                          value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                        } else {
                          // Initial state
                           value = index == _currentPage ? 1.0 : 0.7;
                        }
                        
                        return Center(
                          child: SizedBox(
                            height: Curves.easeOut.transform(value) * 450, // Responsive height
                            width: Curves.easeOut.transform(value) * 400,
                            child: child,
                          ),
                        );
                      },
                      child: GestureDetector(
                        onTap: () => _onScenarioSelected(scenario),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
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
                                Image.network(
                                  scenario.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.broken_image, size: 50, color: Colors.white54),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                     if (loadingProgress == null) return child;
                                     return Container(
                                       color: Colors.black26,
                                       child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                                     );
                                  },
                                ),
                                
                                // Gradient Overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                        Colors.black.withOpacity(0.9),
                                      ],
                                      stops: const [0.5, 0.8, 1.0],
                                    ),
                                  ),
                                ),

                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // State Tag
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.secondaryPink,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              scenario.state.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.white24),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.people, color: Colors.white70, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'MAX ${scenario.maxPlayers}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
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
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            scenario.location,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        scenario.description,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                                // Immediate visual feedback or navigation
                                                _onScenarioSelected(scenario);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.accentGold,
                                              foregroundColor: Colors.black,
                                              elevation: 8, // Added elevation for tactile feel
                                            ),
                                            child: const Text(
                                                "SELECCIONAR",
                                                style: TextStyle(fontWeight: FontWeight.bold)
                                            ),
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
