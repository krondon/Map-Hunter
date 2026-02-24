import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'terms_service_interface.dart';

class TermsServiceImpl implements TermsService {
  @override
  Future<void> launchTerms(String baseUrl) async {
    try {
      final termsUrl = '$baseUrl/functions/v1/get-terms';

      // Descargamos los bytes del PDF de forma privada
      final response = await http.get(Uri.parse(termsUrl));

      if (response.statusCode == 200) {
        // Usamos el paquete 'printing' para mostrar el PDF en un visor nativo
        // Esto NO abre el navegador y NO muestra ninguna URL al usuario.
        await Printing.layoutPdf(
          onLayout: (_) => response.bodyBytes,
          name: 'Terminos_y_Condiciones_Maphunter.pdf',
        );
      } else {
        throw Exception('Falló la descarga del PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al abrir términos en móvil: $e');
    }
  }
}

TermsService getTermsService() => TermsServiceImpl();
