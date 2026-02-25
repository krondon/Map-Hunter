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
  bool _waitingForAdmin = false; // True when countdown finished but admin hasn't started event
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

    final target = widget.event.date.toLocal();
    final current = DateTime.now();

    if (target.isAfter(current)) {
      // Still counting down
      if (mounted) {
        setState(() {
          _timeLeft = target.difference(current);
          _waitingForAdmin = false;
        });
      }
    } else {
      // Countdown reached zero — BUT we do NOT auto-activate.
      // The admin must manually start the event via the start_event RPC.
      // We enter "waiting for admin" mode and keep listening via Realtime.
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _timeLeft = Duration.zero;
          _waitingForAdmin = true;
        });
      }
      debugPrint("⏳ Countdown finished for event ${widget.event.id}. Waiting for admin to start.");
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

    // Determine dynamic content based on admin-wait state
    final String headerText = _waitingForAdmin ? "CUENTA REGRESIVA FINALIZADA" : "PREPÁRATE";
    final String titleText = _waitingForAdmin
        ? "ESPERANDO AL ADMINISTRADOR"
        : "LA AVENTURA COMIENZA PRONTO";
    final String subtitleText = _waitingForAdmin
        ? "El contador ha terminado.\nEsperando señal del administrador para iniciar el evento..."
        : "El tesoro aguarda por el más valiente.\nMantente alerta.";
    final IconData iconData = _waitingForAdmin ? Icons.admin_panel_settings : Icons.hourglass_empty;
    final Color iconColor = _waitingForAdmin ? Colors.orangeAccent : AppTheme.accentGold;
    final Color headerColor = _waitingForAdmin ? Colors.orangeAccent : AppTheme.accentGold;
    final Color glowColor = _waitingForAdmin
        ? Colors.orangeAccent.withOpacity(0.2)
        : AppTheme.secondaryPink.withOpacity(0.2);
    final Color borderColor = _waitingForAdmin
        ? Colors.orangeAccent.withOpacity(0.5)
        : AppTheme.accentGold.withOpacity(0.5);

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
                                  color: borderColor,
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor,
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(iconData,
                                size: 60, color: iconColor),
                          ),
                        ),
                        const SizedBox(height: 50),

                        Text(
                          headerText,
                          style: TextStyle(
                            color: headerColor,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            letterSpacing: 3,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          titleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          subtitleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Countdown or Admin Wait indicator
                        if (_waitingForAdmin)
                          // Admin-wait state: show pulsing indicator instead of countdown
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 25),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.orangeAccent.withOpacity(0.4),
                                  width: 1.5),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.sync, color: Colors.orangeAccent, size: 32),
                                SizedBox(height: 12),
                                Text(
                                  "ESPERANDO INICIO MANUAL",
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Orbitron',
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "El administrador debe presionar PLAY",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // Normal countdown state
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
