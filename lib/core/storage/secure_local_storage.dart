import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementación segura del almacenamiento local para Supabase Auth.
/// Utiliza Keychain (iOS), Keystore (Android) y libsecret (Linux) para encriptar el tokens.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage();

  static const supabasePersistSessionKey = 'supabase_persist_session';
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    // No initialization needed for flutter_secure_storage
  }

  @override
  Future<bool> hasAccessToken() async {
    return _storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    return _storage.delete(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    return _storage.write(
        key: supabasePersistSessionKey, value: persistSessionString);
  }
}
