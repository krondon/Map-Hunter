import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/event.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../admin/services/sponsor_service.dart'; // NEW
import '../../admin/models/sponsor.dart'; // NEW
import '../widgets/sponsor_banner.dart'; // NEW
import 'package:supabase_flutter/supabase_flutter.dart'; 

class EventWaitingScreen extends StatefulWidget {
  final GameEvent event;
  final VoidCallback onTimerFinished;

  const EventWaitingScreen(
      {super.key, required this.event, required this.onTimerFinished});

  @override
  State<EventWaitingScreen> createState() => _EventWaitingScreenState();
}

class _EventWaitingScreenState extends State<EventWaitingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration? _timeLeft;
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;



  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _calculateTime());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _loadSponsor();
  }

  Sponsor? _eventSponsor;

  Future<void> _loadSponsor() async {
    final service = SponsorService();
    final sponsor = await service.getSponsorForEvent(widget.event.id);
    if (mounted && sponsor != null && sponsor.hasSponsoredByBanner) {
      setState(() {
        _eventSponsor = sponsor;
      });
    }

    _setupRealtimeSubscription();
  }

  RealtimeChannel? _eventChannel;

  void _setupRealtimeSubscription() {
    try {
      debugPrint("🔍 Setting up realtime subscription for event: ${widget.event.id}");
      _eventChannel = Supabase.instance.client
          .channel('public:events:${widget.event.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.event.id,
            ),
            callback: (payload) {
              debugPrint("🔔 Event update received: ${payload.newRecord}");
              final newStatus = payload.newRecord['status'];
              if (newStatus == 'active') {
                debugPrint("✅ Event is now ACTIVE! Triggering navigation...");
                if (mounted) {
                   _timer?.cancel();
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onTimerFinished();
                   });
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("❌ Error setting up realtime subscription: $e");
    }
  }

  void _calculateTime() {
    // PRIORIDAD AL ESTADO: Si el evento ya está activo o completado, omitir cuenta regresiva
    if (widget.event.status == 'active' || widget.event.status == 'completed') {
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTimerFinished();
      });
      return;
    }

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTimerFinished();
      });
    }
  }

  @override
  void dispose() {
    _eventChannel?.unsubscribe();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft == null) return const Scaffold(backgroundColor: Colors.black);
    const bool isDarkMode = true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
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
                              color: AppTheme.secondaryPink.withOpacity(0.1),
                              border: Border.all(
                                  color: AppTheme.accentGold.withOpacity(0.5),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.secondaryPink.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.hourglass_empty,
                                size: 60, color: AppTheme.accentGold),
                          ),
                        ),
                        const SizedBox(height: 50),

                        const Text(
                          "PREPÁRATE",
                          style: TextStyle(
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            letterSpacing: 3,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "LA AVENTURA COMIENZA PRONTO",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "El tesoro aguarda por el más valiente.\nMantente alerta.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Countdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 25),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: AppTheme.secondaryPink.withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "TIEMPO RESTANTE",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Orbitron',
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "${_timeLeft!.inDays}d ${_timeLeft!.inHours % 24}h ${_timeLeft!.inMinutes % 60}m ${_timeLeft!.inSeconds % 60}s",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Orbitron',
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Sponsor Banner (Part of flow now)
                        if (_eventSponsor != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 80),
                            child: SponsorBanner(sponsor: _eventSponsor),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom "Back" button
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("Volver a Escenarios",
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.white54
                                : AppTheme.lBrandMain.withOpacity(0.7))),
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
