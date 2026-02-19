import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/version_check_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class VersionMonitor extends StatefulWidget {
  final Widget child;

  const VersionMonitor({super.key, required this.child});

  @override
  State<VersionMonitor> createState() => _VersionMonitorState();
}

class _VersionMonitorState extends State<VersionMonitor> {
  late VersionCheckService _versionService;
  bool _isLoading = true;
  VersionStatus? _status;

  @override
  void initState() {
    super.initState();
    _versionService = VersionCheckService(Supabase.instance.client);
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final status = await _versionService.checkVersion();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchStore() async {
    if (_status?.storeUrl != null && _status!.storeUrl!.isNotEmpty) {
      final Uri url = Uri.parse(_status!.storeUrl!);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $_status!.storeUrl');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // While checking, we can show the child (splash) or a loading indicator.
      // Showing the child is better UX to avoid flashes, but if the check fails quickly, it's fine.
      // However, if we show child, user might start interacting.
      // Given check is fast, let's just show child (Splash Screen usually covers this time).
      return widget.child;
    }

    if (_status != null && _status!.isUpdateRequired) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_alt,
                    size: 80, color: AppTheme.accentGold),
                const SizedBox(height: 24),
                const Text(
                  '¡Actualización Requerida!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tu versión actual (${_status!.localVersion}) es antigua. Necesitas actualizar a la versión ${_status!.minVersion} o superior para seguir jugando.',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _launchStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ACTUALIZAR AHORA',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_status?.storeUrl == null || _status!.storeUrl!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Contacta al administrador para obtener el enlace de descarga.',
                      style: TextStyle(color: Colors.red[300], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (true) // In production, maybe check kDebugMode or allow secret gesture
                  TextButton(
                    onPressed: () {
                      setState(() {
                        // Force bypass
                        _status = null;
                        _isLoading = false;
                      });
                    },
                    child: const Text(
                      'Omitir (Desarrollador)',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
