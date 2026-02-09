import 'dart:async'; // Importar Timer
import 'dart:ui'; // Para FontFeature
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/game_repository.dart'; // DIP: Repository instead of Supabase
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart';
import '../providers/game_provider.dart';
import '../providers/event_provider.dart'; // Import EventProvider
import '../../../core/theme/app_theme.dart';
import '../models/game_request.dart';
import '../models/event.dart'; // Import GameEvent
import '../../layouts/screens/home_screen.dart';
import './scenarios_screen.dart';
import './spectator_mode_screen.dart';
import '../../auth/screens/avatar_selection_screen.dart';
import '../../../shared/widgets/loading_indicator.dart';

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
  GameRepository? _gameRepository; // DIP: Using repository instead of direct channels
  String? _requestChannelId;
  String? _playerChannelId;
  Timer? _pollingTimer;

  
  GameRequest? _gameRequest;

  bool _isLoading = true;
  bool _isSubmitting = false; // Estado para el botón de envío
  int _participantCount = 0; // NEW: Participant count
  int _maxParticipants = 30; // UPDATED: Dynamic limit

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

    // DIP: Using GameRepository for realtime subscriptions
    _gameRepository = GameRepository();

    // 1. Escuchar cambios en la solicitud (status update)
    _requestChannelId = _gameRepository!.subscribeToGameRequests(
      userId: userId,
      onRequestChange: (payload) {
        debugPrint('[REALTIME] Request Change Detected: ${payload.eventType}');
        // Siempre verificar estado, sin importar el tipo de cambio
        _checkApprovalStatus();
      },
    );
        
    // 2. Escuchar INSERCIONES en game_players (Aprobación definitiva)
    _playerChannelId = _gameRepository!.subscribeToGamePlayerInserts(
      userId: userId,
      eventId: eventId,
      onPlayerInsert: (payload) {
        debugPrint('[REALTIME] Player Insert Detected!');
        _checkApprovalStatus();
      },
    );
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
              // CRITICAL FIX: Reset spectator role
              playerProvider.setSpectatorRole(false);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomeScreen(eventId: widget.eventId!)),
              );
              return; 
           }

           // 🔥 FETCH PARTICIPANT COUNT
           final count = await requestProvider.getParticipantCount(eventId);
           
           // FETCH MAX PARTICIPANTS
           final eventProvider = Provider.of<EventProvider>(context, listen: false);
           int maxP = 30;
           try {
             final event = eventProvider.events.firstWhere((e) => e.id == eventId);
             maxP = event.maxParticipants;
           } catch (_) {}

           setState(() {
            _gameRequest = request;
            _isLoading = false;
            _participantCount = count;
            _maxParticipants = maxP;
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
        
        // CRITICAL FIX: Ensure user is NOT marked as spectator if approved as player
        playerProvider.setSpectatorRole(false);
        
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
    _gameRepository?.dispose(); // DIP: Cleanup via repository
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
        
        // Obtenemos el límite real del evento
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        int maxPlayers = 30; // Default fallback
        try {
          final event = eventProvider.events.firstWhere((e) => e.id == widget.eventId);
          maxPlayers = event.maxParticipants;
        } catch (_) {}

        // ✅ CAPTURAR el resultado del submitRequest
        final result = await requestProvider.submitRequest(
            playerProvider.currentPlayer!, widget.eventId!, maxPlayers);

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
            Provider.of<PlayerProvider>(context, listen: false).setSpectatorRole(false);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => HomeScreen(eventId: widget.eventId!)),
            );
            break;

          case SubmitRequestResult.eventFull:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.people_alt, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Evento lleno! El límite es de $maxPlayers participantes. Puedes entrar como espectador.',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'ENTRAR',
                  textColor: Colors.white,
                  onPressed: () {
                    Provider.of<PlayerProvider>(context, listen: false).setSpectatorRole(true);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => SpectatorModeScreen(eventId: widget.eventId!),
                      ),
                    );
                  },
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 8),
              ),
            );
            // Refresh count
            final newCount = await requestProvider.getParticipantCount(widget.eventId!);
            if (mounted) setState(() => _participantCount = newCount);
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
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final Color currentText = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
  final Color currentTextSec = isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode 
                ? [const Color(0xFF1A1F3A), const Color(0xFF0A0E27)]
                : [Colors.white, const Color(0xFFF5F5FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: request.statusColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: currentText,
                fontWeight: FontWeight.bold,
              ),
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
              Text(
                '¡Puedes empezar a jugar!',
                style: TextStyle(color: currentTextSec),
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
              child: Text('Cerrar', style: TextStyle(color: isDarkMode ? Colors.white54 : AppTheme.lBrandMain)),
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

    final isDarkMode = playerProvider.isDarkMode;
    
    // Paleta del Login
    final Color currentSurface0 = isDarkMode ? AppTheme.dSurface0 : AppTheme.lSurface0;
    final Color currentBrandDeep = isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;
    final Color currentText = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec = isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
    final Color currentCard = isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentBrand = isDarkMode ? AppTheme.dBrandMain : AppTheme.lBrandMain;
    final Color currentAccent = isDarkMode ? AppTheme.dGoldMain : AppTheme.lBrandMain;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: currentText),
          onPressed: () {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (_) => ScenariosScreen()),
             );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.5,
            colors: [
              currentBrandDeep,
              currentSurface0,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _isLoading
                  ? const LoadingIndicator()
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo de MapHunter (como en Login)
                                if (_gameRequest == null) ...[
                                  Image.asset(
                                    isDarkMode ? 'assets/images/logo4.1.png' : 'assets/images/logo4.2.png',
                                    height: 160,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Búsqueda del tesoro ☘️",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: currentTextSec,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],

                                // Welcome Message
                                  Text(
                                    '¡Bienvenido ${player?.name ?? "Jugador"}!',
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: currentText,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
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
                                          color: currentAccent),
                                    ),
                                    child: Column(
                                      children: [
                                         Text("LA COMPETENCIA INICIA EN:",
                                             style: TextStyle(
                                                 color: currentAccent,
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
                                      color: currentBrand.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: currentBrand, width: 2),
                                    ),
                                     child: Column(
                                       children: [
                                         Icon(Icons.play_circle_fill,
                                             color: currentBrand, size: 36),
                                         const SizedBox(height: 8),
                                         Text("¡COMPETENCIA EN CURSO!",
                                             style: TextStyle(
                                                 color: currentBrand,
                                                 fontWeight: FontWeight.bold,
                                                 letterSpacing: 1.5,
                                                 fontSize: 16)),
                                         const SizedBox(height: 4),
                                         Text("¡Corre a buscar las pistas!",
                                             style: TextStyle(
                                                 color: currentTextSec)),
                                       ],
                                     ),
                                  ),

                                // Info Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: currentBrand.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
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
                                      if (_participantCount >= _maxParticipants) ...[
                                        const Text(
                                          '¡EVENTO LLENO!',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            letterSpacing: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Participantes: $_participantCount / $_maxParticipants',
                                           style: TextStyle(
                                             color: currentTextSec,
                                             fontSize: 16,
                                           ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Se ha alcanzado el límite máximo. Puedes unirte en modo espectador para observar el progreso.',
                                           style: TextStyle(color: currentTextSec.withOpacity(0.7), fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ] else ...[
                                          Text(
                                            '¿Te gustaría participar?',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: currentText,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Participantes: $_participantCount / $_maxParticipants',
                                          style: TextStyle(color: currentTextSec, fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Manda una solicitud para poder unirte. El administrador revisará tu solicitud antes de iniciar el juego.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
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
                                          const LoadingIndicator(fontSize: 14, color: Colors.greenAccent),
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
                                      gradient: LinearGradient(
                                        colors: isDarkMode 
                                            ? [const Color(0xFFFFF176), const Color(0xFFFECB00)] 
                                            : [const Color(0xFF9D4EDD), const Color(0xFF5A189A)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isDarkMode ? const Color(0xFFFECB00) : const Color(0xFF5A189A))
                                              .withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
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
                                            foregroundColor: isDarkMode ? Colors.black : Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                      child: _isSubmitting
                                        ? const LoadingIndicator(fontSize: 12, showMessage: false)
                                          : Text(
                                              'ENVIAR SOLICITUD',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: isDarkMode ? Colors.black : Colors.white,
                                                letterSpacing: 1.5,
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
