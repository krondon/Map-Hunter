import 'package:flutter/material.dart';

class InvisibilityEffect extends StatelessWidget {
  const InvisibilityEffect({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final overlay = Color.alphaBlend(
      Colors.black.withOpacity(0.22),
      primary.withOpacity(0.16),
    );

    return IgnorePointer(
      child: Stack(
        children: [
          Container(color: overlay),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Modo invisible',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ) ??
                      TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
