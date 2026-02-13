import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Widget? visual; // Para fotos, animaciones o ejemplos

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    this.visual,
  });
}

class CyberTutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onFinish;

  const CyberTutorialOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<CyberTutorialOverlay> createState() => _CyberTutorialOverlayState();
}

class _CyberTutorialOverlayState extends State<CyberTutorialOverlay> {
  int _currentIndex = 0;

  void _next() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() => _currentIndex++);
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentIndex];
    
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isDarkMode = playerProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Container(
              key: ValueKey(_currentIndex),
              margin: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1D) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppTheme.accentGold.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Visual Area (Simula un vídeo o demo)
                    if (step.visual != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: step.visual,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                       // Icon Fallback
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          color: AppTheme.accentGold,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Title
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Description
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.steps.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _currentIndex ? 32 : 8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == _currentIndex 
                                ? AppTheme.accentGold 
                                : AppTheme.accentGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Actions
                    Row(
                      children: [
                        if (_currentIndex > 0)
                          Expanded(
                            child: TextButton(
                              onPressed: () => setState(() => _currentIndex--),
                              child: Text(
                                'ATRÁS',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white38 : Colors.black38, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentGold.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _next,
                              child: Text(
                                _currentIndex == widget.steps.length - 1 ? '¡LISTO PARA JUGAR!' : 'SIGUIENTE',
                                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
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
          ),
        ),
      ),
    );
  }
}
