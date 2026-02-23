import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/spectator_feed_provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_request_provider.dart'; // ADDED
import '../../layouts/screens/home_screen.dart'; // ADDED
import '../../auth/services/power_service.dart';
import '../widgets/race_track_widget.dart';
import '../models/race_view_data.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../mall/models/power_item.dart';
import '../models/event.dart';
import '../providers/power_effect_provider.dart';
import '../../../core/services/effect_timer_service.dart';
import '../repositories/power_repository_impl.dart';
import '../strategies/power_strategy_factory.dart';
import '../../events/services/event_service.dart';
import '../widgets/betting_modal.dart';
import '../../auth/screens/avatar_selection_screen.dart';
import '../widgets/spectator_participants_list.dart';
import '../../../shared/models/player.dart';
import '../../social/widgets/leaderboard_card.dart';
import '../widgets/spectator_betting_pot_widget.dart'; // ADDED
import '../widgets/my_bets_modal.dart';
import '../services/betting_service.dart'; // ADDED
import 'winner_celebration_screen.dart'; // ADDED: Podio redirect
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';


class SpectatorModeScreen extends StatefulWidget {
  final String eventId;

  const SpectatorModeScreen({super.key, required this.eventId});

  @override
  State<SpectatorModeScreen> createState() => _SpectatorModeScreenState();
}

class _SpectatorModeScreenState extends State<SpectatorModeScreen> {
  int _selectedTab = 0; // 0: Actividad, 1: Apuestas, 2: Tienda
  late PowerEffectProvider _powerEffectProvider;
  late Stream<GameEvent> _eventStream;
  bool _hasNavigatedToPodium = false; // Prevent double-navigation when event completes

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    _powerEffectProvider = PowerEffectProvider(
      repository: PowerRepositoryImpl(supabaseClient: supabase),
      timerService: EffectTimerService(),
      strategyFactory: PowerStrategyFactory(supabase),
    );
    
    _eventStream = EventService(supabase).getEventStream(widget.eventId);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final requestProvider =
          Provider.of<GameRequestProvider>(context, listen: false);

      // --- SECURITY CHECK: Redirect Active Players ---
      final userId = playerProvider.currentPlayer?.userId;
      if (userId != null) {
        final participantData =
            await requestProvider.isPlayerParticipant(userId, widget.eventId);
        final isParticipant = participantData['isParticipant'] as bool;
        final status = participantData['status'] as String?;

        // If user is a player (active/pending) and NOT spectator/banned/suspended
        // They should be in the game, not spectating.
        if (isParticipant &&
            status != 'spectator' &&
            status != 'banned' &&
            status != 'suspended') {
          if (!mounted) return;
          debugPrint(
              '🚫 SpectatorMode: User is active player. Redirecting to HomeScreen...');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Redirigiendo al modo Jugador...'),
            backgroundColor: AppTheme.primaryPurple,
            duration: Duration(seconds: 2),
          ));

