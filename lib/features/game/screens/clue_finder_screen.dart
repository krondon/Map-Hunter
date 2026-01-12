import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/clue.dart';
import '../../../core/theme/app_theme.dart';
import 'qr_scanner_screen.dart';

class ClueFinderScreen extends StatefulWidget {
  final Clue clue;

  const ClueFinderScreen({super.key, required this.clue});

  @override
  State<ClueFinderScreen> createState() => _ClueFinderScreenState();
}

class _ClueFinderScreenState extends State<ClueFinderScreen>
    with TickerProviderStateMixin {
  
  // --- STATE ---
  double _distanceToTarget = 800.0;
  StreamSubscription<Position>? _positionStreamSubscription;
  final List<Position> _positionHistory = []; // Cola para suavizado
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _shakeController;

  // Debug
  bool _forceProximity = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    if (widget.clue.latitude == null || widget.clue.longitude == null) {
      // Fallback if no location (shouldn't happen for geolocation clues, but safety first)
      setState(() => _distanceToTarget = 0); 
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) {
      
      if (position.isMocked) {
         _handleFakeGPS();
         return;
      }

      // --- SUAVIZADO DE GPS ---
      _positionHistory.add(position);
      if (_positionHistory.length > 5) {
        _positionHistory.removeAt(0); // Mantener solo los últimos 5 puntos
      }

      double avgLat = 0;
      double avgLng = 0;
      for (var p in _positionHistory) {
        avgLat += p.latitude;
        avgLng += p.longitude;
      }
      avgLat /= _positionHistory.length;
      avgLng /= _positionHistory.length;

      // Calcular distancia con el promedio suavizado
      final double distanceInMeters = Geolocator.distanceBetween(
        avgLat,
        avgLng,
        widget.clue.latitude!,
        widget.clue.longitude!,
      );

      if (mounted) {
        setState(() {
          _distanceToTarget = distanceInMeters;
        });
      }
    });
  }

  void _handleFakeGPS() {
    // Evitar acumulacion de dialogos
    if (!mounted) return;
    
    // Detener actualizaciones si es necesario o simplemente bloquear la UI
    // Mostramos un dialogo que no se puede cerrar facilmente
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Bloquear botón atrás
        child: AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
              SizedBox(width: 10),
              Expanded(child: Text("Ubicación Falsa Detectada", style: TextStyle(color: Colors.white, fontSize: 18))),
            ],
          ),
          content: const Text(
            "Para jugar limpio, debes desactivar las aplicaciones de ubicación falsa (Fake GPS).\n\nEl juego se detendrá hasta que uses tu ubicación real.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar dialogo
                Navigator.of(context).pop(); // Salir de la pantalla de juego
              },
              child: const Text("SALIR DEL JUEGO", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  void _handleScannedCode(String scannedCode) {
    // Expected format: Simple ID match or specific prefix
    // For now, we trust the scanner returned something useful.
    // If the clue has a specific QR code string, we match it.
    // If not, we assume ANY valid scan of the clue ID works.
    
    bool isValid = false;
    
    // 1. Check if it matches clue ID explicitly
    if (scannedCode.contains(widget.clue.id)) {
      isValid = true;
    } 
    // 2. Check if it matches the stored expected QR code (if any)
    else if (widget.clue.qrCode != null && widget.clue.qrCode!.isNotEmpty) {
      if (scannedCode == widget.clue.qrCode) isValid = true;
    }
    
    if (isValid) {
      // Direct navigation as requested
      Navigator.pop(context, true); 
    } else {
      _shakeController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("QR Incorrecto. Ese no es el código de esta misión, intenta de nuevo."),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // --- UI HELPERS ---

  String get _temperatureStatus {
    double dist = _forceProximity ? 5.0 : _distanceToTarget;
    if (dist > 500) return "CONGELADO";
    if (dist > 200) return "FRÍO";
    if (dist > 50) return "TIBIO";
    if (dist > 20) return "CALIENTE";
    return "¡AQUÍ ESTÁ!";
  }

  Color get _temperatureColor {
    double dist = _forceProximity ? 5.0 : _distanceToTarget;
    if (dist > 500) return Colors.cyanAccent;
    if (dist > 200) return Colors.blue;
    if (dist > 50) return Colors.orange;
    if (dist > 20) return Colors.deepOrange;
    return AppTheme.successGreen;
  }

  IconData get _temperatureIcon {
    double dist = _forceProximity ? 5.0 : _distanceToTarget;
    if (dist > 200) return Icons.ac_unit;
    if (dist > 50) return Icons.device_thermostat;
    return Icons.local_fire_department;
  }

  @override
  Widget build(BuildContext context) {
    // Current Distance Logic
    double currentDistance = _forceProximity ? 5.0 : _distanceToTarget;
    bool showInput = currentDistance <= 35;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.clue.title.toUpperCase(), style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Stack(
          children: [
            // Dynamic Gradient Overlay (Over the animated background)
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _temperatureColor.withOpacity(0.2),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hint Card
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                             Icon(Icons.search, color: AppTheme.accentGold),
                             SizedBox(width: 8),
                             Text("OBJETIVO", style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.clue.hint.isNotEmpty ? widget.clue.hint : "Encuentra la ubicación...",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Thermometer
                 Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.2),
                            child: Icon(_temperatureIcon, size: 80, color: _temperatureColor),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _temperatureStatus,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _temperatureColor,
                          shadows: [BoxShadow(color: _temperatureColor.withOpacity(0.5), blurRadius: 20)],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!showInput)
                        Text(
                          "${currentDistance.toInt()}m del objetivo",
                          style: const TextStyle(color: Colors.white54),
                        ),
                    ],
                 ),

                // Footer / Action Area
                Container(
                  padding: const EdgeInsets.all(20),
                  child: showInput
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "¡ESTÁS EN LA ZONA!",
                              style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () async {
                                  final scanned = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                                  );
                                  if (scanned != null) {
                                    _handleScannedCode(scanned);
                                  }
                                },
                                icon: const Icon(Icons.qr_code),
                                label: const Text("ESCANEAR CÓDIGO"),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                // === BOTONES DE DESARROLLADOR ===
                if (kDebugMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        const Divider(color: Colors.orange),
                        const Text(
                          "🔧 MODO DESARROLLADOR",
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  setState(() => _forceProximity = true);
                                },
                                icon: const Icon(Icons.location_on, size: 18),
                                label: const Text("Forzar Proximidad", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.pop(context, true); // Simula escaneo exitoso
                                },
                                icon: const Icon(Icons.skip_next, size: 18),
                                label: const Text("Saltar QR", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
