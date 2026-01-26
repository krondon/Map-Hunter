import 'dart:async'; // Importar Timer
import 'dart:ui'; // Para FontFeature
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart';
import '../providers/game_provider.dart';
import '../providers/event_provider.dart'; // Import EventProvider
import '../../../core/theme/app_theme.dart';
import '../models/game_request.dart';
import '../models/event.dart'; // Import GameEvent
import '../../layouts/screens/home_screen.dart';
import './scenarios_screen.dart';
import '../../auth/screens/avatar_selection_screen.dart';

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
  RealtimeChannel? _subscriptionRequest;
  RealtimeChannel? _subscriptionPlayer;
  Timer? _pollingTimer;

  
  GameRequest? _gameRequest;

  bool _isLoading = true;
  bool _isSubmitting = false; // Estado para el botón de envío

  @override
  void initState() {
    super.initState();
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
    
    _setupRealtimeSubscription();
    _startPolling(); // Iniciar sondeo como respaldo
    _startCountdown(); // Iniciar cuenta regresiva

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
    final userId = playerProvider.currentPlayer?.userId;
    final eventId = widget.eventId;

    if (userId == null || eventId == null) return;

    final supabase = Supabase.instance.client;

    // 1. Escuchar cambios en la solicitud (status update)
    _subscriptionRequest = supabase
        .channel('game_requests_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Escuchar INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'game_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
             debugPrint('[REALTIME] Request Change Detected: ${payload.eventType}');
             // Siempre verificar estado, sin importar el tipo de cambio
             _checkApprovalStatus();
          },
        )
        .subscribe();
        
    // 2. Escuchar INSERCIONES en game_players (Aprobación definitiva)
    _subscriptionPlayer = supabase
        .channel('game_players_inserts_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'game_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
             debugPrint('[REALTIME] Player Insert Detected!');
             final newRecord = payload.newRecord;
             if (newRecord['event_id'] == eventId) {
                _checkApprovalStatus();
             }
          },
        )
        .subscribe();
  }

  Future<void> _loadInitialData() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.userId;
    final eventId = widget.eventId;

    if (userId != null && eventId != null) {
      try {
        final request =
            await requestProvider.getRequestForPlayer(userId, eventId);
        // 2. VERIFICACIÓN CRÍTICA: ¿Ya es participante? (User game_players table)
        final participantData = await requestProvider.isPlayerParticipant(userId, eventId);
        final isParticipant = participantData['isParticipant'] as bool;
        final playerStatus = participantData['status'] as String?;

        if (mounted) {
           // Verificar si está suspendido/baneado
           if (isParticipant && (playerStatus == 'suspended' || playerStatus == 'banned')) {
             debugPrint('🚫 GameRequestScreen: User is BANNED, redirecting to ScenariosScreen');
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (_) => ScenariosScreen()),
             );
             return;
           }
           
           // Si ya es participante ACTIVO o está aprobado -> REDIRECCIÓN INMEDIATA
           if ((request != null && request.isApproved) || (isParticipant && playerStatus == 'active')) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomeScreen(eventId: widget.eventId!)),
              );
              return; 
           }

          setState(() {
            _gameRequest = request;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  // --- COUNTDOWN LOGIC ---
  Duration? _timeUntilStart;
  Timer? _countdownTimer;
  bool _eventStarted = false; // Flag to show "Started" message

  void _startCountdown() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final currentEventId = widget.eventId;
    if (currentEventId == null) return;
    
    // FORCE REFRESH: Always fetch from Supabase to get the latest Date/Time
    // This ensures that if we just edited the event, we see the change immediately.
    try {
      await eventProvider.fetchEvents(); 
    } catch (_) {
      // Ignore network errors, fallback to local cache
    }
    
    // Get event from provider
    GameEvent? event;
    try {
      event = eventProvider.events.firstWhere((e) => e.id == currentEventId);
    } catch (e) {
      return; // Event still not found
    }

    if (event == null) return;
    
    final now = DateTime.now();
    
    // Debug info
    print("Countdown Debug: Event Date: ${event.date} vs Now: $now");

    if (event.date.isAfter(now)) {
      if (mounted) {
        setState(() {
           _timeUntilStart = event!.date.difference(now);
           _eventStarted = false;
        });
      }
      
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final now = DateTime.now();
        if (event!.date.isAfter(now)) {
          setState(() {
            _timeUntilStart = event!.date.difference(now);
          });
        } else {
          timer.cancel();
          setState(() {
            _timeUntilStart = null;
            _eventStarted = true; // Event started!
          });
        }
      });
    } else {
      // Event already started
      if (mounted) {
        setState(() {
          _timeUntilStart = null;
          _eventStarted = true;
        });
      }
    }
  }

  Future<void> _checkApprovalStatus() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.userId;
    final eventId = widget.eventId;

    if (userId != null && eventId != null) {
      // 1. Obtener solicitud (si existe)
      final request =
          await requestProvider.getRequestForPlayer(userId, eventId);
      
      // 2. VERIFICACIÓN CRÍTICA: ¿Ya es participante? (User game_players table)
      // Esto cubre el caso donde la solicitud se borra al aprobarse o el realtime falla
      final participantData = await requestProvider.isPlayerParticipant(userId, eventId);
      final isParticipant = participantData['isParticipant'] as bool;
      final playerStatus = participantData['status'] as String?;

      debugPrint('🔍 GameRequestScreen: Checking approval status');
      debugPrint('   - isParticipant: $isParticipant');
      debugPrint('   - playerStatus: $playerStatus');
      debugPrint('   - request: ${request?.toJson()}');

      if (mounted) {
        setState(() {
          _gameRequest = request;
        });
      }

      // 3. VERIFICAR SI ESTÁ SUSPENDIDO/BANEADO
      if (isParticipant && (playerStatus == 'suspended' || playerStatus == 'banned')) {
        if (!mounted) return;
        
        _pollingTimer?.cancel(); // Detener polling
        
        debugPrint('🚫 GameRequestScreen: User is BANNED from this event!');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Has sido suspendido de esta competencia. No puedes participar.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Redirigir a ScenariosScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ScenariosScreen()),
        );
        return;
      }

      // 4. Si está aprobado O ya es participante ACTIVO, entrar al juego
      if ((request != null && request.isApproved) || (isParticipant && playerStatus == 'active')) {
        if (!mounted) return;
        
        _pollingTimer?.cancel(); // Detener polling
        
        debugPrint('✅ GameRequestScreen: User approved!');
        
        if (playerProvider.currentPlayer?.avatarId == null || playerProvider.currentPlayer!.avatarId!.isEmpty) {
          // No tiene avatar, ir a seleccionarlo
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => AvatarSelectionScreen(eventId: widget.eventId!)),
          );
        } else {
          // Ya tiene avatar, entrar directamente (o ir a historia)
          final gameProvider = Provider.of<GameProvider>(context, listen: false);
          try {
             await gameProvider.startGame(widget.eventId!);
          } catch (e) {
             debugPrint("Warn: Error auto-starting game: $e");
          }
          
          if (mounted) {
             Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomeScreen(eventId: widget.eventId!)),
             );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _subscriptionRequest?.unsubscribe();
    _subscriptionPlayer?.unsubscribe();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestJoin() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null && widget.eventId != null) {
      setState(() => _isSubmitting = true); // Activar loading
      
      try {
        debugPrint('[UI] Attempting to submit request...');
        
        // ✅ CAPTURAR el resultado del submitRequest
        final result = await requestProvider.submitRequest(
            playerProvider.currentPlayer!, widget.eventId!);

        if (!mounted) return;

        // ✅ MANEJAR cada caso específicamente
        switch (result) {
          case SubmitRequestResult.submitted:
            // Refresh data para mostrar la nueva solicitud
            final request = await requestProvider.getRequestForPlayer(
                playerProvider.currentPlayer!.userId, widget.eventId!);

            if (!mounted) return;
            
            setState(() {
              _gameRequest = request;
            });

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
            break;

          case SubmitRequestResult.alreadyRequested:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ya tienes una solicitud pendiente para este evento.',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Refresh para mostrar la solicitud existente en la UI
            final request = await requestProvider.getRequestForPlayer(
                playerProvider.currentPlayer!.userId, widget.eventId!);
            if (!mounted) return;
            setState(() {
              _gameRequest = request;
            });
            break;

          case SubmitRequestResult.alreadyPlayer:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.sports_esports, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Ya eres participante de este evento! Puedes empezar a jugar.',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.blue.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Navegar directamente al juego (rescue de estado inconsistente)
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => HomeScreen(eventId: widget.eventId!)),
            );
            break;

          case SubmitRequestResult.error:
            final errorMsg = requestProvider.lastError ?? 'Error desconocido';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Error: $errorMsg',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.dangerRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
            break;
        }
      } catch (e) {
        debugPrint('[UI] Exception in _handleRequestJoin: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false); // Desactivar loading
      }
    }
  }

  Future<void> _checkRequestStatus() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null && widget.eventId != null) {
      final request = await requestProvider.getRequestForPlayer(
          playerProvider.currentPlayer!.userId, widget.eventId!);

      if (mounted) {
        setState(() {
          _gameRequest = request;
        });
        if (request != null) {
          _showRequestStatusDialog(request);
        }
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
                    onPressed: () async {
                      // Initialize game and fetch clues
                      final gameProvider = Provider.of<GameProvider>(context, listen: false);
                      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

                      if (widget.eventId != null) {
                        if (playerProvider.currentPlayer?.avatarId == null || playerProvider.currentPlayer!.avatarId!.isEmpty) {
                           Navigator.of(context).pop();
                           Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => AvatarSelectionScreen(eventId: widget.eventId!)),
                          );
                          return;
                        }
                        await gameProvider.startGame(widget.eventId!);
                      }
                      
                      if (!context.mounted) return;

                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => HomeScreen(eventId: widget.eventId!)),
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
    final player = playerProvider.currentPlayer;

    return Scaffold(
      extendBodyBehindAppBar: true, // Para que el gradiente cubra todo
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (_) => ScenariosScreen()),
             );
          },
        ),
      ),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Game Icon
                                if (_gameRequest == null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppTheme.primaryGradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryPurple
                                              .withOpacity(0.5),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.sports_esports,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                // Welcome Message
                                Text(
                                  '¡Bienvenido ${player?.name ?? "Jugador"}!',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),

                                // --- COUNTDOWN WIDGET ---
                                if (_timeUntilStart != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: AppTheme.accentGold),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text("LA COMPETENCIA INICIA EN:",
                                            style: TextStyle(
                                                color: AppTheme.accentGold,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5)),
                                        const SizedBox(height: 8),
                                        Text(
                                          "${_timeUntilStart!.inDays}d ${_timeUntilStart!.inHours % 24}h ${_timeUntilStart!.inMinutes % 60}m ${_timeUntilStart!.inSeconds % 60}s",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              fontFeatures: [
                                                FontFeature.tabularFigures()
                                              ]),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (_eventStarted)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: Colors.greenAccent),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(Icons.play_circle_fill,
                                            color: Colors.greenAccent, size: 36),
                                        SizedBox(height: 8),
                                        Text("¡COMPETENCIA EN CURSO!",
                                            style: TextStyle(
                                                color: Colors.greenAccent,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                                fontSize: 16)),
                                        SizedBox(height: 4),
                                        Text("¡Corre a buscar las pistas!",
                                            style: TextStyle(
                                                color: Colors.white70)),
                                      ],
                                    ),
                                  ),

                                // Info Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBg.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.primaryPurple
                                          .withOpacity(0.3),
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
                                        size: 30,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '¿Te gustaría participar en este juego?',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Manda una solicitud para poder unirte. El administrador revisará tu solicitud antes de iniciar el juego.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),

                                // Request Status
                                if (_gameRequest != null) ...[
                                  // OCULTAR SI ESTÁ APROBADO (Porque nos vamos directo)
                                  if (!_gameRequest!.isApproved)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _gameRequest!.statusColor
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _gameRequest!.statusColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _gameRequest!.isRejected
                                                    ? Icons.cancel
                                                    : Icons.hourglass_empty,
                                            color: _gameRequest!.statusColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Estado: ${_gameRequest!.statusText}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    // Feedback visual transitorio - Centrado mejor visualmente
                                    const Padding(
                                      padding: EdgeInsets.only(top: 40, bottom: 20),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 50, 
                                            height: 50, 
                                            child: CircularProgressIndicator(
                                              color: Colors.greenAccent, 
                                              strokeWidth: 3,
                                            )
                                          ),
                                          SizedBox(height: 20),
                                          Text(
                                            "¡Entrando al evento...", 
                                            style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 16,
                                              letterSpacing: 1.1,
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Fixed Bottom Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // Wrap content
                            children: [
                              // Action Buttons
                              if (_gameRequest == null)
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
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
                                      onPressed: _isSubmitting
                                          ? null // Disable while submitting
                                          : () async {
                                              await _handleRequestJoin();
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isSubmitting
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'ENVIAR SOLICITUD',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                    ),
                                  ),
                                )
                              else if (_gameRequest!.isApproved)
                                // SI ESTA APROBADO: Espacio vacío (el loading está arriba)
                                const SizedBox(height: 48)
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: _checkRequestStatus,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: _gameRequest!.statusColor,
                                        width: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'VER ESTADO DE SOLICITUD',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),

                              // === BOTÓN DE DESARROLLADOR ===
                              if (kDebugMode &&
                                  _gameRequest != null &&
                                  !_gameRequest!.isApproved)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "🔧 MODO DESARROLLADOR",
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                          ),
                                          onPressed: () {
                                            // Simular aprobación navegando directamente al HomeScreen
                                            Navigator.of(context).pushReplacement(
                                              MaterialPageRoute(
                                                  builder: (_) => HomeScreen(
                                                      eventId: widget.eventId!)),
                                            );
                                          },
                                          icon: const Icon(Icons.check_circle,
                                              size: 18),
                                          label: const Text(
                                              "DEV: Simular Aprobación",
                                              style: TextStyle(fontSize: 13)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