          playerProvider.setSpectatorRole(false);
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => HomeScreen(eventId: widget.eventId)));
          return;
        }
      }
      // -----------------------------------------------

      // Activar modo espectador en el provider para usar el flujo de compra correcto
      playerProvider.setSpectatorRole(true);

      // Los espectadores no necesitan inicializar el juego (startGame), solo ver los datos
      gameProvider.fetchClues(eventId: widget.eventId);
      gameProvider.startLeaderboardUpdates();

      // Registrarse como espectador para habilitar compras/sabotajes
      await playerProvider.joinAsSpectator(widget.eventId);

      // Inicializar listener de efectos si el espectador tiene gamePlayerId (ahora debería tenerlo)
      if (playerProvider.currentPlayer?.gamePlayerId != null) {
        _powerEffectProvider
            .startListening(playerProvider.currentPlayer!.gamePlayerId);
      }

      _showSpectatorTutorial();
    });
  }

  void _showSpectatorTutorial({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final hasSeen = prefs.getBool('has_seen_tutorial_SPECTATOR') ?? false;
      if (hasSeen) return;
    }

    final steps = MasterTutorialContent.getStepsForSection('SPECTATOR', context);
    if (steps.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CyberTutorialOverlay(
        steps: steps,
        onFinish: () {
          Navigator.pop(context);
          prefs.setBool('has_seen_tutorial_SPECTATOR', true);
        },
      ),
    );
  }

  void _showExitConfirmation() {
    const Color accentColor = AppTheme.dGoldMain;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: accentColor.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF151517),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor, width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.exit_to_app_rounded,
                          color: accentColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '¿Salir del modo espectador?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.3),
                              accentColor,
                              accentColor.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Perderás la vista en tiempo real de la carrera.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Salir button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE33E5D), Color(0xFFB71C1C)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE33E5D).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                            label: const Text(
                              'SALIR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.of(context).pop(); // Exit spectator
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Cancelar
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.white70.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Restaurar rol de espectador al salir
    // Usamos microtask para asegurar que se ejecute sin erores de contexto
    Future.microtask(() {
      try {
        // Nota: Esto asume que el provider sigue vivo.
        // Si se desmonta todo el árbol, el provider se limpia solo.
        // Pero es buena práctica intentar limpiar el flag.
        // Sin embargo, acceder a context en dispose es riesgoso.
        // Lo dejamos así, ya que al logout o cambiar de pantalla el provider debería resetearse o no importar.
        // Pero para seguridad, si Provider está arriba, lo intentamos.
      } catch (_) {}
    });

    _powerEffectProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read actual mode for background images only
    final playerProvider = Provider.of<PlayerProvider>(context);
    final actualDarkMode = playerProvider.isDarkMode;
    // FORCED DARK: All UI elements always use dark cyberpunk styling
    final isDarkMode = true;

    return ChangeNotifierProvider(
      create: (_) => SpectatorFeedProvider(widget.eventId),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        body: Stack(
          children: [
            // Background image based on day/night mode
            Positioned.fill(
              child: Image.asset(
                actualDarkMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // Semi-transparent overlay to ensure legibility of content
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            StreamBuilder<GameEvent>(
              stream: _eventStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.secondaryPink));
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white)));
                }

                if (!snapshot.hasData) {
                  return const Center(
                      child: Text('Evento no encontrado',
                          style: TextStyle(color: Colors.white)));
                }

                final event = snapshot.data!;

                // --- REALTIME REDIRECT: When event completes → go to Podio ---
                if (event.isCompleted && !_hasNavigatedToPodium) {
                  _hasNavigatedToPodium = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    debugPrint(
                        '🏆 SpectatorMode: Event completed. Redirecting to Podio...');
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => WinnerCelebrationScreen(
                          eventId: widget.eventId,
                          playerPosition: 0,
                          totalCluesCompleted: 0,
                          prizeWon: 0,
                        ),
                      ),
                    );
                  });
                  return const Scaffold(
                    backgroundColor: Colors.transparent, // Background visible during redirect
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFFFD700)),
                          SizedBox(height: 20),
                          Text(
                            '🏆 Redirigiendo al podio...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // -------------------------------------------------------

                return SafeArea(
                  child: Column(
                    children: [
                      // 1. Header Row with Back Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            CyberRingButton(
                              size: 40,
                              icon: Icons.arrow_back,
                              onPressed: () => _showExitConfirmation(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                event.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Orbitron',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Body Condicional
                      Expanded(
                        child: Column(
                          children: [
                            // Banner de Victoria (Solo si terminó)
                            if (event.isCompleted) _buildVictoryBanner(),

                            // B. POTE DE APUESTAS (NUEVO)
                            SpectatorBettingPotWidget(eventId: widget.eventId),

                            // RESULTADOS DE APUESTAS (Solo si terminó)
                            if (event.isCompleted)
                              _buildUserWinningsSection(event.id),

                            // C. Carrera en Curso / Finalizada (Race Tracker siempre visible)
                            SizedBox(
                              height: 300,
                              child: Stack(
                                children: [
                                  _buildRaceView(),
                                  Positioned(
                                    top: 38,
                                    right: 25,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.help_outline_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          _showSpectatorTutorial(force: true),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // C. Tabs Section (Siempre visible, pero adaptada)
                            // Si es pending, quizás queramos ver menos cosas, pero mantendremos consistencia
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg.withOpacity(0.9),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(30),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, -5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // El tab de inventario ahora es una pequeña franja superior si estamos en Actividad
                                    if (_selectedTab == 0)
                                      _buildMiniInventoryHeader(),

                                    // Tabs selector principal
                                    _buildTabSelector(),

                                    // Contenido del tab
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: _selectedTab == 2
                                            ? _buildStoreView()
                                            : _selectedTab == 1
                                                ? _rankingView(event)
                                                : _buildLiveFeed(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  void _confirmExit() {
    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentRed.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentRed.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentRed, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentRed.withOpacity(0.1),
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
                    border: Border.all(color: currentRed, width: 2),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: currentRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Salir del Modo Espectador?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Si tienes apuestas activas, seguirán vigentes. '
                  'Podrás volver a entrar en cualquier momento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentRed,
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
    ).then((shouldExit) {
      if (shouldExit == true && mounted) {
        Navigator.pop(context);
      }
    });
  }

  Widget _buildVictoryBanner() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        if (!gameProvider.isRaceCompleted) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                '¡JUEGO FINALIZADO!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.emoji_events, color: Colors.white, size: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRaceView() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final playerProvider =
            Provider.of<PlayerProvider>(context, listen: false);

        if (gameProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.accentGold),
                SizedBox(height: 16),
                Text(
                  'Cargando...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final leaderboard = gameProvider.leaderboard;
        final totalClues = gameProvider.totalClues;
        final currentPlayerId = playerProvider.currentPlayer?.userId ?? '';

        if (leaderboard.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 60,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Esperando que comience la carrera...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: RaceTrackWidget(
            leaderboard: leaderboard,
            currentPlayerId: currentPlayerId,
            totalClues: totalClues,
            compact:
                false, // Usamos la versión completa que ya tiene estilo premium
          ),
        );
      },
    );
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.secondaryPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.2)),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.5), width: 1.5),
            ),
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryPink.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.visibility, color: AppTheme.secondaryPink, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MODO ESPECTADOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildTutorialSection(
                    '👁️ ¿Qué es el Modo Espectador?',
                    'Observa la carrera en tiempo real sin participar. '
                    'Podrás ver el progreso de cada jugador, las pistas resueltas '
                    'y los eventos que ocurren durante el juego.',
                  ),
                  const SizedBox(height: 16),

                  _buildTutorialSection(
                    '⚡ Poderes y Sabotajes',
                    'Compra poderes en la Tienda usando tréboles. '
                    'Usa tus poderes para sabotear jugadores (congelar, difuminar, etc.) '
                    'o enviar ayuda (escudos, invisibilidad). '
                    'Toca un poder de tu inventario para usarlo.',
                  ),
                  const SizedBox(height: 16),

                  _buildTutorialSection(
                    '🎰 Apuestas',
                    'Apuesta 100 tréboles por el jugador que crees que ganará la carrera. '
                    'Si tu jugador gana, ¡recibirás el doble de tu apuesta! '
                    'Las apuestas se realizan con tréboles (moneda premium).',
                  ),
                  const SizedBox(height: 16),

                  _buildTutorialSection(
                    '🍀 Tréboles',
                    'Los tréboles son la moneda del juego. '
                    'Puedes recargarlos desde la Wallet. '
                    'Úsalos para comprar poderes y apostar.',
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'ENTENDIDO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.0,
                        ),
                      ),
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

  Widget _buildTutorialSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.secondaryPink,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              icon: Icons.notifications_active,
              label: 'Actividad',
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildTab(
              icon: Icons.list_alt,
              label: 'Ranking',
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
          Expanded(
            child: _buildTab(
              icon: Icons.shopping_bag,
              label: 'Tienda',
              isSelected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppTheme.secondaryPink, Color(0xFF9B1E8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInventoryHeader() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final inventoryList = playerProvider.currentPlayer?.inventory ?? [];
        if (inventoryList.isEmpty) return const SizedBox.shrink();

        // Contar items para mostrar cantidades
        final inventoryMap = <String, int>{};
        for (var slug in inventoryList) {
          inventoryMap[slug] = (inventoryMap[slug] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 20, top: 10),
              child: Text(
                'MIS PODERES (Toca para usar)',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: inventoryMap.length,
                itemBuilder: (context, index) {
                  final entry = inventoryMap.entries.elementAt(index);
                  // Asegurarse de que el key es un String
                  final String powerSlug = entry.key;
                  final int count = entry.value;

                  return GestureDetector(
                    onTap: () => _showSabotageDialog(powerSlug, count),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryPink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.secondaryPink.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryPink.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getPowerIcon(powerSlug),
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getPowerName(powerSlug),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'x$count',
                                style: const TextStyle(
                                  color: AppTheme.accentGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSabotageDialog(String powerSlug, int count) {
    final isDefense = ['shield', 'return', 'invisibility'].contains(powerSlug);
    
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            final activePowers = gameProvider.activePowerEffects;
            final players = gameProvider.leaderboard
                .where((p) {
                   if (p.gamePlayerId == null || p.gamePlayerId!.isEmpty) return false;
                   
                   // Invisibility Check - Don't show invisible targets for ATTACKS
                   if (!isDefense && p.isInvisible) return false;
                   
                   final isStealthed = activePowers.any((e) {
                      final targetId = e.targetId.trim().toLowerCase();
                      final userId = p.userId.trim().toLowerCase();
                      final gpId = p.gamePlayerId!.trim().toLowerCase();
                      
                      final isMatch = (targetId == userId || targetId == gpId);
                      return isMatch && (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') && !e.isExpired;
                   });
                   
                   // If attacking, respect invisibility
                   if (!isDefense && isStealthed) return false;
                   
                   return true;
                })
                .toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDefense 
                        ? [const Color(0xFF1A3A1F), const Color(0xFF0A270E)] // Green for Support
                        : [const Color(0xFF1A1F3A), const Color(0xFF0A0E27)], // Blue/Dark for Attack
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDefense ? Colors.greenAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5), 
                    width: 2
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getPowerIcon(powerSlug),
                      style: const TextStyle(fontSize: 50),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDefense ? 'ENVIAR AYUDA' : 'SABOTEAR JUGADOR',
                      style: TextStyle(
                        color: isDefense ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDefense 
                          ? 'Elige un aliado para enviar ${_getPowerName(powerSlug)}'
                          : 'Elige una víctima para ${_getPowerName(powerSlug)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      child: players.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay jugadores disponibles',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: players.length,
                              itemBuilder: (context, index) {
                                final player = players[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Colors.redAccent.withOpacity(0.2),
                                      backgroundImage:
                                          player.avatarUrl.isNotEmpty
                                              ? NetworkImage(player.avatarUrl)
                                              : null,
                                      child: player.avatarUrl.isEmpty
                                          ? Text(player.name[0].toUpperCase(),
                                              style: const TextStyle(
                                                  color: Colors.white))
                                          : null,
                                    ),
                                    title: Text(
                                      player.name,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.flash_on,
                                          color: Colors.redAccent),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _usePower(powerSlug,
                                            player.gamePlayerId!, player.name);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _usePower(
      String powerSlug, String targetId, String targetName) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    try {
      final result = await playerProvider.usePower(
        powerSlug: powerSlug,
        targetGamePlayerId: targetId,
        effectProvider: _powerEffectProvider,
        gameProvider: Provider.of<GameProvider>(context, listen: false),
      );

      if (mounted) {
        if (result == PowerUseResult.gifted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎁 ¡Regalo enviado a $targetName!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (result == PowerUseResult.blocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛡️ ¡Ataque bloqueado por escudo!'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (result == PowerUseResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Has saboteado a $targetName con ${_getPowerName(powerSlug)}!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (result == PowerUseResult.reflected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡El ataque a $targetName fue reflejado!'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al usar el poder'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLiveFeed() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVIDAD EN VIVO',
            style: TextStyle(
              color: AppTheme.accentGold,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<SpectatorFeedProvider>(
              builder: (context, provider, child) {
                if (provider.events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 40,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esperando actividad...',
                          style: TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: provider.events.length,
                  itemBuilder: (context, index) {
                    final event = provider.events[index];
                    return _buildFeedEventCard(event);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedEventCard(GameFeedEvent event) {
    final color = _getEventColor(event.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                event.icon ?? '⚡',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.action,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm:ss').format(event.timestamp),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.detail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingView(GameEvent event) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final leaderboard = gameProvider.leaderboard;

        // --- INVISIBILITY FILTER LOGIC ---
        final activePowers = gameProvider.activePowerEffects;
        final playerProvider =
            Provider.of<PlayerProvider>(context, listen: false);
        final currentUserId = playerProvider.currentPlayer?.userId ?? '';

        bool isVisible(Player p) {
          if (p.userId == currentUserId) return true;
          final isStealthed = activePowers.any((e) {
            final target = e.targetId.trim().toLowerCase();
            final pid = p.id.trim().toLowerCase();
            final pgid = (p.gamePlayerId ?? '').trim().toLowerCase();
            final isMatch = (target == pid || target == pgid);
            return isMatch &&
                (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') &&
                !e.isExpired;
          });
          if (isStealthed) return false;
          if (p.isInvisible) return false;
          return true;
        }

        final displayLeaderboard = leaderboard.where(isVisible).toList();
        // ---------------------------------

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Header & Podium (Scrollable)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Header Row
                    // Header Row with Wrap to prevent horizontal overflow
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.leaderboard,
                                color: AppTheme.accentGold, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'RANKING',
                              style: TextStyle(
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (event.status == 'pending')
                              ElevatedButton(
                                onPressed: () => _showBetDialog(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text('Apostar', style: TextStyle(fontSize: 11)),
                              )
                            else
                               Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    event.status == 'active' ? 'En Curso' : 'Finalizado',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                               ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: () => _showMyBetsDialog(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentGold,
                                side: const BorderSide(color: AppTheme.accentGold),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text('Mis Apuestas', style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            Consumer<PlayerProvider>(
                              builder: (context, playerProvider, child) {
                                final clovers =
                                    playerProvider.currentPlayer?.clovers ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🍀',
                                          style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$clovers',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Podium Section (Only if 3+ players)
                    if (displayLeaderboard.length >= 3) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildPodiumPosition(
                                  displayLeaderboard[1],
                                  2,
                                  90,
                                  const Color(0xFFC0C0C0),
                                ),
                              ),
                              Expanded(
                                child: _buildPodiumPosition(
                                  displayLeaderboard[0],
                                  1,
                                  120,
                                  AppTheme.accentGold,
                                ),
                              ),
                              Expanded(
                                child: _buildPodiumPosition(
                                  displayLeaderboard[2],
                                  3,
                                  70,
                                  const Color(0xFFCD7F32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. List of Players (or Empty State)
              if (displayLeaderboard.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No hay jugadores activos',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final player = displayLeaderboard[index];
                      return LeaderboardCard(
                        player: player,
                        rank: index + 1,
                        isTopThree: index < 3,
                      );
                    },
                    childCount: displayLeaderboard.length,
                  ),
                ),
                
              // Extra padding at bottom for navigation bar
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        );
      },
    );
  }

  void _showBetDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BettingModal(
        eventId: widget.eventId,
      ),
    );
  }

  void _showMyBetsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MyBetsModal(eventId: widget.eventId),
    );
  }



  Widget _buildUserWinningsSection(String eventId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserWinnings(eventId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!;
        final won = data['won'] as bool;
        final amount = data['amount'] as int;

        if (amount == 0 && !won) return const SizedBox(); // No bets or lost without specific message? Or show lost?

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: won ? AppTheme.dGoldMain.withOpacity(0.2) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: won ? AppTheme.dGoldMain : Colors.red.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Text(
                won ? "¡FELICIDADES!" : "Resultados",
                style: TextStyle(
                  color: won ? AppTheme.dGoldMain : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 8),
              if (won)
                Text(
                  "Has ganado $amount 🍀",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  "No obtuviste premios en este evento.",
                  style: TextStyle(color: Colors.white70),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getUserWinnings(String eventId) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.userId;
    if (userId == null) return {'won': false, 'amount': 0};
    final bettingService = BettingService(Supabase.instance.client);
    return bettingService.getUserEventWinnings(eventId, userId);
  }

  Widget _buildStoreView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag,
                  color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'TIENDA DE PODERES',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Consumer<PlayerProvider>(
                builder: (context, playerProvider, child) {
                  final clovers = playerProvider.currentPlayer?.clovers ?? 0;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.secondaryPink, Color(0xFF9B1E8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('🍀', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '$clovers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<PlayerProvider>(
              builder: (context, playerProvider, child) {
                final powers = playerProvider.shopItems.where((p) => p.id != 'extra_life').toList();
                
                if (powers.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay poderes disponibles',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: powers.length,
                  itemBuilder: (context, index) {
                    final power = powers[index];
                    return _buildPowerCard(power);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerCard(PowerItem power) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.secondaryPink.withOpacity(0.2),
            const Color(0xFF0D0D14).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPurchaseDialog(power),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  power.icon,
                  style: const TextStyle(fontSize: 40),
                ),
                Text(
                  power.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  power.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGold),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🍀', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${power.cost}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
    );
  }

  void _showPurchaseDialog(PowerItem power) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentClovers = playerProvider.currentPlayer?.clovers ?? 0;
    final canAfford = currentClovers >= power.cost;

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
                color: AppTheme.accentGold.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                power.icon,
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Comprar ${power.name}?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🍀', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    '${power.cost} tréboles',
                    style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Saldo actual del usuario
              Text(
                'Tu saldo: $currentClovers 🍀',
                style: TextStyle(
                  color: canAfford ? Colors.white54 : Colors.redAccent,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              // Advertencia de moneda paga
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Los tréboles son moneda premium',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!canAfford)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Tréboles insuficientes. Recarga en la tienda.',
                    style: TextStyle(
                        color: Colors.redAccent.shade100, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canAfford
                          ? () async {
                              Navigator.pop(context);
                              await _purchasePower(
                                  power.id, power.name, power.cost);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canAfford ? AppTheme.accentGold : Colors.grey,
                        disabledBackgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        canAfford ? 'Confirmar Compra' : 'Sin Saldo',
                        style: TextStyle(
                          color: canAfford ? Colors.black : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchasePower(
      String powerId, String powerName, int price) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentClovers = playerProvider.currentPlayer?.clovers ?? 0;

    if (currentClovers < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No tienes tréboles suficientes. Recarga en la tienda.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final success = await playerProvider.purchaseItem(
        powerId,
        widget.eventId,
        price,
        isPower: true,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🍀 ', style: TextStyle(fontSize: 16)),
                Text('¡$powerName comprado con $price tréboles!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        throw 'La transacción no pudo completarse';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al comprar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getEventColor(String? type) {
    switch (type) {
      case 'power':
        return Colors.amber;
      case 'clue':
        return Colors.greenAccent;
      case 'life':
        return Colors.redAccent;
      case 'join':
        return Colors.blueAccent;
      case 'shop':
        return Colors.orangeAccent;
      default:
        return Colors.white;
    }
  }

  String _getPowerIcon(String slug) {
    switch (slug) {
      case 'freeze':
        return '❄️';
      case 'shield':
        return '🛡️';
      case 'invisibility':
        return '👻';
      case 'life_steal':
        return '🧛';
      case 'blur_screen':
        return '🌫️';
      case 'return':
        return '🔄';
      case 'black_screen':
        return '🕶️';
      default:
        return '⚡';
    }
  }

  String _getPowerName(String slug) {
    switch (slug) {
      case 'freeze':
        return 'Congelar';
      case 'shield':
        return 'Escudo';
      case 'invisibility':
        return 'Invisible';
      case 'life_steal':
        return 'Robar Vida';
      case 'blur_screen':
        return 'Difuminar';
      case 'return':
        return 'Retornar';
      case 'black_screen':
        return 'Pantalla Negra';
      case 'extra_life':
        return 'Vida Extra';
      default:
        return slug;
    }
  }
  Widget _buildPodiumPosition(Player player, int position, double barHeight, Color color) {
    String? avatarId = player.avatarId;
    final String avatarUrl = player.avatarUrl;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar with Laurel Wreath
        SizedBox(
          width: 82,
          height: 82,
          child: CustomPaint(
            painter: _LaurelWreathPainter(color: color),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: color, width: 2.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Builder(
                    builder: (context) {
                      if (avatarId != null && avatarId.isNotEmpty) {
                        return Image.asset(
                          'assets/images/avatars/$avatarId.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white70, size: 22),
                        );
                      }
                      if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                        return Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person,
                              color: Colors.white70, size: 22),
                        );
                      }
                      return const Icon(Icons.person, color: Colors.white70, size: 22);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Name
        SizedBox(
          width: 80,
          child: Text(
            player.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),

        // Pedestal bar with position number at the bottom
        Container(
          width: double.infinity,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.45),
                color.withOpacity(0.12),
              ],
            ),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color.withOpacity(0.3), width: 0.5),
              right: BorderSide(color: color.withOpacity(0.3), width: 0.5),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 0.8,
                  color: color.withOpacity(0.7),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws a laurel wreath around the avatar matching the reference design
class _LaurelWreathPainter extends CustomPainter {
  final Color color;

  _LaurelWreathPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;

    final stemPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final leafPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Draw U-shaped stem arc (open at the top) - brought closer to avatar
    final rect = Rect.fromCircle(center: center, radius: radius * 0.68);
    // Start at ~1:30 o'clock and sweep through the bottom to ~10:30 o'clock
    canvas.drawArc(rect, -4/14 * math.pi, 22/14 * math.pi, false, stemPaint);

    // Draw leaves in a circular "clock" distribution with a gap at the top
    final int totalLeaves = 14; 
    for (int i = 0; i < totalLeaves; i++) {
      // Skip the top 3 positions to leave it open at the top (11, 12, 1 o'clock)
      if (i == 0 || i == 1 || i == totalLeaves - 1) continue;
      
      // Distribute evenly around the circle
      final angle = (2 * math.pi * i / totalLeaves) - math.pi / 2;
      
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: true);
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: false);
    }
  }

  void _drawReferenceLeaf(
      Canvas canvas, Offset center, double radius, double angle, Paint paint,
      {required bool isOuter}) {
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);

    canvas.save();
    canvas.translate(x, y);

    // Point leaf radially with a strong tilt to the right (+0.5 math.radians)
    double rotation = isOuter ? angle + 0.5 : angle + math.pi + 0.5;
    
    canvas.rotate(rotation + math.pi / 2);

    // Make inner leaves slightly smaller for better aesthetics
    final scale = isOuter ? 1.0 : 0.75;
    canvas.scale(scale, scale);

    final path = Path();
    final len = 13.0;
    final width = 5.0;

    // Pointed oval leaf (wider in middle, sharp tip)
    path.moveTo(0, 0);
    path.quadraticBezierTo(width * 1.2, -len * 0.45, 0, -len); // Outer curve
    path.quadraticBezierTo(-width * 1.2, -len * 0.45, 0, 0); // Inner curve
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CyberRingButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const CyberRingButton({
    super.key,
    required this.size,
    required this.icon,
    this.onPressed,
    this.color = const Color(0xFFFECB00),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(
              color: color.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      ),
    );
  }
}
