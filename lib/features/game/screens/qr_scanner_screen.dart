import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/input_sanitizer.dart';

class QRScannerScreen extends StatefulWidget {
  final String? expectedClueId; // Optional validation
  
  const QRScannerScreen({super.key, this.expectedClueId});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        final rawCode = barcode.rawValue!;
        debugPrint('QR Scanned (raw): $rawCode');
        
        // Sanitizar el código para mitigar inyección y datos malformados
        final sanitized = InputSanitizer.sanitizeQRCode(rawCode);
        debugPrint('QR Sanitized: $sanitized');
        
        // Validar que el código sanitizado no esté vacío
        if (!InputSanitizer.isValidQRCode(sanitized)) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código QR no válido'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        // Devolver el código sanitizado
        Navigator.pop(context, sanitized);
        return; // Procesar solo el primer código válido
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Escanear QR", style: TextStyle(color: Colors.white)),
        // Actions removed temporarily to ensure compatibility with MobileScanner v7+
        // functionality can be re-added once API is verified.
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Stack(
          children: [
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
            // Overlay
            Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: AppTheme.accentGold,
                  borderRadius: 20,
                  borderLength: 40,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  widget.expectedClueId != null 
                      ? "Busca el código QR de la pista" 
                      : "Escanea el código QR",
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero)
      ..addRect(_getCutOutRect(rect));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = _getCutOutRect(rect);
    final cutOutRRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        rect,
        backgroundPaint,
      )
      ..drawRRect(
        cutOutRRect,
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final cutOutPath = Path()..addRRect(cutOutRRect);

    canvas.drawPath(cutOutPath, borderPaint);
  }

  Rect _getCutOutRect(Rect rect) {
    final width = rect.width;
    final height = rect.height;
    final _cutOutSize = cutOutSize < width
        ? cutOutSize
        : width - 40;
    final cutOutHeight = _cutOutSize;

    return Rect.fromLTWH(
      width / 2 - _cutOutSize / 2,
      height / 2 - cutOutHeight / 2,
      _cutOutSize,
      cutOutHeight,
    );
  }
  
  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}