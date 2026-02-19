import 'dart:ui';
import 'package:provider/provider.dart';
import '../providers/game_request_provider.dart';
import '../../auth/providers/player_provider.dart';
import 'package:flutter/foundation.dart';
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
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Iniciar rastreo SOLO si es presencial
    if (widget.scenario.type != 'online') {
      _startLocationUpdates();
      _showCodeFinderTutorial();
    } else {
      // Si es online, 'simulamos' que estamos cerca para activar la UI
      setState(() {
        _distanceToTarget = 0; // Distancia 0 para activar todo
      });
    }
  }

  void _showCodeFinderTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_tutorial_CODE_FINDER') ?? false;
    if (hasSeen) return;

    final steps = MasterTutorialContent.getStepsForSection('CODE_FINDER', context);
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
            prefs.setBool('has_seen_tutorial_CODE_FINDER', true);
          },
        ),
      );
    });
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
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
              const SizedBox(width: 10),
              Expanded(child: Text("Ubicación Falsa Detectada", style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D), fontSize: 18))),
            ],
          ),
          content: Text(
            "Para jugar limpio, debes desactivar las aplicaciones de ubicación falsa (Fake GPS).\n\nEl juego se detendrá hasta que uses tu ubicación real.",
            style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (_distanceToTarget > 500) return Colors.cyanAccent;
    if (_distanceToTarget > 200) return Colors.blue;
    if (_distanceToTarget > 50) return Colors.orange;
    if (_distanceToTarget > 10) return Colors.red;
    return AppTheme.successGreen;
  }

  IconData get _temperatureIcon {
    if (_distanceToTarget > 200) return Icons.ac_unit;
    // Use fire icon for both Tibio and Caliente as requested
    return Icons.local_fire_department;
  }

  void _verifyCode() {
    // Verificar si coincide con el código secreto
    if (_codeController.text == widget.scenario.secretCode) {
      _showSuccessDialog();
    } else {
      // Shake animation for error
      _shakeController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("El código QR no coincide."),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const Color successColor = AppTheme.successGreen;
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: successColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: successColor.withOpacity(0.3), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: successColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: successColor.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: successColor.withOpacity(0.1),
                    border: Border.all(color: successColor.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: successColor.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: successColor, size: 50),
                ),
                const SizedBox(height: 24),
                const Text(
                  "¡CÓDIGO ENCONTRADO!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'Orbitron',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Has desbloqueado el acceso al escenario.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        // Validar si el evento tiene costo
                        if (widget.scenario.entryFee > 0) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1,
                              title: Row(
                                children: [
                                  const Icon(Icons.monetization_on, color: AppTheme.accentGold),
                                  const SizedBox(width: 10),
                                  Text('Confirmar Solicitud', style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D))),
                                ],
                              ),
                              content: Text(
                                'Este evento tiene un costo de ${widget.scenario.entryFee} 🍀.\n\n'
                                'Los tréboles se descontarán automáticamente de tu saldo CUANDO el administrador apruebe tu solicitud.',
                                style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('CANCELAR', style: TextStyle(color: isDarkMode ? Colors.white54 : AppTheme.lBrandMain)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGold,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("ENTENDIDO, SOLICITAR"),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) return;
                        }

                        // Submit request (Action: "allí es donde solicita acceso")
                        final requestProvider = Provider.of<GameRequestProvider>(context, listen: false);
                        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                        
                        if (playerProvider.currentPlayer != null) {
                            await requestProvider.submitRequest(
                              playerProvider.currentPlayer!, 
                              widget.scenario.id, 
                              widget.scenario.maxPlayers
                            );
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => GameRequestScreen(
                                      eventId: widget.scenario.id,
                                      eventTitle: widget.scenario.name,
                                    )),
                          );
                        }
                      },
                      child: const Text(
                        "SOLICITAR ACCESO",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                border: Border.all(color: goldAccent.withOpacity(0.3), width: 1),
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
                      '¿DETENER BÚSQUEDA?',
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
                      'Si sales ahora, podrías perder el progreso de tu búsqueda actual.',
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
    // Si es online, no mostramos elementos térmicos
    if (widget.scenario.type == 'online') return [];

    final status = _temperatureStatus;
    IconData icon;
    Color color = _temperatureColor.withOpacity(0.12);
    
    if (status == "CONGELADO" || status == "FRÍO") {
      icon = Icons.ac_unit;
    } else if (status == "CALIENTE" || status == "TIBIO") {
      icon = Icons.local_fire_department;
    } else {
      return []; // No bg elements for "¡AQUÍ ESTÁ!"
    }

    // Pattern of decorative icons
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
    // Only show input if close enough (e.g., < 20 meters)
    final bool showInput = _distanceToTarget <= 20;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine if we should force dark styling (for cold states or when target is reached)
    final bool shouldForceDark = isDarkMode ||
        _temperatureStatus == "CONGELADO" ||
        _temperatureStatus == "FRÍO" ||
        _temperatureStatus == "¡AQUÍ ESTÁ!";
    final bool useDarkStyle = shouldForceDark;
    final Color effectiveTextColor =
        useDarkStyle ? Colors.white : const Color(0xFF1A1A1D);
    final Color effectiveSecondaryTextColor =
        useDarkStyle ? Colors.white70 : const Color(0xFF4A4A5A);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            widget.scenario.name.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: effectiveTextColor,
              letterSpacing: 1.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 80,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 24.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(2), // Outer ring
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Container(
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
          ),
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

              // BG DECORATIVE ELEMENTS (Snowflakes or Fire)
              ..._buildBackgroundElements(),

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
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.15),
                                          width: 1),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: useDarkStyle
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                                color: useDarkStyle
                                                    ? Colors.white24
                                                    : Colors.black12),
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
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    height: 1.5,
                                                    color: effectiveTextColor),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                          const SizedBox(height: 40),

                          // Hot/Cold Indicator OR Online Header
                          if (widget.scenario.type == 'online')
                            // --- HEADER ONLINE ---
                            Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.0 + (_pulseController.value * 0.1),
                                      child: Container(
                                        padding: const EdgeInsets.all(30),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.cyanAccent.withOpacity(0.1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.cyanAccent.withOpacity(0.3),
                                              blurRadius: 30,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.cloud_done_rounded,
                                          size: 80,
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "EVENTO REMOTO DETECTADO",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.cyanAccent,
                                    letterSpacing: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                                  child: Text(
                                    "No es necesario desplazarse físicamente.\nIngresa el PIN para continuar.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          else
                            // --- INDICADOR PRESENCIAL (HOT/COLD) ---
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
                                    
                                    // --- CONDICIONAL ONLINE / PRESENCIAL ---
                                    if (widget.scenario.type == 'online') ...[
                                       // --- MODO ONLINE: SOLICITUD DIRECTA ---
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.touch_app_rounded, size: 60, color: Colors.cyanAccent),
                                            const SizedBox(height: 10),
                                            const Text(
                                              "Acceso directo habilitado",
                                              style: TextStyle(color: Colors.white70, fontSize: 16),
                                            ),
                                            const SizedBox(height: 20),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.cyanAccent,
                                                  foregroundColor: Colors.black,
                                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                                ),
                                                onPressed: () {
                                                  // Ir directo a la solicitud/ingreso de PIN
                                                    Navigator.of(context).pushReplacement(
                                                      MaterialPageRoute(
                                                          builder: (_) => GameRequestScreen(
                                                                eventId: widget.scenario.id,
                                                                eventTitle: widget.scenario.name,
                                                              )),
                                                    );
                                                },
                                                icon: const Icon(Icons.login),
                                                label: const Text("SOLICITAR ACCESO", style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      // --- MODO PRESENCIAL: SCANNER QR ---
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
                                    ],
                                    
                                    const SizedBox(height: 30),
                                    const Divider(color: Colors.white24),
                                    const SizedBox(height: 10),
                                    
                                    // Botón secundario para verificar (solo presencial o como fallback)
                                    if (widget.scenario.type != 'online')
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
                          // === BOTONES DE DESARROLLADOR ===
                          if (true) // Developer Button Enabled
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withOpacity(0.5)),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "🔧 MODO DESARROLLADOR",
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: () {
                                            setState(() => _distanceToTarget = 5);
                                          },
                                          icon: const Icon(Icons.location_on, size: 16),
                                          label: const Text("Forzar Zona", style: TextStyle(fontSize: 11)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: () {
                                            _showSuccessDialog(); // Simula éxito directo
                                          },
                                          icon: const Icon(Icons.skip_next, size: 16),
                                          label: const Text("Saltar Todo", style: TextStyle(fontSize: 11)),
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
              },
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }
}
