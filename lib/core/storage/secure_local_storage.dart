import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementación segura del almacenamiento local para Supabase Auth.
/// Utiliza Keychain (iOS) y Keystore (Android) para encriptar el tokens.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage()
      : super(
          initialize: () async {},
          hasAccessToken: () {
            const storage = FlutterSecureStorage();
            return storage.containsKey(key: supabasePersistSessionKey);
          },
          accessToken: () {
            const storage = FlutterSecureStorage();
            return storage.read(key: supabasePersistSessionKey);
          },
          removePersistedSession: () {
            const storage = FlutterSecureStorage();
            return storage.delete(key: supabasePersistSessionKey);
          },
          persistSession: (String persistSessionString) {
            const storage = FlutterSecureStorage();
            return storage.write(
                key: supabasePersistSessionKey, value: persistSessionString);
          },
        );

  static const supabasePersistSessionKey = 'supabase_persist_session';
}
