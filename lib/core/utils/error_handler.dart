import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  static String getFriendlyErrorMessage(Object error) {
    if (error is SocketException) {
      return 'Revisa tu conexión a internet, la aventura no puede comenzar sin conexión.';
    }

    // FunctionException: extract the friendly message from details['error']
    // instead of showing the raw exception toString.
    if (error is FunctionException) {
      if (error.status == 409 || error.toString().contains('409')) {
        return 'Este correo ya está registrado. Intenta iniciar sesión.';
      }
      final details = error.details;
      if (details is Map && details['error'] is String) {
        final serverMsg = details['error'] as String;
        // The server already sends a user-friendly message, return it directly
        return serverMsg;
      }
    }

    final String message = error.toString().toLowerCase();

    // Errores de Registro / Código 409
    if (message.contains('409') || 
        message.contains('conflict') || 
        message.contains('already exists')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }

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
    if (message.contains('profiles_id_fkey') || 
        message.contains('foreign key constraint')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (message.contains('is invalid') && message.contains('email')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    
    if (message.contains('password should be at least')) {
        return 'La contraseña es muy corta.';
    }
    
    if (message.contains('422') || message.contains('different from the old password')) {
        return 'La nueva contraseña debe ser diferente a la anterior.';
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
