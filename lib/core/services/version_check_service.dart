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

      // 2. Get remote config
      // Note: We use .single() assuming there's only one active config row.
      // If you have multiple rows, you might need to order by created_at or use a specific ID.
      final response = await supabaseClient
          .from('app_config')
          .select('value')
          .eq('key', 'version_configuration')
          .maybeSingle();

      if (response == null || response['value'] == null) {
        debugPrint('VersionCheck: No version_configuration found in Supabase.');
        return VersionStatus(
          isUpdateRequired: false,
          localVersion: localVersion,
          minVersion: '0.0.0',
          storeUrl: '',
        );
      }

      final data = response['value'];

      final String minVersion =
          data['min_supported_version'] as String? ?? '0.0.0';
      final String? androidUrl = data['android_store_url'] as String?;
      final String? iosUrl = data['ios_store_url'] as String?;

      // 3. Compare versions
      final bool updateRequired = _isUpdateRequired(localVersion, minVersion);

      debugPrint(
          'VersionCheck: Required: $minVersion. Update needed: $updateRequired');

      return VersionStatus(
        isUpdateRequired: updateRequired,
        localVersion: localVersion,
        minVersion: minVersion,
        storeUrl:
            defaultTargetPlatform == TargetPlatform.iOS ? iosUrl : androidUrl,
      );
    } catch (e) {
      debugPrint('VersionCheck: Error checking version: $e');
      // In case of error (e.g. offline), we usually want to let the user in (fail open)
      // unless it's critical. For now, fail open.
      return VersionStatus(
        isUpdateRequired: false,
        localVersion: 'Unknown',
        minVersion: 'Unknown',
        storeUrl: null,
      );
    }
  }

  bool _isUpdateRequired(String local, String min) {
    List<int> localParts =
        local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> minParts =
        min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad with zeros if lengths differ (though usually they are x.y.z)
    int maxLength = localParts.length > minParts.length
        ? localParts.length
        : minParts.length;

    for (int i = 0; i < maxLength; i++) {
      int l = i < localParts.length ? localParts[i] : 0;
      int m = i < minParts.length ? minParts[i] : 0;

      if (l < m) return true; // Local is strictly less than min
      if (l > m) return false; // Local is strictly greater than min
    }

    return false; // Equal
  }
}

class VersionStatus {
  final bool isUpdateRequired;
  final String localVersion;
  final String minVersion;
  final String? storeUrl;

  VersionStatus({
    required this.isUpdateRequired,
    required this.localVersion,
    required this.minVersion,
    this.storeUrl,
  });
}
