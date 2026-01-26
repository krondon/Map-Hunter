import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../game/models/clue.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final gameProvider = Provider.of<GameProvider>(context);
    final player = playerProvider.currentPlayer;
    
    if (player == null) {
      return const Center(child: Text('No player data', style: TextStyle(color: Colors.white)));
    }
    
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: AnimatedCyberBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              backgroundColor: Colors.black.withOpacity(0.5),
              title: const Text('ID DE JUGADOR', 
                style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 16)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: AppTheme.dangerRed),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.cardBg,
                        title: const Text('Cerrar Sesión',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                          '¿Estás seguro que deseas cerrar sesión?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar',
                                style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx); // Close dialog
                              playerProvider.logout();
                              // AuthMonitor will handle navigation
                            },
                            child: const Text('Salir',
                                style: TextStyle(color: AppTheme.dangerRed)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 1. GAMER CARD WITH NEON GLOW
                    _buildGamerCard(player),
                    
                    const SizedBox(height: 24),
                    
                    // 2. TEMPORAL STAMPS (SELLOS) - NEW ANIMATED SECTION
                    _buildTemporalStampsSection(gameProvider),
                    
                    const SizedBox(height: 24),
                    


                    const SizedBox(height: 40),
                    const Text("ASTHORIA PROTOCOL v1.0.4", 
                      style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 4)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamerCard(dynamic player) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.2), 
            blurRadius: 30, 
            offset: const Offset(0, 10)
          )
        ]
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
               SizedBox(
                 width: 120, height: 120,
                 child: CircularProgressIndicator(
                   value: player.experienceProgress,
                   strokeWidth: 8,
                   backgroundColor: Colors.white10,
                   valueColor: const AlwaysStoppedAnimation(AppTheme.accentGold),
                 ),
               ),
               Container(
                 width: 95, height: 95,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   gradient: LinearGradient(
                     colors: [AppTheme.primaryPurple, AppTheme.secondaryPink],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15)]
                 ),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(47.5),
                   child: Builder(
                     builder: (context) {
                       final avatarId = player.avatarId;
                       
                       // 1. Prioridad: Avatar Local
                       if (avatarId != null && avatarId.isNotEmpty) {
                         return Image.asset(
                           'assets/images/avatars/$avatarId.png',
                           fit: BoxFit.cover,
                           errorBuilder: (_, __, ___) => Icon(_getAvatarIcon(player.profession), size: 55, color: Colors.white),
                         );
                       }
                       
                       // 2. Fallback: Foto de perfil (URL)
                       if (player.avatarUrl != null && player.avatarUrl!.startsWith('http')) {
                         return Image.network(
                           player.avatarUrl!,
                           fit: BoxFit.cover,
                           errorBuilder: (_, __, ___) => Icon(_getAvatarIcon(player.profession), size: 55, color: Colors.white),
                         );
                       }
                       
                       // 3. Fallback: Icono de profesión
                       return Icon(_getAvatarIcon(player.profession), size: 55, color: Colors.white);
                     },
                   ),
                 ),
               ),
               Positioned(
                 bottom: 0,
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                   decoration: BoxDecoration(
                     color: AppTheme.accentGold,
                     borderRadius: BorderRadius.circular(12),
                     boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black45)]
                   ),
                   child: Text("LVL ${player.level}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                 ),
               )
            ],
          ),
          const SizedBox(height: 20),
          Text(player.name.toUpperCase(), 
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(player.profession.toUpperCase(), 
            style: const TextStyle(color: AppTheme.secondaryPink, fontSize: 12, letterSpacing: 4, fontWeight: FontWeight.w300)),
          
          const SizedBox(height: 30),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCompact(Icons.monetization_on, "${player.coins}", "MONEDAS", AppTheme.accentGold),
              _buildVerticalDivider(),
              _buildStatCompact(Icons.star, "${player.totalXP}", "XP TOTAL", AppTheme.secondaryPink),
              _buildVerticalDivider(),
              _buildStatCompact(Icons.emoji_events, "${player.eventsCompleted?.length ?? 0}", "EVENTOS", Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemporalStampsSection(GameProvider gameProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("SELLOS TEMPORALES", 
              style: TextStyle(color: AppTheme.accentGold, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w900)),
            Text("${gameProvider.completedClues}/${gameProvider.totalClues}", 
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: gameProvider.clues.isEmpty
            ? const Center(child: Text("Inicia una misión para recolectar sellos", 
                style: TextStyle(color: Colors.white24, fontSize: 12)))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                itemCount: gameProvider.clues.length,
                itemBuilder: (context, index) {
                  final clue = gameProvider.clues[index];
                  final bool isCollected = clue.isCompleted;
                  
                  return _buildStampItem(clue, isCollected, index);
                },
              ),
        ),
      ],
    );
  }

  Widget _buildStampItem(Clue clue, bool isCollected, int index) {
    final gradient = _getStampGradient(index);
    
    return Container(
      width: 75,
      margin: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 1000 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCollected ? null : Colors.black45,
                      gradient: isCollected ? LinearGradient(colors: gradient) : null,
                      border: Border.all(
                        color: isCollected ? Colors.white : Colors.white10, 
                        width: isCollected ? 2 : 1
                      ),
                      boxShadow: isCollected ? [
                        BoxShadow(color: gradient[0].withOpacity(0.5), blurRadius: 10, spreadRadius: 1)
                      ] : null,
                    ),
                    child: Icon(
                      _getStampIcon(index),
                      size: 24,
                      color: isCollected ? Colors.white : Colors.white10,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text("S${index + 1}", 
            style: TextStyle(
              fontSize: 10, 
              color: isCollected ? Colors.white70 : Colors.white10,
              fontWeight: FontWeight.bold
            )
          ),
        ],
      ),
    );
  }



  Widget _buildAttributeBar(String label, int value, Color color) {
    double progress = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("$value%", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
               value: progress,
               backgroundColor: Colors.white.withOpacity(0.05),
               valueColor: AlwaysStoppedAnimation(color),
               minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCompact(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 35, color: Colors.white.withOpacity(0.05));
  }

  IconData _getAvatarIcon(String profession) {
    switch (profession.toLowerCase()) {
      case 'speedrunner': return Icons.flash_on;
      case 'strategist': return Icons.psychology;
      case 'warrior': return Icons.shield;
      case 'balanced': return Icons.stars;
      case 'novice': return Icons.explore;
      default: return Icons.person;
    }
  }

  IconData _getStampIcon(int index) {
    const icons = [Icons.extension, Icons.lock_open, Icons.history_edu, Icons.warning_amber, Icons.cable, Icons.palette, Icons.visibility, Icons.settings_suggest, Icons.flash_on];
    return icons[index % icons.length];
  }

  List<Color> _getStampGradient(int index) {
    const gradients = [[Color(0xFF3B82F6), Color(0xFF06B6D4)], [Color(0xFF06B6D4), Color(0xFF10B981)], [Color(0xFF10B981), Color(0xFF84CC16)], [Color(0xFF84CC16), Color(0xFFF59E0B)], [Color(0xFFF59E0B), Color(0xFFEF4444)], [Color(0xFFEF4444), Color(0xFFEC4899)], [Color(0xFFEC4899), Color(0xFFD946EF)], [Color(0xFFD946EF), Color(0xFF8B5CF6)], [Color(0xFF8B5CF6), Color(0xFF6366F1)]];
    return gradients[index % gradients.length];
  }
}
