import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/screens/clues_screen.dart';
import '../../game/screens/event_waiting_screen.dart';
import '../../game/providers/event_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../social/screens/inventory_screen.dart';
import '../../social/screens/leaderboard_screen.dart';
import '../../social/screens/profile_screen.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../game/providers/power_effect_provider.dart';

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
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final effectProvider = Provider.of<PowerEffectProvider>(context, listen: false);
      playerProvider.syncRealInventory(effectProvider: effectProvider);
      
      // Sincronizar contexto del evento actual
      playerProvider.setCurrentEventContext(widget.eventId);

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
    _screens = [
      CluesScreen(
        eventId: widget.eventId,
      ),
      InventoryScreen(eventId: widget.eventId),
      const LeaderboardScreen(),
    ];
  }

  // Cache provider to avoid context usage in dispose
  late GameProvider _gameProviderRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardamos la referencia segura mientras el widget está activo
    _gameProviderRef = Provider.of<GameProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // Usamos la referencia guardada, no el context
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _gameProviderRef.resetState();
        debugPrint("HomeScreen disposed: Game Set Reset (Safe)");
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;
    final eventProvider = Provider.of<EventProvider>(context);

    try {
      final event = eventProvider.events.firstWhere((e) => e.id == widget.eventId);
      final now = DateTime.now();
      
      if (event.date.toLocal().isAfter(now) && !_forceGameStart) {
        return EventWaitingScreen(
          event: event,
          onTimerFinished: () {
            setState(() {
               _forceGameStart = true;
            });
          },
        );
      }
    } catch (_) {
      // Fallback
    }
    
    return SabotageOverlay(
      child: Scaffold(
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
                if (player == null || (!player.isFrozen && !player.isBlinded)) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppTheme.cardBg,
              selectedItemColor: AppTheme.secondaryPink,
              unselectedItemColor: Colors.white54,
              showUnselectedLabels: true,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  activeIcon: Icon(Icons.map, size: 28),
                  label: 'Pistas',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2, size: 28),
                  label: 'Inventario',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.leaderboard_outlined),
                  activeIcon: Icon(Icons.leaderboard, size: 28),
                  label: 'Ranking',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
