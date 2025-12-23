import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'dart:async';
import 'dart:math' as math;
import '../models/scenario.dart';
import '../../../core/theme/app_theme.dart';
import 'game_request_screen.dart';
import 'qr_scanner_screen.dart'; // Import scanner
import 'event_waiting_screen.dart'; // Import Waiting Screen
import '../models/event.dart'; // Import GameEvent

class CodeFinderScreen extends StatefulWidget {
  final Scenario scenario;

  const CodeFinderScreen({super.key, required this.scenario});

  @override
  State<CodeFinderScreen> createState() => _CodeFinderScreenState();
}

class _CodeFinderScreenState extends State<CodeFinderScreen>
    with TickerProviderStateMixin {
  // State for the "Hot/Cold" mechanic
  double _distanceToTarget = 800.0; // Valor inicial (placeholder) hasta tener GPS
  StreamSubscription<Position>? _positionStreamSubscription;

  // GPS Smoothing Buffer
  final List<Position> _positionBuffer = [];
  static const int _bufferLimit = 5; // Usamos 5 para mayor estabilidad (configurable a 3)

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  
  // Debug State
  bool _forceStart = false;

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

    // DEBUG: Imprimir el código secreto
    print(
        "SECRET CODE FOR ${widget.scenario.name}: ${widget.scenario.secretCode}");

    // Iniciar rastreo de ubicación real
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    // Verificar si tenemos coordenadas del objetivo
    if (widget.scenario.latitude == null || widget.scenario.longitude == null) {
      print("ERROR: El escenario no tiene coordenadas definidas.");
      return;
    }

    // Configuración estándar para móviles
    // Usamos high para un buen balance entre batería y precisión
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
      
      // --- LÓGICA ORIGINAL (SIN FILTROS COMPLEJOS) ---
      // Calculamos la distancia directa usando la fórmula del Haversine (nativa de Geolocator)
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.scenario.latitude!,
        widget.scenario.longitude!,
      );

      if (mounted) {
        setState(() {
          _distanceToTarget = distanceInMeters;
        });
      }
    }, onError: (error) {
      print("Error en stream de ubicación: $error");
    });
  }

  void _handleFakeGPS() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, 
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
    _codeController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleScannedCode(String scannedCode) {
    // Handle Format: "EVENT:{id}:{pin}"
    String pin = scannedCode;
    if (pin.startsWith("EVENT:")) {
      final parts = pin.split(':');
      if (parts.length >= 3) {
        pin = parts[2];
      }
    }
    
    _codeController.text = pin;
    _verifyCode();
  }


  // Visual Helpers based on distance
  String get _temperatureStatus {
    if (_distanceToTarget > 500) return "CONGELADO";
    if (_distanceToTarget > 200) return "FRÍO";
    if (_distanceToTarget > 50) return "TIBIO";
    if (_distanceToTarget > 10) return "CALIENTE";
    return "¡AQUÍ ESTÁ!";
  }

  Color get _temperatureColor {
    if (_distanceToTarget > 500) return Colors.cyanAccent;
    if (_distanceToTarget > 200) return Colors.blue;
    if (_distanceToTarget > 50) return Colors.orange;
    if (_distanceToTarget > 10) return Colors.red;
    return AppTheme.successGreen;
  }

  IconData get _temperatureIcon {
    if (_distanceToTarget > 200) return Icons.ac_unit;
    if (_distanceToTarget > 50) return Icons.device_thermostat;
    return Icons.local_fire_department;
  }

  void _verifyCode() {
  // 1. Validar longitud exacta antes de verificar el contenido
  if (_codeController.text.length != 6) {
    _shakeController.forward(from: 0.0); // Agitar pantalla
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("El código debe ser de 6 dígitos."),
        backgroundColor: Colors.orange, // Un color de advertencia diferente
        behavior: SnackBarBehavior.floating,
      ),
    );
    return; // Detener la ejecución aquí
  }

  // 2. Verificar si coincide con el código secreto
  if (_codeController.text == widget.scenario.secretCode) {
    _showSuccessDialog();
  } else {
    // Shake animation for error
    _shakeController.forward(from: 0.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Código incorrecto. Sigue buscando."),
        backgroundColor: AppTheme.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle,
            color: AppTheme.successGreen, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "¡CÓDIGO ENCONTRADO!",
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Has desbloqueado el acceso al escenario.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => GameRequestScreen(
                          eventId: widget.scenario.id,
                          eventTitle: widget.scenario.name,
                        )),
              );
            },
            child: const Text("SOLICITAR ACCESO"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show input if close enough (e.g., < 20 meters)
    final bool showInput = _distanceToTarget <= 20;
    


    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.scenario.name.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black45, // Semi-transparent for readability
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Stack(
          children: [
            // Dynamic Proximity Glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _temperatureColor.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            // Content
            SafeArea(
            child: LayoutBuilder(
              // Use LayoutBuilder to check for available space
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // Use spaceBetween instead of Spacer()
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: 20),

                              // Clue Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.lightbulb,
                                            color: AppTheme.accentGold),
                                        SizedBox(width: 10),
                                        Text(
                                          "PISTA INICIAL",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.accentGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      widget.scenario.starterClue,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.5,
                                          color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Hot/Cold Indicator
                          Column(
                            children: [
                              // Animated Icon
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: 1.0 + (_pulseController.value * 0.2),
                                    child: Icon(
                                      _temperatureIcon,
                                      size: 100,
                                      color: _temperatureColor,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _temperatureStatus,
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: _temperatureColor,
                                  shadows: [
                                    BoxShadow(
                                      color: _temperatureColor.withOpacity(0.5),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "${_distanceToTarget.toInt()}m del objetivo",
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Code Input Area
                          if (showInput)
                            AnimatedBuilder(
                              animation: _shakeController,
                              builder: (context, child) {
                                final offset = math.sin(
                                        _shakeController.value * math.pi * 4) *
                                    10;
                                return Transform.translate(
                                  offset: Offset(offset, 0),
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppTheme.accentGold.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "¡ESTÁS EN LA ZONA!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.successGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // --- QR CODE SECTION (Primary) ---
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.qr_code_2, size: 60, color: AppTheme.accentGold),
                                          const SizedBox(height: 10),
                                          const Text(
                                            "Escanea el QR del evento",
                                            style: TextStyle(color: Colors.white70, fontSize: 16),
                                          ),
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.accentGold,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(vertical: 15),
                                              ),
                                              onPressed: () async {
                                                final scannedCode = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                                                );
                                                if (scannedCode != null) {
                                                  _handleScannedCode(scannedCode);
                                                }
                                              },
                                              icon: const Icon(Icons.camera_alt),
                                              label: const Text("ESCANEAR AHORA", style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 30),
                                    const Divider(color: Colors.white24),
                                    const SizedBox(height: 10),
                                    // Hidden TextField for logic compatibility (optional, better to use variable)
                                    // kept invisible or removed. We will use _codeController programmatically.
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _verifyCode,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.accentGold,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text("VERIFICAR CÓDIGO"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
