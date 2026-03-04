import 'package:flutter/foundation.dart';
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

  Future<void> _launchDownload() async {
    final url = _status?.downloadUrl;
    if (url != null && url.isNotEmpty) {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('VersionMonitor: No se pudo abrir $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Mientras se verifica mostramos el child (usualmente el SplashScreen lo cubre)
      return widget.child;
    }

    // 1. Modo mantenimiento: bloquea por completo sin ofrecer descarga
    if (_status != null && _status!.maintenanceMode) {
      return _buildBlockScreen(
        icon: Icons.construction_rounded,
        iconColor: Colors.orange,
        title: 'En Mantenimiento',
        message:
            'La aplicación está en mantenimiento temporalmente. Intenta nuevamente en unos minutos.',
        showDownloadButton: false,
      );
    }

    // 2. Actualización requerida: versión local < mínima
    if (_status != null && _status!.isUpdateRequired) {
      return _buildBlockScreen(
        icon: Icons.system_update_alt,
        iconColor: AppTheme.accentGold,
        title: '¡Actualización Requerida!',
        message:
            'Tu versión actual (${_status!.localVersion}) ya no es compatible. '
            'Descarga la versión ${_status!.minVersion} o superior para seguir jugando.',
        showDownloadButton: true,
      );
    }

    return widget.child;
  }

  Widget _buildBlockScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required bool showDownloadButton,
  }) {
    final hasUrl =
        _status?.downloadUrl != null && _status!.downloadUrl!.isNotEmpty;

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
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (showDownloadButton) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: hasUrl ? _launchDownload : null,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text(
                      'DESCARGAR NUEVA VERSIÓN',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (!hasUrl)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Contacta al administrador para obtener el enlace de descarga.',
                      style: TextStyle(color: Colors.red[300], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              // Botón de bypass solo en modo debug
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _isLoading = false;
                      });
                    },
                    child: const Text(
                      'Omitir (Desarrollador)',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
