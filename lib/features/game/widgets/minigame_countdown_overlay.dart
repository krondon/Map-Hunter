import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme/app_theme.dart';

class MinigameCountdownOverlay extends StatefulWidget {
  final String instruction;
  final Widget child;

  const MinigameCountdownOverlay({
    super.key,
    required this.instruction,
    required this.child,
  });

  @override
  State<MinigameCountdownOverlay> createState() =>
      _MinigameCountdownOverlayState();
}

class _MinigameCountdownOverlayState extends State<MinigameCountdownOverlay>
    with TickerProviderStateMixin {
  int _counter = 3;
  bool _isFinished = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Audio para efecto de sonido del countdown
  final AudioPlayer _beepPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    _beepPlayer.setVolume(0.8);
    _startCountdown();
  }

  @override
  void dispose() {
    _controller.dispose();
    _beepPlayer.dispose();
    super.dispose();
  }

  void _startCountdown() async {
    // Reproducir el audio de countdown UNA SOLA VEZ (se sincroniza con los números)
    try {
      await _beepPlayer.play(AssetSource('audio/countdown.mp3'));
    } catch (e) {
      debugPrint("Countdown audio error: $e");
    }

    // Show "3"
    HapticFeedback.lightImpact();
    await _playPulse();

    // Show "2"
    if (!mounted) return;
    setState(() => _counter = 2);
    HapticFeedback.lightImpact();
    await _playPulse();

    // Show "1"
    if (!mounted) return;
    setState(() => _counter = 1);
    HapticFeedback.mediumImpact();
    await _playPulse();

    // Show "¡YA!"
    if (!mounted) return;
    setState(() => _counter = 0);
    HapticFeedback.heavyImpact();
    await _playPulse();

    if (mounted) {
      // Detener audio por si aún suena
      try { await _beepPlayer.stop(); } catch (_) {}
      setState(() {
        _isFinished = true;
      });
    }
  }

  Future<void> _playPulse() async {
    if (!mounted) return;
    _controller.reset();
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return widget.child;
    }

    String displayText = _counter == 0 ? "¡YA!" : "$_counter";

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 500),
      color: Colors.black45,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 50),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: _counter == 0
                          ? AppTheme.successGreen
                          : AppTheme.accentGold,
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: (_counter == 0
                                  ? AppTheme.successGreen
                                  : AppTheme.accentGold)
                              .withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
