import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/providers/app_mode_provider.dart';
import 'scenarios_screen.dart';
import '../../auth/providers/player_provider.dart';
import '../../auth/screens/login_screen.dart';

class GameModeSelectorScreen extends StatelessWidget {
  const GameModeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'SELECCIONA TU MODO',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 24,
                        letterSpacing: 2,
                        color: Colors.white,
                        shadows: [
                          const Shadow(
                            color: AppTheme.primaryPurple,
                            blurRadius: 10,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '¿Cómo deseas participar hoy?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                
                // Card Presencial
                _ModeCard(
                  title: 'MODO PRESENCIAL',
                  description: 'Vive la aventura en el mundo real. Requiere GPS y escanear códigos QR en ubicaciones físicas.',
                  icon: Icons.location_on_outlined,
                  color: AppTheme.accentGold,
                  onTap: () {
                    context.read<AppModeProvider>().setMode(GameMode.presencial);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ScenariosScreen()),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Card Online
                _ModeCard(
                  title: 'MODO ONLINE',
                  description: 'Participa desde cualquier lugar. Acceso mediante códigos PIN y minijuegos digitales.',
                  icon: Icons.wifi,
                  color: Colors.cyanAccent,
                  onTap: () {
                    context.read<AppModeProvider>().setMode(GameMode.online);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ScenariosScreen()),
                    );
                  },
                ),
                
                const Spacer(),
                
                // Logout button for convenience
                TextButton.icon(
                  onPressed: () async {
                    // Logout and navigate to login
                    try {
                      await context.read<PlayerProvider>().logout();
                    } catch (e) {
                      debugPrint('Error logging out: $e');
                    }
                    
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white54),
                  label: const Text('Volver', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.15),
                  Colors.black.withOpacity(0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.color.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: widget.color.withOpacity(0.5),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
