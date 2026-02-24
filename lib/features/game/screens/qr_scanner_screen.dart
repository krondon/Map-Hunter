import 'dart:ui';
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
        
        final sanitized = InputSanitizer.sanitizeQRCode(rawCode);
        debugPrint('QR Sanitized: $sanitized');
        
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
        
        Navigator.pop(context, sanitized);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // Marco de esquinas para apuntar
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppTheme.accentGold,
                borderRadius: 20,
                borderLength: 40,
                borderWidth: 4,
                cutOutSize: 280,
                overlayColor: Colors.transparent,
              ),
            ),
          ),

          // Back button (estilo avatar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentGold.withOpacity(0.3),
                    width: 1.0,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.6),
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          // Título superior
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'ESCANEAR QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: AppTheme.accentGold.withOpacity(0.5), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),

          // Instrucciones glassmorphism abajo
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0F).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.4), width: 1),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentGold.withOpacity(0.15)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner, color: AppTheme.accentGold, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              widget.expectedClueId != null 
                                  ? 'Busca el código QR de la pista' 
                                  : 'Apunta la cámara al código QR',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'El escaneo es automático',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.accentGold),
                    const SizedBox(height: 16),
                    Text(
                      'Procesando...',
                      style: TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: AppTheme.accentGold.withOpacity(0.5), blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Botón Simular Escaneo
          if (true)
            Positioned(
              bottom: 160,
              left: 24,
              right: 24,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final fakeCode = widget.expectedClueId != null 
                        ? "CLUE:${widget.expectedClueId}" 
                        : "DEV_SKIP_CODE";
                    Navigator.pop(context, fakeCode);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.accentGold.withOpacity(0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    foregroundColor: AppTheme.accentGold,
                    backgroundColor: Colors.black.withOpacity(0.4),
                  ),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text(
                    'SIMULAR ESCANEO',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
        ],
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