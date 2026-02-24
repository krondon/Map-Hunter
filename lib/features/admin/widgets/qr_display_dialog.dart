import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_theme.dart';

class QRDisplayDialog extends StatelessWidget {
  final String data;
  final String title;
  final String label;
  final String? hint;

  const QRDisplayDialog({
    super.key,
    required this.data,
    required this.title,
    required this.label,
    this.hint,
  });

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();

    // Load Unicode-compatible fonts (supports Spanish accented characters)
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: data,
                  width: 300,
                  height: 300,
                ),
                if (hint != null && hint!.isNotEmpty) ...[
                  pw.SizedBox(height: 20),
                  pw.Text(
                    hint!,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontItalic,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.normal,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  Future<void> _printPdf(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => _generatePdf(format),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    final pdfBytes = await _generatePdf(PdfPageFormat.a4);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'qr_${title.replaceAll(RegExp(r'\s+'), '_')}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1F3A), Color(0xFF0A0E27)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGold.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText( // Allows copying manually if needed
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (hint != null && hint!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  "Pista: $hint",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                "Escanea este código para acceder",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
             const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _printPdf(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black12),
                      ),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text(
                      "IMPRIMIR",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadPdf(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text(
                      "DESCARGAR",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check),
                label: const Text(
                  "LISTO",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
