
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ScenarioCountdown extends StatefulWidget {
  final DateTime targetDate;

  const ScenarioCountdown({super.key, required this.targetDate});

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
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
        ),
        child: const Text(
          "EN CURSO",
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      );
    }

    if (_timeLeft == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            "${_timeLeft!.inDays}d ${_timeLeft!.inHours % 24}h ${_timeLeft!.inMinutes % 60}m ${_timeLeft!.inSeconds % 60}s",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
