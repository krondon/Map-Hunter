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
  GameRepository?
      _gameRepository; // DIP: Using repository instead of direct channels
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Precargar ambas imágenes de fondo para transiciones suaves
    precacheImage(const AssetImage('assets/images/hero.png'), context);
    precacheImage(const AssetImage('assets/images/loginclaro.png'), context);
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
        final participantData =
            await requestProvider.isPlayerParticipant(userId, eventId);
        final isParticipant = participantData['isParticipant'] as bool;
        final playerStatus = participantData['status'] as String?;

        if (mounted) {
          // Verificar si está suspendido/baneado
          if (isParticipant &&
              (playerStatus == 'suspended' || playerStatus == 'banned')) {
            debugPrint(
                '🚫 GameRequestScreen: User is BANNED, redirecting to ScenariosScreen');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ScenariosScreen()),
            );
            return;
          }

          // Si ya es participante ACTIVO o está aprobado -> REDIRECCIÓN INMEDIATA
          if ((request != null && request.isApproved) ||
              (isParticipant && playerStatus == 'active')) {
            // CRITICAL FIX: Reset spectator role
            playerProvider.setSpectatorRole(false);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => HomeScreen(eventId: widget.eventId!)),
            );
            return;
          }

          // 🔥 FETCH PARTICIPANT COUNT
          final count = await requestProvider.getParticipantCount(eventId);

          // FETCH MAX PARTICIPANTS
          final eventProvider =
              Provider.of<EventProvider>(context, listen: false);
          int maxP = 30;
          try {
            final event =
                eventProvider.events.firstWhere((e) => e.id == eventId);
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

    // PRIORIDAD AL ESTADO: Si el evento ya está activo o completado, omitir cuenta regresiva
    if (event.status == 'active' || event.status == 'completed') {
      if (mounted) {
        setState(() {
          _timeUntilStart = null;
          _eventStarted = true;
        });
      }
      return;
    }

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
        
        // RE-VERIFICAR ESTADO EN CADA TICK (Por si cambia a active manualmente)
        // Nota: Esto requiere que 'event' se actualice, lo cual no sucede aquí automáticamente.
        // GameRequestScreen debería escuchar cambios del evento si queremos realtime real.
        // Por ahora, mantenemos la lógica de fecha, pero ya tenemos la validación inicial.
        
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
      final participantData =
          await requestProvider.isPlayerParticipant(userId, eventId);
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
      if (isParticipant &&
          (playerStatus == 'suspended' || playerStatus == 'banned')) {
        if (!mounted) return;

        _pollingTimer?.cancel(); // Detener polling

        debugPrint('🚫 GameRequestScreen: User is BANNED from this event!');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Has sido suspendido de esta competencia. No puedes participar.'),
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
      if ((request != null && request.isApproved) ||
          (isParticipant && playerStatus == 'active')) {
        if (!mounted) return;

        _pollingTimer?.cancel(); // Detener polling

        debugPrint('✅ GameRequestScreen: User approved!');

        // CRITICAL FIX: Ensure user is NOT marked as spectator if approved as player
        playerProvider.setSpectatorRole(false);

        if (playerProvider.currentPlayer?.avatarId == null ||
            playerProvider.currentPlayer!.avatarId!.isEmpty) {
          // No tiene avatar, ir a seleccionarlo
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) =>
                    AvatarSelectionScreen(eventId: widget.eventId!)),
          );
        } else {
          // Ya tiene avatar, entrar directamente (o ir a historia)
          final gameProvider =
              Provider.of<GameProvider>(context, listen: false);
          try {
            await gameProvider.startGame(widget.eventId!);
          } catch (e) {
            debugPrint("Warn: Error auto-starting game: $e");
          }

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => HomeScreen(eventId: widget.eventId!)),
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
        final eventProvider =
            Provider.of<EventProvider>(context, listen: false);
        int maxPlayers = 30; // Default fallback
        try {
          final event =
              eventProvider.events.firstWhere((e) => e.id == widget.eventId);
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
            Provider.of<PlayerProvider>(context, listen: false)
                .setSpectatorRole(false);
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
                    Provider.of<PlayerProvider>(context, listen: false)
                        .setSpectatorRole(true);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            SpectatorModeScreen(eventId: widget.eventId!),
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
            final newCount =
                await requestProvider.getParticipantCount(widget.eventId!);
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
        if (mounted)
          setState(() => _isSubmitting = false); // Desactivar loading
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
    final isDarkMode = true /* always dark UI */;
    final Color currentOrange =
        const Color(0xFFFF9800); // Naranja de conexión perdida
    final Color cardBg = const Color(0xFF151517); // Fondo muy oscuro

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding:
              const EdgeInsets.all(4), // Espacio para el efecto de doble borde
          decoration: BoxDecoration(
            color:
                currentOrange.withOpacity(0.2), // Tono naranja suave exterior
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentOrange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentOrange.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de Reloj Naranja Circundado
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: currentOrange, width: 3),
                  ),
                  child: Icon(
                    Icons.access_time_filled_rounded,
                    color: currentOrange,
                    size: 45,
                  ),
                ),
                const SizedBox(height: 24),

                // Título
                const Text(
                  'Estado de la solicitud',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Píldora de Estado (Pendiente/Naranja)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    request.statusText.toUpperCase(),
                    style: TextStyle(
                      color: request.isApproved
                          ? Colors.greenAccent
                          : (request.isRejected
                              ? Colors.redAccent
                              : currentOrange),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Botón de Acción Principal
                if (request.isApproved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final gameProvider =
                            Provider.of<GameProvider>(context, listen: false);
                        final playerProvider =
                            Provider.of<PlayerProvider>(context, listen: false);

                        if (widget.eventId != null) {
                          if (playerProvider.currentPlayer?.avatarId == null ||
                              playerProvider.currentPlayer!.avatarId!.isEmpty) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => AvatarSelectionScreen(
                                      eventId: widget.eventId!)),
                            );
                            return;
                          }
                          await gameProvider.startGame(widget.eventId!);
                        }

                        if (!context.mounted) return;

                        Navigator.of(context).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) =>
                                  HomeScreen(eventId: widget.eventId!)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'ENTRAR AL JUEGO',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 40),
                    ),
                    child: Text(
                      'Entendido',
                      style: TextStyle(
                        color: isDarkMode ? currentOrange : AppTheme.lBrandMain,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;

    final isDarkMode = playerProvider.isDarkMode;

    // Paleta del Login
    final Color currentSurface0 =
        isDarkMode ? AppTheme.dSurface0 : AppTheme.lSurface0;
    final Color currentBrandDeep =
        isDarkMode ? AppTheme.dBrandDeep : AppTheme.lBrandSurface;
    final Color currentText =
        isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec =
        isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
    final Color currentCard =
        isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentBrand =
        isDarkMode ? AppTheme.dBrandMain : AppTheme.lBrandMain;
    final Color currentAccent =
        isDarkMode ? AppTheme.dGoldMain : AppTheme.lBrandMain;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 80,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ScenariosScreen()),
                );
              },
              child: Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
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
                      color: AppTheme.accentGold.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image (Legacy Style from Login)
          Positioned.fill(
            child: isDarkMode
                ? Opacity(
                    opacity: 0.7,
                    child: Image.asset(
                      'assets/images/hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  )
                : Stack(
                    children: [
                      Image.asset(
                        'assets/images/loginclaro.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _isLoading
                    ? const Center(child: LoadingIndicator())
                    : Column(
                        children: [
                          // Main Content Area
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24.0),
                              child: _gameRequest != null &&
                                      _gameRequest!.isApproved
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Center(
                                          child: LoadingIndicator(
                                              fontSize: 16,
                                              color: Colors.greenAccent),
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          "¡SOLICITUD APROBADA!",
                                          style: TextStyle(
                                            fontFamily: 'Orbitron',
                                            color: Colors.greenAccent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Entrando al evento...",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Container(
                                          width: 85,
                                          height: 85,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(42.5),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.35),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.2),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Builder(
                                                  builder: (context) {
                                                    final avatarId = player?.avatarId;
                                                    if (avatarId != null && avatarId.isNotEmpty) {
                                                      return Image.asset(
                                                        'assets/images/avatars/$avatarId.png',
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => const Icon(
                                                            Icons.person,
                                                            size: 55,
                                                            color: Colors.white),
                                                      );
                                                    }
                                                    if (player?.avatarUrl != null && player!.avatarUrl!.startsWith('http')) {
                                                      return Image.network(
                                                        player.avatarUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => const Icon(
                                                            Icons.person,
                                                            size: 55,
                                                            color: Colors.white),
                                                      );
                                                    }
                                                    return const Icon(Icons.person, size: 55, color: Colors.white);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Welcome Message
                                        Text(
                                          '¡Bienvenido ${player?.name ?? "Jugador"}!',
                                          style: Theme.of(context)
                                              .textTheme
                                              .displaySmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),

                                        // --- COUNTDOWN WIDGET ---
                                        if (_timeUntilStart != null)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: currentAccent
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(19),
                                              border: Border.all(
                                                  color: currentAccent
                                                      .withOpacity(0.35),
                                                  width: 1),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                    sigmaX: 10, sigmaY: 10),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF0D0D0F)
                                                            .withOpacity(0.6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    border: Border.all(
                                                        color: currentAccent,
                                                        width: 1.5),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                          "LA COMPETENCIA INICIA EN:",
                                                          style: TextStyle(
                                                              color:
                                                                  currentAccent,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              letterSpacing:
                                                                  1.2,
                                                              fontSize: 12)),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "${_timeUntilStart!.inDays}d ${_timeUntilStart!.inHours % 24}h ${_timeUntilStart!.inMinutes % 60}m ${_timeUntilStart!.inSeconds % 60}s",
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 22,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontFeatures: [
                                                              FontFeature
                                                                  .tabularFigures()
                                                            ]),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (_eventStarted)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00F0FF)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(19),
                                              border: Border.all(
                                                  color: const Color(0xFF00F0FF)
                                                      .withOpacity(0.35),
                                                  width: 1),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                    sigmaX: 10, sigmaY: 10),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF0D0D0F)
                                                            .withOpacity(0.6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFF00F0FF),
                                                        width: 1.5),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .play_circle_fill,
                                                          color:
                                                              Color(0xFF00F0FF),
                                                          size: 30),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                          "¡COMPETENCIA EN CURSO!",
                                                          style: TextStyle(
                                                              color: Color(
                                                                  0xFF00F0FF),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontFamily:
                                                                  'Orbitron',
                                                              letterSpacing:
                                                                  0.5,
                                                              fontSize: 15)),
                                                      const Text(
                                                          "¡Corre a buscar las pistas!",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Info Card
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF9D4EDD)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(19),
                                            border: Border.all(
                                                color: const Color(0xFF9D4EDD)
                                                    .withOpacity(0.35),
                                                width: 1),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 16),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0D0D0F)
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF9D4EDD),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Icon(
                                                        Icons.info_outline,
                                                        color:
                                                            Color(0xFFC77DFF),
                                                        size: 32),
                                                    const SizedBox(height: 10),
                                                    if (_participantCount >=
                                                        _maxParticipants) ...[
                                                      const Text(
                                                          '¡EVENTO LLENO!',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .redAccent,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 18,
                                                              letterSpacing:
                                                                  1.0)),
                                                      Text(
                                                          'Participantes: $_participantCount / $_maxParticipants',
                                                          style: TextStyle(
                                                              color:
                                                                  currentTextSec,
                                                              fontSize: 14)),
                                                    ] else ...[
                                                      const Text(
                                                        '¿Te gustaría participar?',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                            fontSize: 16),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Envía tu solicitud para que el administrador la revise.',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.3),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Participantes: $_participantCount / $_maxParticipants',
                                                        style: TextStyle(
                                                            color:
                                                                currentAccent,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Request Status
                                        if (_gameRequest != null &&
                                            !_gameRequest!.isApproved)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9800)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(19),
                                              border: Border.all(
                                                  color: const Color(0xFFFF9800)
                                                      .withOpacity(0.35),
                                                  width: 1),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                    sigmaX: 10, sigmaY: 10),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF0D0D0F)
                                                            .withOpacity(0.6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            15),
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFFFF9800),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .access_time_filled_rounded,
                                                          color:
                                                              Color(0xFFFF9800),
                                                          size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Estado: ',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 14)),
                                                      Text('Pendiente',
                                                          style: TextStyle(
                                                              color: Color(
                                                                  0xFFFF9800),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                            ),
                          ),

                          // Bottom Action Section
                          if (_gameRequest == null ||
                              (!_gameRequest!.isApproved))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_gameRequest == null)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDarkMode
                                                ? [
                                                    const Color(0xFFFFF176),
                                                    const Color(0xFFFECB00)
                                                  ]
                                                : [
                                                    const Color(0xFF9D4EDD),
                                                    const Color(0xFF5A189A)
                                                  ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isDarkMode
                                                      ? const Color(0xFFFECB00)
                                                      : const Color(0xFF5A189A))
                                                  .withOpacity(0.4),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isSubmitting
                                              ? null
                                              : _handleRequestJoin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isSubmitting
                                              ? const LoadingIndicator(
                                                  fontSize: 12,
                                                  showMessage: false)
                                              : const Text(
                                                  'ENVIAR SOLICITUD',
                                                  style: TextStyle(
                                                      fontFamily: 'Orbitron',
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: 1.5,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black26,
                                                          offset: Offset(0, 2),
                                                          blurRadius: 4,
                                                        )
                                                      ]),
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
                                          backgroundColor:
                                              const Color(0xFF0D0D0F)
                                                  .withOpacity(0.5),
                                          side: const BorderSide(
                                            color: Color(0xFFFF9800),
                                            width: 2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'VER ESTADO DE SOLICITUD',
                                          style: TextStyle(
                                            fontFamily: 'Orbitron',
                                            color: Color(0xFFFF9800),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Debug Mode Button
                                  if (kDebugMode &&
                                      _gameRequest != null &&
                                      !_gameRequest!.isApproved)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                          side: const BorderSide(
                                              color: Colors.orange),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                                builder: (_) => HomeScreen(
                                                    eventId: widget.eventId!)),
                                          );
                                        },
                                        icon: const Icon(Icons.bug_report,
                                            size: 18),
                                        label: const Text(
                                            "DEBUG: Simular Aprobación",
                                            style: TextStyle(fontSize: 12)),
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
    );
  }
}
