import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/screens/clues_screen.dart';
import '../../game/screens/event_waiting_screen.dart';
import '../../game/providers/event_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../game/providers/spectator_feed_provider.dart'; // NEW
import '../../game/screens/live_feed_screen.dart'; // NEW
import '../../social/screens/inventory_screen.dart';
import '../../social/screens/leaderboard_screen.dart';
import '../../social/screens/profile_screen.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../game/providers/power_interfaces.dart';
import '../../game/screens/spectator_mode_screen.dart'; // ADDED
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final String eventId;

  const HomeScreen({super.key, required this.eventId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late List<Widget> _screens;

  // Debug logic
  bool _forceGameStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final effectProvider =
          Provider.of<PowerEffectManager>(context, listen: false);

      // Spectators don't need inventory sync
      if (playerProvider.currentPlayer?.role != 'spectator') {
        playerProvider.syncRealInventory(effectProvider: effectProvider);
      }

      // Sincronizar contexto del evento actual
      playerProvider.setCurrentEventContext(widget.eventId);

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });

    final player =
        Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    final isSpectator = player?.role == 'spectator';

    if (isSpectator) {
      // REDIRECCIÓN: Si es espectador, no debe estar en HomeScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SpectatorModeScreen(eventId: widget.eventId),
            ),
          );
        }
      });
      // Placeholder mientras redirige
      _screens = [
        const Scaffold(body: Center(child: LoadingIndicator()))
      ];
    } else {
      _screens = [
        CluesScreen(eventId: widget.eventId),
        InventoryScreen(eventId: widget.eventId),
        const LeaderboardScreen(),
      ];
    }
  }

  // Cache provider to avoid context usage in dispose
  late GameProvider _gameProviderRef;
  late PlayerProvider _playerProviderRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardamos la referencia segura mientras el widget está activo
    _gameProviderRef = Provider.of<GameProvider>(context, listen: false);
    _playerProviderRef = Provider.of<PlayerProvider>(context, listen: false);
  }

  bool _isTutorialShowing = false;

  void _checkAndShowTutorial({bool force = false}) async {
    if (_isTutorialShowing) return;
    
    String section;
    switch (_currentIndex) {
      case 0: section = 'CLUES'; break;
      case 1: section = 'INVENTORY'; break;
      case 2: section = 'RANKING'; break;
      default: return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String tutorialKey = 'has_seen_tutorial_$section';
    final hasSeen = prefs.getBool(tutorialKey) ?? false;

    if (!force && hasSeen) return;
    
    final steps = MasterTutorialContent.getStepsForSection(section, context);
    if (steps.isEmpty) return;

    _isTutorialShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CyberTutorialOverlay(
          steps: steps,
          onFinish: () {
            Navigator.pop(context);
            _isTutorialShowing = false;
            prefs.setBool(tutorialKey, true); // Mark as seen
          },
        ),
      );
    });
  }

  // Removed _showWelcomeTutorial as it is no longer required in Home/Mode selection
  
  @override
  void dispose() {
    // Usamos la referencia guardada, no el context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProviderRef.resetState();
      _playerProviderRef
          .clearGameContext(); // ⚡ CRITICAL: Stops SabotageOverlay
      debugPrint(
          "HomeScreen disposed: Game Set Reset & Player Context Cleared");
    });
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // REMOVED: Conflicts with Logout transition
    super.dispose();
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentGold),
            SizedBox(width: 10),
            Text("Salir del Evento", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "¿Estás seguro de que deseas salir del evento actual? Tu progreso se guardará, pero dejarás la carrera momentáneamente.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Exit HomeScreen (back to selector)
            },
            child: const Text("SALIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;
    final eventProvider = Provider.of<EventProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    try {
      final event =
          eventProvider.events.firstWhere((e) => e.id == widget.eventId);
      final now = DateTime.now();

      if (event.date.toLocal().isAfter(now) && !_forceGameStart) {
        return EventWaitingScreen(
          event: event,
          onTimerFinished: () {
            // 1. Update DB status to 'active' if it's currently 'pending'
            if (event.status == 'pending') {
               debugPrint("⏳ Timer finished! Updating event ${event.id} status to active.");
               eventProvider.updateEventStatus(event.id, 'active');
            }
            
            // 2. Local state update to force re-render
            setState(() {
              _forceGameStart = true;
            });
          },
        );
      }
    } catch (_) {
      // Fallback
    }

    final isSpectator = player?.role == 'spectator';
    
    // Trigger tutorial for the current section
    if (!isSpectator) {
      _checkAndShowTutorial();
    }

    Widget content = Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              // Calculate index of the "Exit" item
              final exitIndex = isSpectator ? 4 : 3;
              
              if (index == exitIndex) {
                 _showExitDialog();
                 return;
              }

              if (player == null || (!player.isFrozen && !player.isBlinded)) {
                setState(() {
                  _currentIndex = index;
                });
                // When tab changes, we might want to show tutorial again if it's the first time for that tab
                _checkAndShowTutorial(force: false);
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1,
            selectedItemColor: AppTheme.secondaryPink,
            unselectedItemColor: isDarkMode ? Colors.white54 : Colors.black45,
            showUnselectedLabels: true,
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.map),
                activeIcon: Icon(Icons.map, size: 28),
                label: 'Pistas',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                    isSpectator ? Icons.rss_feed : Icons.inventory_2_outlined),
                activeIcon: Icon(
                    isSpectator ? Icons.rss_feed : Icons.inventory_2,
                    size: 28),
                label: isSpectator ? 'En Vivo' : 'Inventario',
              ),
              if (isSpectator)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.flash_on),
                  activeIcon: Icon(Icons.flash_on, size: 28),
                  label: 'Sabotajes',
                ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                activeIcon: Icon(Icons.leaderboard, size: 28),
                label: 'Ranking',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.sensor_door_outlined),
                activeIcon: Icon(Icons.sensor_door, color: AppTheme.dangerRed),
                label: 'Salir',
              ),
            ],
          ),
        ),
      ),
    );

    if (isSpectator) {
      content = ChangeNotifierProvider(
        create: (_) => SpectatorFeedProvider(widget.eventId),
        child: content,
      );
    }

    return SabotageOverlay(
      child: content,
    );
  }
}
