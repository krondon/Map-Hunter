import 'dart:async';
import 'package:flutter/material.dart';

class EffectTimer extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback? onFinished;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? textColor;

  const EffectTimer({
    super.key,
    required this.expiresAt,
    this.onFinished,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.textColor,
  });

  @override
  State<EffectTimer> createState() => _EffectTimerState();
}

class _EffectTimerState extends State<EffectTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    final now = DateTime.now().toUtc();
    final diff = widget.expiresAt.difference(now);
    
    if (diff.isNegative) {
      _remaining = Duration.zero;
      _timer.cancel();
      widget.onFinished?.call();
    } else {
      _remaining = diff;
    }
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.backgroundColor ?? Colors.black.withOpacity(0.85),
              widget.backgroundColor?.withOpacity(0.7) ?? Colors.black.withOpacity(0.65),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.borderColor ?? Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: (widget.iconColor ?? Colors.white70).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timer_outlined,
                color: widget.iconColor ?? Colors.white70,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatDuration(_remaining),
              style: TextStyle(
                color: widget.textColor ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Courier',
                letterSpacing: 1.2,
                decoration: TextDecoration.none, // Elimina el subrayado amarillo
              ),
            ),
          ],
        ),
      ),
    );
  }
}
