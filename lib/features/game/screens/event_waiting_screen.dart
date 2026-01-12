
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/event.dart';

class EventWaitingScreen extends StatefulWidget {
  final GameEvent event;
  final VoidCallback onTimerFinished;

  const EventWaitingScreen({
    super.key, 
    required this.event, 
    required this.onTimerFinished
  });

  @override
  State<EventWaitingScreen> createState() => _EventWaitingScreenState();
}

class _EventWaitingScreenState extends State<EventWaitingScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration? _timeLeft;
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTime());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _calculateTime() {
    final now = DateTime.now(); // Local time
    // event.date should be in local time (Provider converts it correctly usually)
    // But since we fixed the Provider to send UTC, we receive UTC ISO string.
    // Provider.fromMap parses it.
    // If it's UTC, we should compare with UTC or ensure both are aligned.
    // simpler: DateTime.now() is local. event.date is likely Local if parsed without 'isUtc' logic or handled by framework.
    // Let's assume standard comparison handles it if both are DateTime.
    
    // IMPORTANT: In Flutter DateTime.parse("...Z") returns UTC.
    // If event.date is UTC, we must use DateTime.now().toUtc() or event.date.toLocal().
    final target = widget.event.date.toLocal();
    final current = DateTime.now();

    if (target.isAfter(current)) {
      if (mounted) {
        setState(() {
          _timeLeft = target.difference(current);
        });
      }
    } else {
      _timer?.cancel();
      widget.onTimerFinished();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == null) return const Scaffold(backgroundColor: Colors.black);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background particles or decoration (optional, keeping clean for now)
              
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with pulse
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryPurple.withOpacity(0.2),
                            border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.hourglass_empty, 
                            size: 60, 
                            color: AppTheme.accentGold
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                      
                      const Text(
                        "PREPÁRATE",
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "La aventura aún no comienza",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Por favor, espera con paciencia.\nEl tesoro aguarda valientemente.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 60),

                      // Countdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "TIEMPO RESTANTE",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "${_timeLeft!.inDays}d ${_timeLeft!.inHours % 24}h ${_timeLeft!.inMinutes % 60}m ${_timeLeft!.inSeconds % 60}s",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // === BOTÓN DE DESARROLLADOR ===
                      if (kDebugMode)
                        Container(
                          margin: const EdgeInsets.only(top: 30),
                          padding: const EdgeInsets.all(12),
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
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    widget.onTimerFinished(); // Simula fin del timer
                                  },
                                  icon: const Icon(Icons.skip_next, size: 18),
                                  label: const Text("DEV: Saltar Espera", style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Bottom "Back" button just in case
              Positioned(
                bottom: 20,
                left: 0, 
                right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Volver a Escenarios", style: TextStyle(color: Colors.white54)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
