import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/scenario.dart';
import '../theme/app_theme.dart';
import 'game_request_screen.dart';

class CodeFinderScreen extends StatefulWidget {
  final Scenario scenario;

  const CodeFinderScreen({super.key, required this.scenario});

  @override
  State<CodeFinderScreen> createState() => _CodeFinderScreenState();
}

class _CodeFinderScreenState extends State<CodeFinderScreen>
    with TickerProviderStateMixin {
  // State for the "Hot/Cold" mechanic
  double _distanceToTarget = 800.0; // Start far away (meters)
  bool _isSimulationActive = true;
  Timer? _simulationTimer;

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _shakeController;

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
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _codeController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
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
      body: Stack(
        children: [
          // Dynamic Background
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.darkBg,
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

                          // Debug Slider (Simulation)
                          if (_isSimulationActive && !showInput)
                            Column(
                              children: [
                                const Text("SIMULAR DISTANCIA (DEMO)",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                Slider(
                                  value: _distanceToTarget,
                                  min: 0,
                                  max: 1000,
                                  activeColor: _temperatureColor,
                                  onChanged: (val) {
                                    setState(() {
                                      _distanceToTarget = val;
                                    });
                                  },
                                ),
                              ],
                            ),

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
                                    TextField(
                                      controller: _codeController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          letterSpacing: 5,
                                          color: Colors
                                              .white), // Added color: Colors.white explicitly
                                      decoration: const InputDecoration(
                                        hintText: "----",
                                        hintStyle:
                                            TextStyle(color: Colors.white24),
                                        filled: true,
                                        fillColor: Colors.black26,
                                      ),
                                      onSubmitted: (_) => _verifyCode(),
                                    ),
                                    const SizedBox(height: 10),
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
    );
  }
}
