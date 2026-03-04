import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class VersionCheckService {
  final SupabaseClient supabaseClient;

  VersionCheckService(this.supabaseClient);

  Future<VersionStatus> checkVersion() async {
    try {
      // 1. Get local app version
      final packageInfo = await PackageInfo.fromPlatform();
      final String localVersion = packageInfo.version;

      debugPrint('VersionCheck: Local version is $localVersion');

      // 2. Get remote config from Supabase app_config
      final response = await supabaseClient
          .from('app_config')
          .select('value')
          .eq('key', 'version_configuration')
          .maybeSingle();

      if (response == null || response['value'] == null) {
        debugPrint('VersionCheck: No version_configuration found in Supabase.');
        return VersionStatus(
          isUpdateRequired: false,
          maintenanceMode: false,
          localVersion: localVersion,
          minVersion: '0.0.0',
          downloadUrl: null,
        );
      }

      final data = response['value'];

      final String minVersion =
          data['min_supported_version'] as String? ?? '0.0.0';
      final bool maintenanceMode =
          data['maintenance_mode'] as bool? ?? false;

      // 3. Selección de URL según plataforma:
      //    iOS              → ios_store_url  (App Store)
      //    Android en Store → android_store_url (Play Store)
      //    Android APK      → apk_download_url  (descarga directa)
      //    Web              → no aplica actualización forzada
      String? downloadUrl;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosUrl = data['ios_store_url'] as String?;
        downloadUrl = (iosUrl != null && iosUrl.isNotEmpty) ? iosUrl : null;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final storeUrl = data['android_store_url'] as String?;
        final apkUrl   = data['apk_download_url']  as String?;
        // Si ya está en Play Store usa esa URL; si no, descarga directa
        downloadUrl = (storeUrl != null && storeUrl.isNotEmpty)
            ? storeUrl
            : ((apkUrl != null && apkUrl.isNotEmpty) ? apkUrl : null);
      }
      // En web no forzamos descarga

      // 4. Compare versions
      final bool updateRequired = _isUpdateRequired(localVersion, minVersion);

      debugPrint(
          'VersionCheck: minVersion=$minVersion, local=$localVersion, '
          'updateRequired=$updateRequired, maintenance=$maintenanceMode');

      return VersionStatus(
        isUpdateRequired: updateRequired,
        maintenanceMode: maintenanceMode,
        localVersion: localVersion,
        minVersion: minVersion,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('VersionCheck: Error checking version: $e');
      // Fail open: si no hay conexión, dejamos entrar al usuario.
      return VersionStatus(
        isUpdateRequired: false,
        maintenanceMode: false,
        localVersion: 'Unknown',
        minVersion: 'Unknown',
        downloadUrl: null,
      );
    }
  }

  bool _isUpdateRequired(String local, String min) {
    List<int> localParts =
        local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> minParts =
        min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLength = localParts.length > minParts.length
        ? localParts.length
        : minParts.length;

    for (int i = 0; i < maxLength; i++) {
      int l = i < localParts.length ? localParts[i] : 0;
      int m = i < minParts.length ? minParts[i] : 0;

      if (l < m) return true;  // versión local menor que la mínima
      if (l > m) return false; // versión local mayor
    }

    return false; // iguales
  }
}

class VersionStatus {
  final bool isUpdateRequired;
  final bool maintenanceMode;
  final String localVersion;
  final String minVersion;
  final String? downloadUrl;

  VersionStatus({
    required this.isUpdateRequired,
    required this.maintenanceMode,
    required this.localVersion,
    required this.minVersion,
    this.downloadUrl,
  });
}
