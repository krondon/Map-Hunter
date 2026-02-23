import 'dart:ui';
import 'package:provider/provider.dart';
import '../providers/game_request_provider.dart';
import '../../auth/providers/player_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/scenario.dart';
import '../../../core/theme/app_theme.dart';
import 'game_request_screen.dart';
import 'qr_scanner_screen.dart';
import 'event_waiting_screen.dart';
import '../models/event.dart';
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
  double _distanceToTarget = 800.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  
  // Debug State
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

    if (widget.scenario.type != 'online') {
      _startLocationUpdates();
      _showCodeFinderTutorial();
    } else {
      setState(() {
        _distanceToTarget = 0;
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
    if (widget.scenario.latitude == null || widget.scenario.longitude == null) return;

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
    });
  }

  void _handleFakeGPS() {
    if (!mounted) return;
    final isDarkMode = true /* always dark UI */;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, 
        child: AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
              SizedBox(width: 10),
              Expanded(child: Text("Ubicación Falsa Detectada", style: TextStyle(fontSize: 18))),
            ],
          ),
          content: const Text(
            "Para jugar limpio, debes desactivar las aplicaciones de ubicación falsa (Fake GPS).\n\nEl juego se detendrá hasta que uses tu ubicación real.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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
    // DEV: Simulated scan bypasses verification
    if (scannedCode == "DEV_SKIP_CODE") {
      _showSuccessDialog();
      return;
    }

    String pin = scannedCode;
    if (pin.startsWith("EVENT:")) {
      final parts = pin.split(':');
      if (parts.length >= 3) pin = parts[2];
    }
    _codeController.text = pin;
    // Verify directly without showing PIN dialog (code came from scanner)
    if (_codeController.text == widget.scenario.secretCode) {
      _showSuccessDialog();
    } else {
      _shakeController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("El código escaneado no coincide."),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _temperatureStatus {
    double dist = _forceProximity ? 5.0 : _distanceToTarget;
    if (dist > 500) return "CONGELADO";
    if (dist > 200) return "FRÍO";
    if (dist > 50) return "TIBIO";
    if (dist > 10) return "CALIENTE";
    return "¡AQUÍ ESTÁ!";
  }

  Color get _temperatureColor {
    double dist = _forceProximity ? 5.0 : _distanceToTarget;
    if (dist > 500) return Colors.cyanAccent;
    if (dist > 200) return Colors.blue;
    if (dist > 50) return Colors.orange;
    if (dist > 10) return Colors.red;
    return AppTheme.successGreen;
  }

  IconData get _temperatureIcon {
    double dist = _forceProximity ? 5.0 : _distanceToTarget;
    if (dist > 200) return Icons.ac_unit;
    return Icons.local_fire_department;
  }

  void _verifyCode() {
    _showPinDialog();
  }

  void _showPinDialog() {
    final List<TextEditingController> pinControllers = 
        List.generate(6, (_) => TextEditingController());
    final List<FocusNode> focusNodes = 
        List.generate(6, (_) => FocusNode());
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // Auto-focus first field
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNodes[0].requestFocus();
        });

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void submitPin() {
              final pin = pinControllers.map((c) => c.text).join();
              if (pin.length < 6) {
                setDialogState(() => errorText = 'Ingresa los 6 dígitos');
                return;
              }
              _codeController.text = pin;
              Navigator.pop(ctx);
              if (_codeController.text == widget.scenario.secretCode) {
                _showSuccessDialog();
              } else {
                _shakeController.forward(from: 0.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("El código no coincide."),
                    backgroundColor: AppTheme.dangerRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.accentGold.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1D),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_open, color: AppTheme.accentGold, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'VERIFICAR CÓDIGO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa el PIN de 6 dígitos',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      // 6 digit PIN fields
                      Row(
                        children: List.generate(6, (index) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: index < 5 ? 6 : 0),
                              height: 50,
                              child: TextField(
                                controller: pinControllers[index],
                                focusNode: focusNodes[index],
                                textAlign: TextAlign.center,
                                textCapitalization: TextCapitalization.characters,
                                keyboardType: TextInputType.text,
                                maxLength: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.accentGold, width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  setDialogState(() => errorText = null);
                                  if (value.isNotEmpty && index < 5) {
                                    focusNodes[index + 1].requestFocus();
                                  }
                                  // Auto-submit when all 6 digits entered
                                  final pin = pinControllers.map((c) => c.text).join();
                                  if (pin.length == 6) {
                                    submitPin();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(errorText!, style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12)),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'CANCELAR',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: submitPin,
                              child: const Text('VERIFICAR', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      for (final c in pinControllers) c.dispose();
      for (final f in focusNodes) f.dispose();
    });
  }

  void _showSuccessDialog() {
    final isDarkMode = true /* always dark UI */;
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (widget.scenario.entryFee > 0) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1,
                            title: const Text('Confirmar Solicitud'),
                            content: Text('Este evento tiene un costo de ${widget.scenario.entryFee} 🍀.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("SOLICITAR")),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                      }

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
                    child: const Text("SOLICITAR ACCESO"),
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: goldAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: goldAccent.withOpacity(0.5), width: 1),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: goldAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: goldAccent.withOpacity(0.1),
                      blurRadius: 20,
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
                        border: Border.all(color: goldAccent, width: 2),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: goldAccent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¿DETENER BÚSQUEDA?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Si sales ahora, podrías perder el progreso de tu búsqueda actual.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              'CANCELAR',
                              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
    if (widget.scenario.type == 'online') return [];
    final status = _temperatureStatus;
    IconData icon;
    Color color = _temperatureColor.withOpacity(0.12);
    if (status == "CONGELADO" || status == "FRÍO") icon = Icons.ac_unit;
    else if (status == "CALIENTE" || status == "TIBIO") icon = Icons.local_fire_department;
    else return [];

    return [
      Positioned(
        right: -50,
        top: 100,
        child: Opacity(opacity: 0.5, child: Icon(icon, size: 200, color: color)),
      ),
      Positioned(
        left: -50,
        bottom: 100,
        child: Opacity(opacity: 0.5, child: Icon(icon, size: 200, color: color)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double currentDistance = _forceProximity ? 5.0 : _distanceToTarget;
    final bool showInput = currentDistance <= 25 || widget.scenario.type == 'online';
    final bool isDarkMode = true /* always dark UI */;

    final bool shouldForceDark = isDarkMode ||
        _temperatureStatus == "CONGELADO" ||
        _temperatureStatus == "FRÍO" ||
        _temperatureStatus == "¡AQUÍ ESTÁ!";

    final Color effectiveTextColor = shouldForceDark ? Colors.white : const Color(0xFF1A1A1D);

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
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentGold.withOpacity(0.05),
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF150826).withOpacity(0.4),
                      border: Border.all(color: AppTheme.accentGold.withOpacity(0.6), width: 2),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
          ),
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
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: shouldForceDark
                      ? const LinearGradient(
                          colors: [AppTheme.dSurface0, AppTheme.dSurface1],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : AppTheme.mainGradient(context),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: Image.asset(
                  Provider.of<PlayerProvider>(context).isDarkMode ? 'assets/images/hero.png' : 'assets/images/loginclaro.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (shouldForceDark)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            Positioned.fill(
              child: Stack(
                children: [
                  // Brillo de proximidad (MUCHO MÁS NOTORIO)
                  AnimatedContainer(
                    duration: const Duration(seconds: 1),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _temperatureColor.withOpacity(showInput ? 0.45 : 0.30),
                        ],
                      ),
                    ),
                  ),
                  ..._buildBackgroundElements(),
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                        // Hint Card (Doble borde gold)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppTheme.accentGold.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF150826).withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.6), width: 2),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.lightbulb, color: AppTheme.accentGold, size: 20),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "PISTA INICIAL",
                                            style: TextStyle(
                                              color: AppTheme.accentGold,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        widget.scenario.starterClue,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Termómetro / Estatus (COLORES MÁS FUERTES)
                        Column(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) => Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.15),
                                child: Icon(
                                  _temperatureIcon, 
                                  size: 110, 
                                  color: _temperatureColor,
                                  shadows: [
                                    Shadow(color: _temperatureColor.withOpacity(0.9), blurRadius: 40),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _temperatureStatus,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: _temperatureColor,
                                shadows: [
                                  Shadow(color: _temperatureColor.withOpacity(0.9), blurRadius: 25),
                                  Shadow(color: Colors.black, blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (widget.scenario.type != 'online')
                              Text(
                                "${currentDistance.toInt()}m del objetivo",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                                ),
                              ),
                          ],
                        ),
                        // Footer
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: showInput
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "¡ESTÁS EN LA ZONA!",
                                      style: TextStyle(
                                        color: AppTheme.successGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        shadows: [Shadow(color: AppTheme.successGreen, blurRadius: 15)],
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successGreen.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: AppTheme.successGreen.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF150826).withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: AppTheme.successGreen.withOpacity(0.6), width: 2),
                                            ),
                                            child: const Column(
                                              children: [
                                                Icon(Icons.qr_code_scanner, color: AppTheme.successGreen, size: 60),
                                                SizedBox(height: 10),
                                                Text(
                                                  "Escanea el QR del evento",
                                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.successGreen,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 10,
                                        ),
                                        onPressed: () async {
                                          final scanned = await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                                          );
                                          if (scanned != null) _handleScannedCode(scanned);
                                        },
                                        icon: const Icon(Icons.qr_code),
                                        label: const Text("ESCANEAR AHORA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.accentGold,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: _verifyCode,
                                        child: const Text("VERIFICAR CÓDIGO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        // PANEL DE DESARROLLO (RESTAURADO)
                        Container(
                          margin: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.orange.withOpacity(0.4)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                        setState(() {
                                          _distanceToTarget = 5;
                                          _forceProximity = true;
                                        });
                                      },
                                      icon: const Icon(Icons.location_on, size: 16),
                                      label: const Text("Forzar Zona", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                                        _showSuccessDialog();
                                      },
                                      icon: const Icon(Icons.skip_next, size: 16),
                                      label: const Text("Saltar Todo", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  "CERRAR BUSCADOR",
                                  style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
