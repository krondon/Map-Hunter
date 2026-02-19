import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/sponsor_banner.dart';
import '../models/clue.dart';
import '../../../core/theme/app_theme.dart';
import 'qr_scanner_screen.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClueFinderScreen extends StatefulWidget {
  final Clue clue; // Changed from PhysicalClue to Clue

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
    _showClueScannerTutorial();
  }

  void _showClueScannerTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial_CLUE_SCANNER') ?? false;
    if (hasSeen) return;

    final steps =
        MasterTutorialContent.getStepsForSection('CLUE_SCANNER', context);
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
            prefs.setBool('has_seen_tutorial_CLUE_SCANNER', true);
          },
        ),
      );
    });
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
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
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
    if (!mounted) return;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 40),
              const SizedBox(width: 10),
              Expanded(
                  child: Text("Ubicación Falsa Detectada",
                      style: TextStyle(
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF1A1A1D),
                          fontSize: 18))),
            ],
          ),
          content: Text(
            "Para jugar limpio, debes desactivar las aplicaciones de ubicación falsa (Fake GPS).\n\nEl juego se detendrá hasta que uses tu ubicación real.",
            style: TextStyle(
                color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar dialogo
                Navigator.of(context).pop(); // Salir de la pantalla de juego
              },
              child: const Text("SALIR DEL JUEGO",
                  style: TextStyle(color: Colors.red)),
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
          content: Text(
              "QR Incorrecto. Ese no es el código de esta misión, intenta de nuevo."),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
    // Use fire icon for both Tibio and Caliente as requested
    return Icons.local_fire_department;
  }

  Future<bool> _onWillPop() async {
    const Color goldAccent = AppTheme.accentGold;
    const Color cardBg = Color(0xFF151517);

    return (await showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: goldAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: goldAccent.withOpacity(0.3), width: 1),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: goldAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: goldAccent.withOpacity(0.1),
                      blurRadius: 15,
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
                        color: goldAccent.withOpacity(0.1),
                        border: Border.all(color: goldAccent.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: goldAccent, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '¿SALIR DE LA BÚSQUEDA?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Si sales ahora, interrumpirás la búsqueda del objetivo y tu progreso actual.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'CANCELAR',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              side: BorderSide(
                                  color: Colors.redAccent.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'SALIR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        )) ??
        false;
  }

  List<Widget> _buildBackgroundElements() {
    final status = _temperatureStatus;
    IconData icon;
    Color color = _temperatureColor.withOpacity(0.12); // Slightly more visible

    if (status == "CONGELADO" || status == "FRÍO") {
      icon = Icons.ac_unit;
    } else if (status == "CALIENTE" || status == "TIBIO") {
      icon = Icons.local_fire_department;
    } else {
      return []; // No bg elements for "¡AQUÍ ESTÁ!"
    }

    // Fixed positions for a nice decorative spread
    final List<math.Point> positions = [
      const math.Point(0.9, 0.15), // Superior derecha
      const math.Point(0.1, 0.85), // Inferior izquierda
    ];

    return positions.map((p) {
      const double iconSize = 250;
      return Positioned(
        left: MediaQuery.of(context).size.width * p.x - (iconSize / 2),
        top: MediaQuery.of(context).size.height * p.y - (iconSize / 2),
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.6,
            child: Icon(
              icon,
              size: iconSize,
              color: color,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Current Distance Logic
    final double currentDistance = _forceProximity ? 5.0 : _distanceToTarget;
    final bool showInput = currentDistance <= 35;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bool shouldForceDark = isDarkMode ||
        _temperatureStatus == "CONGELADO" ||
        _temperatureStatus == "FRÍO" ||
        _temperatureStatus == "¡AQUÍ ESTÁ!";
    final bool useDarkStyle = shouldForceDark;
    final Color effectiveTextColor =
        useDarkStyle ? Colors.white : const Color(0xFF1A1A1D);
    final Color effectiveHintTextColor =
        useDarkStyle ? Colors.white : const Color(0xFF2D3436);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leadingWidth: 80,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
          title: Text(widget.clue.title.toUpperCase(),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: effectiveTextColor)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: shouldForceDark
                ? const LinearGradient(
                    colors: [AppTheme.dSurface0, AppTheme.dSurface1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : AppTheme.mainGradient(context),
          ),
          child: Stack(
            children: [
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
              ..._buildBackgroundElements(),
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
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.search, color: AppTheme.accentGold),
                                SizedBox(width: 8),
                                Text("OBJETIVO",
                                    style: TextStyle(
                                        color: AppTheme.accentGold,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.clue.hint.isNotEmpty
                                  ? widget.clue.hint
                                  : "Encuentra la ubicación...",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, color: effectiveHintTextColor),
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
                              child: Icon(_temperatureIcon,
                                  size: 80, color: _temperatureColor),
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
                            shadows: [
                              BoxShadow(
                                  color: _temperatureColor.withOpacity(0.5),
                                  blurRadius: 20)
                            ],
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
                    // Action Area & Sponsor
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showInput)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGold,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () async {
                                  final scanned = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const QRScannerScreen()),
                                  );
                                  if (scanned != null) {
                                    _handleScannedCode(scanned);
                                  }
                                },
                                icon: const Icon(Icons.qr_code),
                                label: const Text("ESCANEAR CÓDIGO"),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Consumer<GameProvider>(
                          builder: (context, game, _) {
                            return SponsorBanner(sponsor: game.currentSponsor);
                          },
                        ),
                        const SizedBox(height: 10),
                        // DEV BUTTONS
                        if (true)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _forceProximity = true),
                                    child: const Text("DEV: CERCA",
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10)),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("DEV: SALTAR",
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 10)),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
