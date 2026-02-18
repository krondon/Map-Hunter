import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';

/// Servicio de autenticación que encapsula la lógica de login, registro y logout.
///
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AuthService {
  final SupabaseClient _supabase;
  final List<Future<void> Function()> _logoutCallbacks = [];

  AuthService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Registra un callback que se ejecutará al cerrar sesión.
  void onLogout(Future<void> Function() callback) {
    _logoutCallbacks.add(callback);
  }

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

        // 403 = email not verified → clean up any local session state
        if (response.status == 403) {
          try {
            await _supabase.auth.signOut();
          } catch (_) {}
        }
        throw error;
      }

      final data = response.data;

      if (data['session'] != null) {
        await _supabase.auth.setSession(data['session']['refresh_token']);

        if (data['user'] != null) {
          final user = data['user'];

          // Verificar si el email ha sido confirmado (redundant safety check)
          if (user['email_confirmed_at'] == null) {
            await logout(); // Limpiar cualquier sesión parcial
            throw 'Tu cuenta aún no está activa. Por favor, verifica tu correo electrónico.';
          }

          return user['id'] as String;
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

  /// Inicia sesión como ADMINISTRADOR.
  ///
  /// Verificas credenciales y ADEMÁS verifica que el usuario tenga rol 'admin'.
  /// Si no es admin, cierra sesión automáticamente y lanza excepción.
  Future<String> loginAdmin(String email, String password) async {
    try {
      // 1. Login normal
      final userId = await login(email, password);

      // 2. Verificar rol
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = profile['role'] as String?;

      if (role != 'admin') {
        debugPrint('AuthService: Access denied for $email (Role: $role)');
        await logout(); // Limpiar sesión inmediatamente
        throw 'Acceso denegado: No tienes permisos de administrador.';
      }

      return userId;
    } catch (e) {
      // Re-lanzar errores ya procesados o procesar nuevos
      debugPrint('AuthService: Error logging in as admin: $e');
      if (e is String) rethrow;
      throw _handleAuthError(e);
    }
  }

  /// Registra un nuevo usuario con nombre, email y password.
  ///
  /// Retorna el ID del usuario creado en caso de éxito.
  /// Lanza una excepción con mensaje legible si falla.
  Future<String> register(String name, String email, String password,
      {String? cedula, String? phone}) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'cedula': cedula,
          'phone': phone,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Error desconocido';
        // 409 = user already exists (race condition handled gracefully)
        // Just rethrow the user-friendly message from the server
        throw error;
      }

      final data = response.data;

      if (data['user'] != null) {
        // Si hay usuario, el registro fue exitoso a nivel de BD.
        // Si hay sesión, la guardamos. Si no (porque requiere confirmación), seguimos igual.
        if (data['session'] != null) {
          await _supabase.auth.setSession(data['session']['refresh_token']);
        }

        final userId = data['user']['id'] as String;

        // Delay para permitir que la BD sincronice el perfil (Trigger)
        await Future.delayed(const Duration(seconds: 1));

        // Actualización explícita de datos extra en perfil si tenemos sesión
        // Si no tenemos sesión (email sin confirmar), esto fallará por RLS, así que lo omitimos o lo intentamos con catch
        if ((cedula != null || phone != null) && data['session'] != null) {
          try {
            await _supabase.from('profiles').update({
              if (cedula != null) 'cedula': cedula,
              if (phone != null) 'phone': phone,
            }).eq('id', userId);
          } catch (e) {
            debugPrint('Warning: Could not update extra profile fields: $e');
          }
        }

        return userId;
      }
      throw 'No se recibió información del usuario';
    } catch (e) {
      debugPrint('AuthService: Error registering: $e');
      throw _handleAuthError(e);
    }
  }

  /// Cierra la sesión del usuario actual y ejecuta los callbacks de limpieza.
  Future<void> logout() async {
    debugPrint('AuthService: Executing Global Logout...');

    // 1. Ejecutar limpieza de providers
    for (final callback in _logoutCallbacks) {
      try {
        await callback();
      } catch (e) {
        debugPrint('AuthService: Error in logout callback: $e');
      }
    }

    // 2. Cerrar sesión en Supabase
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

  /// Actualiza la información del perfil del usuario.
  Future<void> updateProfile(String userId,
      {String? name, String? email, String? cedula, String? phone}) async {
    try {
      // 1. Actualizar datos en la tabla profiles (DNI, Phone, etc.)
      if (name != null || cedula != null || phone != null) {
        // Pass cedula as string directly to 'dni'
        final response = await _supabase.functions.invoke(
          'auth-service/update-profile',
          body: {
            if (name != null) 'name': name.trim(),
            if (cedula != null) 'dni': cedula,
            if (phone != null) 'phone': phone.trim(),
          },
          method: HttpMethod.post,
        );

        if (response.status != 200) {
          final error = response.data['error'] ??
              'Error desconocido al actualizar perfil';
          throw error;
        }
      }

      // 2. Actualizar email en Supabase Auth si se provee
      if (email != null) {
        await _supabase.auth.updateUser(
          UserAttributes(email: email.trim()),
        );
      }
    } catch (e) {
      debugPrint('AuthService: Error updating profile: $e');
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
    if (errorMsg.contains('contraseña incorrecta')) {
      return 'Contraseña incorrecta. Por favor, verifica e intenta de nuevo.';
    }
    if (errorMsg.contains('cédula ya está registrada')) {
      return 'Esta cédula ya está registrada. Intenta con otra.';
    }
    if (errorMsg.contains('teléfono ya está registrado')) {
      return 'Este teléfono ya está registrado. Intenta con otro.';
    }
    if (errorMsg.contains('formato de cédula')) {
      return 'Formato de cédula inválido. Usa V12345678 o E12345678.';
    }
    if (errorMsg.contains('formato de teléfono')) {
      return 'Formato de teléfono inválido. Usa 04121234567.';
    }
    if (errorMsg.contains('user already registered') ||
        errorMsg.contains('already exists')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('profiles_id_fkey') ||
        errorMsg.contains('foreign key constraint')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (errorMsg.contains('is invalid') && errorMsg.contains('email')) {
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
    if (errorMsg.contains('aún no está activa')) {
      return 'Tu cuenta aún no está activa. Por favor, verifica tu correo electrónico.';
    }
    if (errorMsg.contains('rate limit') ||
        errorMsg.contains('too many requests')) {
      return 'Demasiados intentos. Por favor espera unos minutos antes de intentar de nuevo.';
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

  /// Agrega un método de pago vinculado al usuario.
  Future<void> addPaymentMethod({required String bankCode}) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/add-payment-method',
        body: {
          'bank_code': bankCode,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data['error'] ??
            'Error desconocido al guardar método de pago';
        throw error;
      }
    } catch (e) {
      debugPrint('AuthService: Error adding payment method: $e');
      throw _handleAuthError(e);
    }
  }

  /// Obtiene el perfil del usuario.
  Future<Player?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Player.fromJson(response);
    } catch (e) {
      debugPrint('AuthService: Error fetching profile: $e');
      return null;
    }
  }

  /// Elimina la cuenta del usuario actual.
  ///
  /// Invoca a la Edge Function 'auth-service/delete-account'.
  /// Si tiene éxito, el usuario es eliminado de la base de datos.
  Future<void> deleteAccount(String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/delete-account',
        body: {'password': password},
        method: HttpMethod.delete,
      );

      if (response.status != 200) {
        final error =
            response.data['error'] ?? 'Error desconocido al eliminar cuenta';
        throw error;
      }

      // La sesión se cierra automáticamente o debemos forzarlo
      await logout();
    } catch (e) {
      debugPrint('AuthService: Error deleting account: $e');
      throw _handleAuthError(e);
    }
  }

  /// Elimina un usuario siendo administrador.
  ///
  /// Invoca a la Edge Function 'auth-service/delete-user-admin'.
  Future<void> adminDeleteUser(String userId) async {
    try {
      final response = await _supabase.functions.invoke(
        'auth-service/delete-user-admin',
        body: {'user_id': userId},
        method: HttpMethod.delete,
      );

      if (response.status != 200) {
        final error = response.data['error'] ??
            'Error desconocido al eliminar usuario como admin';
        throw error;
      }
    } catch (e) {
      debugPrint('AuthService: Error in adminDeleteUser: $e');
      throw _handleAuthError(e);
    }
  }
}
