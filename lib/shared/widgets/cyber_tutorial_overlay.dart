import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
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
      backgroundColor: (isDarkMode ? Colors.black : const Color(0xFF121212)).withOpacity(0.7),
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1A1D) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(isDarkMode ? 0.2 : 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    color: AppTheme.accentGold,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  step.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.steps.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _currentIndex ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _currentIndex 
                            ? AppTheme.accentGold 
                            : AppTheme.accentGold.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ANTERIOR',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white54 : Colors.black45, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.accentGold.withOpacity(0.5),
                        ),
                        onPressed: _next,
                        child: Text(
                          _currentIndex == widget.steps.length - 1 ? '¡ENTENDIDO!' : 'SIGUIENTE',
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
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
    );
  }
}
