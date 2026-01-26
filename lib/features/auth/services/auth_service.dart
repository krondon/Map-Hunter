import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de autenticación que encapsula la lógica de login, registro y logout.
/// 
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AuthService {
  final SupabaseClient _supabase;

  AuthService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Inicia sesión con email y password.
  /// 
  /// Retorna el ID del usuario autenticado en caso de éxito.
  /// Lanza una excepción con mensaje legible si falla.
  Future<String> login(String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/login',
        body: {'email': email, 'password': password},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        throw error;
      }

      final data = response.data;

      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);

        if (data['user'] != null) {
          return data['user']['id'] as String;
        }
        throw 'No se recibió información del usuario';
      } else {
        throw 'No se recibió sesión válida';
      }
    } catch (e) {
      debugPrint('AuthService: Error logging in: $e');
      throw _handleAuthError(e);
    }
  }

  /// Registra un nuevo usuario con nombre, email y password.
  /// 
  /// Retorna el ID del usuario creado en caso de éxito.
  /// Lanza una excepción con mensaje legible si falla.
  Future<String> register(String name, String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/register',
        body: {'email': email, 'password': password, 'name': name},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        throw error;
      }

      final data = response.data;

      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);

        if (data['user'] != null) {
          // Delay para permitir que la BD sincronice el perfil
          await Future.delayed(const Duration(seconds: 1));
          return data['user']['id'] as String;
        }
        throw 'No se recibió información del usuario';
      }
      throw 'No se recibió sesión válida';
    } catch (e) {
      debugPrint('AuthService: Error registering: $e');
      throw _handleAuthError(e);
    }
  }

  /// Cierra la sesión del usuario actual.
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// Envía un correo de recuperación de contraseña.
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'io.supabase.treasurehunt://reset-password',
      );
    } catch (e) {
      debugPrint('AuthService: Error resetting password: $e');
      throw _handleAuthError(e);
    }
  }

  /// Actualiza la contraseña del usuario actual.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      debugPrint('AuthService: Error updating password: $e');
      throw _handleAuthError(e);
    }
  }

  /// Actualiza el avatar del usuario en su perfil.
  Future<void> updateAvatar(String userId, String avatarId) async {
    debugPrint('AuthService: Updating avatar for $userId to $avatarId');
    try {
      await _supabase.from('profiles').update({
        'avatar_id': avatarId,
      }).eq('id', userId);
      debugPrint('AuthService: Avatar updated successfully in profiles table');
    } catch (e) {
      debugPrint('AuthService: Error updating avatar: $e');
      throw _handleAuthError(e);
    }
  }

  /// Convierte errores de autenticación en mensajes legibles para el usuario.
  String _handleAuthError(dynamic e) {
    String errorMsg = e.toString().toLowerCase();

    if (errorMsg.contains('invalid login credentials') ||
        errorMsg.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';
    }
    if (errorMsg.contains('user already registered') ||
        errorMsg.contains('already exists')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('password should be at least 6 characters')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (errorMsg.contains('network') || errorMsg.contains('connection')) {
      return 'Error de conexión. Revisa tu internet e intenta de nuevo.';
    }
    if (errorMsg.contains('email not confirmed')) {
      return 'Debes confirmar tu correo electrónico antes de entrar.';
    }
    if (errorMsg.contains('too many requests')) {
      return 'Demasiados intentos. Por favor espera un momento.';
    }
    if (errorMsg.contains('suspendida') || errorMsg.contains('banned')) {
      return 'Tu cuenta ha sido suspendida permanentemente.';
    }

    // Limpiar el prefijo 'Exception: ' si existe
    return e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('exception: ', '');
  }
}
