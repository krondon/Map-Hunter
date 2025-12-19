import 'package:flutter/material.dart';

class BlindEffect extends StatelessWidget {
  const BlindEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              "¡TE HAN CEGADO!",
              style: TextStyle(
                color: Colors.white, 
                fontSize: 24, 
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }
}