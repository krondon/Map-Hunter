import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String message;
  final bool showMessage;
  final Color color;
  final double fontSize;

  const LoadingIndicator({
    super.key,
    this.message = 'Cargando...',
    this.showMessage = true,
    this.color = const Color(0xFFFECB00), // Legendary Gold
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isVerySmall = constraints.maxHeight < 60;
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMessage && !isVerySmall) ...[
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                      decoration: TextDecoration.none,
                      fontFamily: 'Inter',
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: isVerySmall ? 20 : fontSize * 1.2,
                  height: isVerySmall ? 20 : fontSize * 1.2,
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
