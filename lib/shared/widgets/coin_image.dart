import 'package:flutter/material.dart';

class CoinImage extends StatelessWidget {
  final double size;
  const CoinImage({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/coin.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.monetization_on, size: size, color: Colors.amber);
        },
      ),
    );
  }
}
