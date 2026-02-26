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
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';

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
    final playerProvider = context.watch<PlayerProvider>();
    final isDarkMode = playerProvider.isDarkMode;

    // Determine dynamic content based on admin-wait state
    final String headerText = _waitingForAdmin ? "CUENTA REGRESIVA FINALIZADA" : "PREPÁRATE";
    final String titleText = _waitingForAdmin
        ? "ESPERANDO AL ADMINISTRADOR"
        : "LA AVENTURA COMIENZA PRONTO";
    final String subtitleText = _waitingForAdmin
        ? "El contador ha terminado.\nEsperando señal del administrador para iniciar el evento..."
        : "El tesoro aguarda por el más valiente.\nMantente alerta.";
    final IconData iconData = _waitingForAdmin ? Icons.admin_panel_settings : Icons.hourglass_empty;
    
    // LOGIN CLARO STYLE COLORS
    final Color dGoldMain = const Color(0xFFFECB00);
    final Color lBrandMain = const Color(0xFF5A189A);
    final Color lTextPrimary = const Color(0xFF1A1A1D);
    final Color lTextSecondary = const Color(0xFF4A4A5A);

    final Color primaryAccent = isDarkMode ? AppTheme.accentGold : lBrandMain;
    final Color secondaryAccent = isDarkMode ? AppTheme.secondaryPink : dGoldMain;

    final Color iconColor = _waitingForAdmin ? Colors.orangeAccent : primaryAccent;
    final Color headerColor = _waitingForAdmin ? Colors.orangeAccent : primaryAccent;
    final Color glowColor = _waitingForAdmin
        ? Colors.orangeAccent.withOpacity(0.2)
        : secondaryAccent.withOpacity(0.2);
    final Color borderColor = _waitingForAdmin
        ? Colors.orangeAccent.withOpacity(0.5)
        : primaryAccent.withOpacity(0.5);

    final Color currentCardBg = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.9);
    final Color currentTitleColor = Colors.white;
    final Color currentSubtitleColor = Colors.white70;
    final Color currentBorderColor = (isDarkMode ? secondaryAccent : primaryAccent).withOpacity(0.3);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Image (hero.png for Dark, loginclaro.png for Light)
          Positioned.fill(
            child: isDarkMode
                ? Image.asset(
                    'assets/images/hero.png',
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/images/loginclaro.png',
                    fit: BoxFit.cover,
                  ),
          ),
          // Subtle Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.2),
            ),
          ),
          
          SafeArea(
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
                                color: primaryAccent.withOpacity(0.1),
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
                            textAlign: TextAlign.center,
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
                            style: TextStyle(
                              color: currentTitleColor,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            subtitleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: currentSubtitleColor,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Countdown or Admin Wait indicator
                          if (_waitingForAdmin)
                            // Admin-wait state
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: Colors.orangeAccent.withOpacity(0.6),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orangeAccent.withOpacity(0.05),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.orangeAccent.withOpacity(0.2),
                                        width: 1.0,
                                      ),
                                      color: Colors.orangeAccent.withOpacity(0.02),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.sync, color: Colors.orangeAccent, size: 32),
                                        const SizedBox(height: 12),
                                        const Text(
                                          "ESPERANDO INICIO MANUAL",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        RichText(
                                          textAlign: TextAlign.center,
                                          text: const TextSpan(
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontFamily: 'Roboto',
                                            ),
                                            children: [
                                              TextSpan(text: "El administrador debe presionar "),
                                              TextSpan(
                                                text: "PLAY",
                                                style: TextStyle(
                                                  color: Colors.orangeAccent,
                                                  fontWeight: FontWeight.bold,
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
                            )
                          else if (_timeLeft != null)
                            // Normal countdown state
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                        color: currentBorderColor,
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDarkMode ? secondaryAccent : primaryAccent).withOpacity(0.05),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: (isDarkMode ? secondaryAccent : primaryAccent).withOpacity(0.2),
                                        width: 1.0,
                                      ),
                                      color: (isDarkMode ? secondaryAccent : primaryAccent).withOpacity(0.02),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          "TIEMPO RESTANTE",
                                          style: TextStyle(
                                            color: currentSubtitleColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "${_timeLeft!.inDays}d ${_timeLeft!.inHours % 24}h ${_timeLeft!.inMinutes % 60}m ${_timeLeft!.inSeconds % 60}s",
                                          style: TextStyle(
                                            color: isDarkMode ? Colors.white : lBrandMain,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Orbitron',
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // DEV BYPASS: Only visible for admin role
                      Consumer<PlayerProvider>(
                        builder: (context, playerProv, _) {
                          final player = playerProv.currentPlayer;
                          if (player == null || !player.isAdmin) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.orange.shade400, width: 1.5),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                _timer?.cancel();
                                widget.onTimerFinished();
                              },
                              icon: const Icon(Icons.developer_mode, size: 18),
                              label: const Text('DEV: Saltar Espera',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          );
                        },
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Volver a Escenarios",
                            style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white54
                                    : AppTheme.lBrandMain.withOpacity(0.7))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
