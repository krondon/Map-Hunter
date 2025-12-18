import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    
    if (player == null) {
      return const Center(child: Text('No player data', style: TextStyle(color: Colors.white)));
    }
    
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('ID DE JUGADOR', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.dangerRed),
            onPressed: () {
              playerProvider.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 1. CARNET DE IDENTIDAD (GAMER CARD)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 5))
                    ]
                  ),
                  child: Column(
                    children: [
                      // Avatar & Level Ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                           // Ring
                           SizedBox(
                             width: 110, height: 110,
                             child: CircularProgressIndicator(
                               value: player.experienceProgress,
                               strokeWidth: 6,
                               backgroundColor: Colors.white10,
                               valueColor: const AlwaysStoppedAnimation(AppTheme.accentGold),
                             ),
                           ),
                           // Avatar
                           Container(
                             width: 90, height: 90,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               gradient: AppTheme.primaryGradient,
                               boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
                             ),
                             child: Icon(_getAvatarIcon(player.profession), size: 50, color: Colors.white),
                           ),
                           // Level Badge
                           Positioned(
                             bottom: 0,
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               decoration: BoxDecoration(
                                 color: AppTheme.accentGold,
                                 borderRadius: BorderRadius.circular(12),
                                 boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black45)]
                               ),
                               child: Text("LVL ${player.level}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                             ),
                           )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text(player.profession.toUpperCase(), style: const TextStyle(color: AppTheme.secondaryPink, fontSize: 14, letterSpacing: 2)),
                      
                      const SizedBox(height: 24),
                      
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCompact(Icons.monetization_on, "${player.coins}", "Monedas", AppTheme.accentGold),
                          _buildContainerDivider(),
                          _buildStatCompact(Icons.star, "${player.totalXP}", "XP Total", AppTheme.secondaryPink),
                          _buildContainerDivider(),
                          _buildStatCompact(Icons.emoji_events, "${player.eventsCompleted?.length ?? 0}", "Eventos", Colors.cyan),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 2. ESTADÍSTICAS DETALLADAS (Attributes)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ATRIBUTOS", style: TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildAttributeRow("Fuerza", player.stats['strength'] ?? 0, Colors.redAccent),
                      _buildAttributeRow("Velocidad", player.stats['speed'] ?? 0, Colors.blueAccent),
                      _buildAttributeRow("Inteligencia", player.stats['intelligence'] ?? 0, Colors.purpleAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. MOCHILA (Inventory Preview)
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Padding(
                         padding: EdgeInsets.only(left: 8.0, bottom: 10),
                         child: Text("MOCHILA RÁPIDA", style: TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
                       ),
                       Container(
                         height: 80,
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.05),
                           borderRadius: BorderRadius.circular(16),
                         ),
                         child: player.inventory.isEmpty 
                           ? const Center(child: Text("Mochila vacía", style: TextStyle(color: Colors.white38)))
                           : ListView.builder(
                               scrollDirection: Axis.horizontal,
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                               itemCount: player.inventory.length,
                               itemBuilder: (context, index) {
                                 // Simple icon mapping implies we use ID to guess icon
                                 final itemId = player.inventory[index];
                                 return Container(
                                   width: 56,
                                   margin: const EdgeInsets.only(right: 12),
                                   decoration: BoxDecoration(
                                     color: Colors.black26,
                                     borderRadius: BorderRadius.circular(12),
                                     border: Border.all(color: Colors.white10)
                                   ),
                                   child: Center(
                                     child: Text(
                                       _getItemIcon(itemId), 
                                       style: const TextStyle(fontSize: 24),
                                     ),
                                   ),
                                 );
                               },
                             ),
                       ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                const Text("ID: 8493-2023-GAME", style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCompact(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildContainerDivider() {
    return Container(width: 1, height: 30, color: Colors.white10);
  }

  Widget _buildAttributeRow(String label, int value, Color color) {
    // Normalize value roughly 0-100
    double progress = (value / 100).clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                 value: progress,
                 backgroundColor: Colors.black45,
                 valueColor: AlwaysStoppedAnimation(color),
                 minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text("$value", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _getItemIcon(String itemId) {
    if (itemId.contains('freeze')) return '❄️';
    if (itemId.contains('black_screen')) return '🕶️';
    if (itemId.contains('life')) return '❤️';
    if (itemId.contains('shield')) return '🛡️';
    if (itemId.contains('slow')) return '🐢';
    return '📦';
  }
}


IconData _getAvatarIcon(String profession) {
  switch (profession.toLowerCase()) {
    case 'speedrunner':
      return Icons.flash_on;
    case 'strategist':
      return Icons.psychology;
    case 'warrior':
      return Icons.shield;
    case 'balanced':
      return Icons.stars;
    case 'novice':
      return Icons.explore;
    default:
      return Icons.person;
  }
}
