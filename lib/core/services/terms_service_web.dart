import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'terms_service_interface.dart';

class TermsServiceImpl implements TermsService {
  @override
  Future<void> launchTerms(String baseUrl) async {
    try {
      final url = Uri.parse('$baseUrl/functions/v1/get-terms');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'application/pdf');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);

        // Abrimos en una nueva pestaña. La URL se verá como blob:http://...
        html.window.open(blobUrl, '_blank');
      } else {
        throw Exception('Falló la descarga del PDF: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en TermsServiceWeb: $e');
      rethrow;
    }
  }
}

// Factoría para exportar la implementación correcta
TermsService getTermsService() => TermsServiceImpl();
