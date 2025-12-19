import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PowerSwipeAction extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  final IconData icon;

  const PowerSwipeAction({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = Icons.bolt,
  });

  @override
  State<PowerSwipeAction> createState() => _PowerSwipeActionState();
}

class _PowerSwipeActionState extends State<PowerSwipeAction> {
  double _dragPercent = 0;
  bool _triggered = false;

  void _reset() {
    if (!mounted) return;
    setState(() {
      _dragPercent = 0;
      _triggered = false;
    });
  }

  void _handleUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_triggered) return;
    final delta = details.primaryDelta ?? 0;
    final width = constraints.maxWidth;
    final next = (_dragPercent * width + delta).clamp(0, width);
    setState(() {
      _dragPercent = next / width;
    });
    if (_dragPercent >= 0.95) {
      _triggered = true;
      widget.onConfirmed();
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final progressWidth = constraints.maxWidth * _dragPercent;
        return GestureDetector(
          onHorizontalDragUpdate: (d) => _handleUpdate(d, constraints),
          onHorizontalDragEnd: (_) => _reset(),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: progressWidth,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
