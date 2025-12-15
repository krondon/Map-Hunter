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
      return const Center(child: Text('No player data'));
    }
    
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.darkGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Logout button at top right
              Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(top: 10, right: 16),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () {
                    playerProvider.logout();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ),
              
              // Profile header
              Column(
                children: [
                  // Avatar with icon instead of photo
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.cardBg,
                      ),
                      child: Icon(
                        _getAvatarIcon(player.profession),
                        size: 60,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  
                  // Profession badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      player.profession,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Level and XP
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nivel ${player.level}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${player.experience} / ${player.experienceToNextLevel} XP',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: player.experienceProgress,
                        minHeight: 12,
                        backgroundColor: AppTheme.cardBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.secondaryPink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Stats grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    StatCard(
                      icon: Icons.monetization_on,
                      title: 'Monedas',
                      value: '${player.coins}',
                      color: AppTheme.accentGold,
                    ),
                    StatCard(
                      icon: Icons.star,
                      title: 'XP Total',
                      value: '${player.totalXP}',
                      color: AppTheme.secondaryPink,
                    ),
                    StatCard(
                      icon: Icons.flash_on,
                      title: 'Velocidad',
                      value: '${player.stats['speed']}',
                      color: Colors.blue,
                    ),
                    StatCard(
                      icon: Icons.fitness_center,
                      title: 'Fuerza',
                      value: '${player.stats['strength']}',
                      color: Colors.red,
                    ),
                    StatCard(
                      icon: Icons.psychology,
                      title: 'Inteligencia',
                      value: '${player.stats['intelligence']}',
                      color: Colors.purple,
                    ),
                    StatCard(
                      icon: Icons.inventory_2,
                      title: 'Items',
                      value: '${player.inventory.length}',
                      color: AppTheme.successGreen,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
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
