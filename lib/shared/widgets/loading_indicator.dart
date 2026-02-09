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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMessage) ...[
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
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: fontSize * 1.5,
            height: fontSize * 1.5,
            child: CircularProgressIndicator(
              color: color,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }
}
