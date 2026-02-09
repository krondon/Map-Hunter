import 'package:flutter/material.dart';
import '../../../shared/widgets/loading_indicator.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final BoxFit fit;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Validación básica: si es nulo, vacío o es una ruta local de Windows
    if (url == null || url!.isEmpty || url!.contains('C:/') || url!.startsWith('file://')) {
      return _buildErrorContainer();
    }

    // 2. Intentar cargar la imagen
    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.black12,
          child: const Center(child: LoadingIndicator(fontSize: 10)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorContainer();
      },
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800], // Fondo oscuro
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.white54, size: 40),
          SizedBox(height: 5),
          Text(
            'Imagen no disponible',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          )
        ],
      ),
    );
  }
}