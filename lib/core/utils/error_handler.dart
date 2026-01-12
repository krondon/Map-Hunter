import 'dart:io';

class ErrorHandler {
  static String getFriendlyErrorMessage(Object error) {
    if (error is SocketException) {
      return 'Revisa tu conexión a internet, la aventura no puede comenzar sin conexión.';
    }

    final String message = error.toString().toLowerCase();

    // Errores de conexión / Red
    if (message.contains('socketexception') || 
        message.contains('failed host lookup') || 
        message.contains('connection refused') ||
        message.contains('network is unreachable')) {
      return 'Revisa tu conexión a internet, la aventura no puede comenzar sin conexión.';
    }

    // Errores de Login
    if (message.contains('invalid login credentials') || 
        message.contains('invalid_grant') ||
        message.contains('invalid_credentials') ||
        message.contains('wrong password') || 
        message.contains('invalid email or password')) {
      return 'Credenciales incorrectas. Verifica tu email y contraseña.';
    }

    if (message.contains('user not found')) {
      return 'No existe una cuenta con este correo electrónico.';
    }

    // Errores de Registro
    if (message.contains('user already registered') || 
        message.contains('unique violation')) {
      return 'Ya existe una cuenta registrada con este correo.';
    }
    
    if (message.contains('password should be at least')) {
        return 'La contraseña es muy corta.';
    }

    // Errores de Baneo
    if (message.contains('suspendida') || 
        message.contains('banned') || 
        message.contains('bloqueada')) {
      return 'Tu cuenta ha sido suspendida permanentemente.';
    }

    // Mensaje por defecto (limpiamos un poco el mensaje técnico si es posible)
    if (message.contains('exception:')) {
      return message.split('exception:').last.trim();
    }

    return 'Ocurrió un error inesperado ($message).';
  }
}
