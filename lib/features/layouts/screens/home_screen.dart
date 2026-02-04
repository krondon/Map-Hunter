import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
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
  late PlayerProvider _playerProviderRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardamos la referencia segura mientras el widget está activo
    _gameProviderRef = Provider.of<GameProvider>(context, listen: false);
    _playerProviderRef = Provider.of<PlayerProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // Usamos la referencia guardada, no el context
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _gameProviderRef.resetState();
        _playerProviderRef.clearGameContext(); // ⚡ CRITICAL: Stops SabotageOverlay
        debugPrint("HomeScreen disposed: Game Set Reset & Player Context Cleared");
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;
    final eventProvider = Provider.of<EventProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDayMode = themeProvider.isDayMode;

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
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
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
                if (index == 3) {
                  _showExitConfirmation();
                  return;
                }
                if (player == null || (!player.isFrozen && !player.isBlinded)) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: isDayMode ? Colors.white : AppTheme.cardBg,
              selectedItemColor: AppTheme.secondaryPink,
              unselectedItemColor: isDayMode ? Colors.black54 : Colors.white54,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              showUnselectedLabels: true,
              elevation: 0,
              items: [
                _buildNavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: 'Pistas',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  label: 'Inventario',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.leaderboard_outlined,
                  activeIcon: Icons.leaderboard,
                  label: 'Ranking',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.meeting_room_outlined,
                  activeIcon: Icons.meeting_room,
                  label: 'Salir',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    // For the exit button, it's never "selected" in terms of index, but we can color it red for emphasis
    final isExit = index == 3;
    return BottomNavigationBarItem(
      icon: Icon(
        isSelected ? activeIcon : icon,
        color: isExit ? AppTheme.dangerRed.withOpacity(0.8) : null,
      ),
      label: label,
    );
  }

  Future<void> _showExitConfirmation() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDayMode = themeProvider.isDayMode;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDayMode ? Colors.white : AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "¿Salir del Evento?",
          style: TextStyle(
            color: isDayMode ? Colors.black : Colors.white, 
            fontWeight: FontWeight.bold
          ),
        ),
        content: Text(
          "Si sales ahora, podrías perder tu progreso o tu posición en el ranking.",
          style: TextStyle(color: isDayMode ? Colors.black87 : Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCELAR", style: TextStyle(color: isDayMode ? Colors.black54 : Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text("SALIR"),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}
