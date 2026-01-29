/// Utilidad de sanitización de inputs para mitigar riesgos de inyección.
/// 
/// Esta clase proporciona métodos estáticos para limpiar y validar
/// datos de entrada antes de procesarlos en la aplicación.
class InputSanitizer {
  /// Longitud máxima permitida para códigos QR.
  static const int maxQRCodeLength = 100;

  /// Expresión regular que permite solo caracteres seguros:
  /// - Caracteres alfanuméricos (\w = [a-zA-Z0-9_])
  /// - Guiones (-)
  /// - Dos puntos (:)
  static final RegExp _unsafeCharacters = RegExp(r'[^\w\-:]');

  /// Sanitiza un código QR eliminando caracteres potencialmente peligrosos.
  /// 
  /// Proceso de sanitización:
  /// 1. Elimina espacios en blanco al inicio y final.
  /// 2. Remueve todos los caracteres que no sean alfanuméricos, guiones o dos puntos.
  /// 3. Limita la longitud máxima a [maxQRCodeLength] caracteres.
  /// 
  /// Retorna el código sanitizado, o una cadena vacía si el input es null.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final clean = InputSanitizer.sanitizeQRCode('CLUE:abc-123<script>alert(1)</script>');
  /// // Resultado: 'CLUE:abc-123scriptalert1script'
  /// ```
  static String sanitizeQRCode(String? rawCode) {
    if (rawCode == null) return '';

    // Paso 1: Eliminar espacios en blanco
    String sanitized = rawCode.trim();

    // Paso 2: Eliminar caracteres no seguros
    sanitized = sanitized.replaceAll(_unsafeCharacters, '');

    // Paso 3: Limitar longitud
    if (sanitized.length > maxQRCodeLength) {
      sanitized = sanitized.substring(0, maxQRCodeLength);
    }

    return sanitized;
  }

  /// Verifica si el texto contiene palabras inadecuadas.
  static bool hasInappropriateContent(String text) {
    if (text.isEmpty) return false;
    
    // Lista básica de palabras inadecuadas (puedes expandirla)
    final bannedWords = [
      'puto', 'puta', 'mierda', 'gonorrea', 'malparido', 'hijueputa', 
      'culero', 'pendejo', 'zorra', 'maricon', 'verga', 'chupa', 'idiota'
    ];
    
    final lowerText = text.toLowerCase();
    
    for (var word in bannedWords) {
      if (lowerText.contains(word)) {
        return true;
      }
    }
    
    return false;
  }

  /// Verifica si un código QR sanitizado es válido (no vacío).
  static bool isValidQRCode(String sanitizedCode) {
    return sanitizedCode.isNotEmpty;
  }
}
