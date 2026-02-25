
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ScenarioCountdown extends StatefulWidget {
  final DateTime targetDate;
  final String eventStatus; // 'pending', 'active', 'completed'

  const ScenarioCountdown({
    super.key,
    required this.targetDate,
    this.eventStatus = 'pending',
  });

  @override
  State<ScenarioCountdown> createState() => _ScenarioCountdownState();
}

class _ScenarioCountdownState extends State<ScenarioCountdown> {
  Timer? _timer;
  Duration? _timeLeft;
  bool _isStarted = false;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTime());
  }

  void _calculateTime() {
    final now = DateTime.now();
    if (widget.targetDate.isAfter(now)) {
      if (mounted) {
        setState(() {
          _timeLeft = widget.targetDate.difference(now);
          _isStarted = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = null;
          _isStarted = true;
        });
      }
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isStarted) {
      // Time is up: Show different badge based on event status
      final bool isActive = widget.eventStatus == 'active';
      final Color badgeColor = isActive ? Colors.greenAccent : Colors.orangeAccent;
      final String badgeText = isActive ? "EN CURSO" : "ESPERANDO ADMIN";

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor,
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_timeLeft == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            "${_timeLeft!.inDays}d ${_timeLeft!.inHours % 24}h ${_timeLeft!.inMinutes % 60}m ${_timeLeft!.inSeconds % 60}s",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
