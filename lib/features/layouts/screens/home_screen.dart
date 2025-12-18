import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/screens/clues_screen.dart';
import '../../game/screens/event_waiting_screen.dart';
import '../../game/providers/event_provider.dart';
import '../../social/screens/inventory_screen.dart';
import '../../social/screens/leaderboard_screen.dart';
import '../../social/screens/profile_screen.dart';
import '../../../shared/widgets/sabotage_overlay.dart';

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
    _screens = [
      CluesScreen(
        eventId: widget.eventId,
      ),
      InventoryScreen(eventId: widget.eventId),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];
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
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person, size: 28),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
