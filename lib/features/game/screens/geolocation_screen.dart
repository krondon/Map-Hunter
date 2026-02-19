import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/game_provider.dart';
import '../widgets/sponsor_banner.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:math' as math;
import '../models/clue.dart';

class GeolocationScreen extends StatefulWidget {
  final String clueId;

  const GeolocationScreen({super.key, required this.clueId});

  @override
  State<GeolocationScreen> createState() => _GeolocationScreenState();
}

class _GeolocationScreenState extends State<GeolocationScreen>
    with SingleTickerProviderStateMixin {
  double _currentDistance = 0; // meters
  bool _isLoading = true;
  String _errorMsg = '';
  late AnimationController _pulseController;
  Clue? _targetClue;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    // 1. Find target clue
    try {
      _targetClue = gameProvider.clues.firstWhere((c) => c.id == widget.clueId);

      if (_targetClue?.latitude == null || _targetClue?.longitude == null) {
        setState(() {
          _errorMsg = "Error: La pista no tiene coordenadas definidas.";
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMsg = "Error: Pista no encontrada.";
        _isLoading = false;
      });
      return;
    }

    // 2. Request permissions
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMsg = 'Los servicios de ubicación están desactivados.';
        _isLoading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMsg = 'Permiso de ubicación denegado.';
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMsg =
            'Los permisos de ubicación están denegados permanentemente.';
        _isLoading = false;
      });
      return;
    }

    // 3. Start listening
    setState(() => _isLoading = false);

    // Initial fetch
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _updateDistance(position);
    } catch (e) {
      debugPrint("Error getting initial position: $e");
    }

    // Stream
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // Update every 2 meters
      ),
    ).listen((Position position) {
      if (mounted) {
        _updateDistance(position);
      }
    });
  }

  void _updateDistance(Position userPosition) {
    if (_targetClue == null || _targetClue!.latitude == null) return;

    final double distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      _targetClue!.latitude!,
      _targetClue!.longitude!,
    );

    setState(() {
      _currentDistance = distance;
    });

    // Check completion threshold (e.g., 20 meters)
    if (_currentDistance <= 20) {
      _onTargetReached();
    }
  }

  // --- MANUAL SIMULATION FOR TESTING ---
  void _simulateApproach() {
    setState(() {
      // Decrease distance by 100m or set to 0 if close
      if (_currentDistance > 100) {
        _currentDistance -= 100;
      } else {
        _currentDistance = 0;
      }

      if (_currentDistance <= 20) {
        _onTargetReached();
      }
    });
  }

  bool _isCompleting = false;

  void _onTargetReached() async {
    if (_isCompleting) return;
    _isCompleting = true;

    // Stop pulse to indicate success
    _pulseController.stop();

    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    // Call backend
    final success = await gameProvider.completeCurrentClue("ARRIVED");

    if (success == null) {
      _isCompleting = false; // Reset on failure
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                size: 60,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Ubicación Encontrada!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '+50 XP',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
              },
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  String _getProximityText() {
    if (_currentDistance > 300) return '❄️ FRÍO';
    if (_currentDistance > 100) return '🌡️ TIBIO';
    if (_currentDistance > 50) return '🔥 CALIENTE';
    return '🎯 ¡MUY CERCA!';
  }

  Color _getProximityColor() {
    if (_currentDistance > 500) return Colors.blueGrey;
    if (_currentDistance > 200) return Colors.blue;
    if (_currentDistance > 100) return Colors.orange;
    if (_currentDistance > 50) return Colors.deepOrange;
    return AppTheme.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Error'), backgroundColor: AppTheme.darkBg),
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(_errorMsg, style: const TextStyle(color: Colors.white)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda por Ubicación'),
        backgroundColor: AppTheme.darkBg,
        actions: [
          // SIMULATION BUTTON (DEBUG)
          IconButton(
            icon: const Icon(Icons.directions_run),
            tooltip: 'Simular Avance (Debug)',
            onPressed: _simulateApproach,
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulse animation circle
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 200 + (_pulseController.value * 50),
                    height: 200 + (_pulseController.value * 50),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getProximityColor().withOpacity(0.5),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getProximityColor().withOpacity(0.2),
                          border: Border.all(
                            color: _getProximityColor(),
                            width: 4,
                          ),
                        ),
                        child: Icon(
                          Icons.navigation,
                          size: 80,
                          color: _getProximityColor(),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 50),

              // Proximity indicator
              Text(
                _getProximityText(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _getProximityColor(),
                ),
              ),

              const SizedBox(height: 20),

              // Distance
              Text(
                '${_currentDistance.toInt()} metros',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 40),

              // Hint
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: AppTheme.accentGold),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Acércate a la ubicación indicada para desbloquear.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Sponsor Banner
              Consumer<GameProvider>(
                builder: (context, game, _) {
                  return SponsorBanner(sponsor: game.currentSponsor);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
