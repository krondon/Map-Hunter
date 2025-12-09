import 'dart:async'; // Importar Timer
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/player_provider.dart';
import '../providers/game_request_provider.dart';
import '../theme/app_theme.dart';
import '../models/game_request.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class GameRequestScreen extends StatefulWidget {
  final String? eventId;
  final String? eventTitle;

  const GameRequestScreen({
    super.key,
    this.eventId,
    this.eventTitle,
  });

  @override
  State<GameRequestScreen> createState() => _GameRequestScreenState();
}

class _GameRequestScreenState extends State<GameRequestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;

  // Variable para el truco de desarrollador
  int _devTapCount = 0;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
    _startPolling(); // Iniciar sondeo como respaldo
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _setupRealtimeSubscription() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.id;
    final eventId = widget.eventId;

    if (userId == null || eventId == null) return;

    final supabase = Supabase.instance.client;

    _subscription = supabase
        .channel('game_requests_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['event_id'] == eventId) {
              final status = newRecord['status'];
              if (status == 'approved') {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Tu solicitud ha sido aprobada!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Navigate to Home
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              } else {
                // Refresh to show rejected or other status
                setState(() {});
              }
            }
          },
        )
        .subscribe();
  }

  void _startPolling() {
    // Revisar cada 3 segundos por si falla el Realtime
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkApprovalStatus();
    });
  }

  Future<void> _checkApprovalStatus() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.id;
    final eventId = widget.eventId;

    if (userId != null && eventId != null) {
      final request =
          await requestProvider.getRequestForPlayer(userId, eventId);

      if (request != null && request.isApproved && mounted) {
        _pollingTimer?.cancel(); // Detener polling
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tu solicitud ha sido aprobada!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (mounted) {
        // Actualizar UI si cambió algo (ej. rechazado)
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _subscription?.unsubscribe();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestJoin() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null && widget.eventId != null) {
      try {
        await requestProvider.submitRequest(
            playerProvider.currentPlayer!, widget.eventId!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¡Solicitud enviada! Espera la aprobación del administrador.',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {}); // Refresh UI
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkRequestStatus() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null && widget.eventId != null) {
      final request = await requestProvider.getRequestForPlayer(
          playerProvider.currentPlayer!.id, widget.eventId!);

      if (request != null && mounted) {
        _showRequestStatusDialog(request);
      }
    }
  }

  void _showRequestStatusDialog(GameRequest request) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1F3A), Color(0xFF0A0E27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: request.statusColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                request.isApproved
                    ? Icons.check_circle
                    : request.isRejected
                        ? Icons.cancel
                        : Icons.access_time,
                color: request.statusColor,
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                'Estado de la Solicitud',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: request.statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: request.statusColor, width: 1),
                ),
                child: Text(
                  request.statusText,
                  style: TextStyle(
                    color: request.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (request.isApproved) ...[
                const SizedBox(height: 16),
                const Text(
                  '¡Puedes empezar a jugar!',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'IR AL JUEGO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final requestProvider = Provider.of<GameRequestProvider>(context);
    final player = playerProvider.currentPlayer;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: FutureBuilder<GameRequest?>(
                    future: player != null && widget.eventId != null
                        ? requestProvider.getRequestForPlayer(
                            player.id, widget.eventId!)
                        : Future.value(null),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final request = snapshot.data;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Game Icon
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primaryPurple.withOpacity(0.5),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.sports_esports,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Welcome Message
                          Text(
                            '¡Bienvenido ${player?.name ?? "Jugador"}!',
                            style: Theme.of(context).textTheme.displayLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Info Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primaryPurple.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.secondaryPink,
                                  size: 50,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '¿Te gustaría participar en este juego?',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Manda una solicitud para poder unirte. El administrador revisará tu solicitud antes de iniciar el juego.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Request Status
                          if (request != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: request.statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: request.statusColor,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    request.isApproved
                                        ? Icons.check_circle
                                        : request.isRejected
                                            ? Icons.cancel
                                            : Icons.hourglass_empty,
                                    color: request.statusColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Estado: ${request.statusText}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Action Buttons
                          if (request == null)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryPurple
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _handleRequestJoin();
                                    setState(() {}); // Refresh UI
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'ENVIAR SOLICITUD',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (request.isApproved)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Navigate to the actual game
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                        builder: (_) => const HomeScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'IR AL EVENTO',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _checkRequestStatus,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: request.statusColor,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'VER ESTADO DE SOLICITUD',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Logout Button
                          TextButton(
                            onPressed: () {
                              playerProvider.logout();
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Text(
                              'Cerrar Sesión',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
