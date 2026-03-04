import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_config_service.dart';

/// Admin screen for managing global application configuration.
/// 
/// Handles:
/// - BCV Exchange Rate (USD -> VES)
/// - Gateway Fee Percentage (for visual display in app)
class GlobalConfigScreen extends StatefulWidget {
  const GlobalConfigScreen({super.key});

  @override
  State<GlobalConfigScreen> createState() => _GlobalConfigScreenState();
}

class _GlobalConfigScreenState extends State<GlobalConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _exchangeRateController = TextEditingController();
  final _gatewayFeeController = TextEditingController();

  // Version config
  final _latestVersionController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _apkUrlController = TextEditingController();
  final _androidStoreUrlController = TextEditingController();
  final _iosStoreUrlController = TextEditingController();
  bool _maintenanceMode = false;
  bool _isSavingVersion = false;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _rechargeEnabled = true;
  bool _isTogglingRecharge = false;

  late final AppConfigService _configService;

  @override
  void initState() {
    super.initState();
    _configService = AppConfigService(supabaseClient: Supabase.instance.client);
    _loadConfig();
  }

  @override
  void dispose() {
    _exchangeRateController.dispose();
    _gatewayFeeController.dispose();
    _latestVersionController.dispose();
    _minVersionController.dispose();
    _apkUrlController.dispose();
    _androidStoreUrlController.dispose();
    _iosStoreUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _configService.getExchangeRate(),
        _configService.getGatewayFeePercentage(),
        _configService.isRechargeEnabled(),
        _configService.getVersionConfig(),
      ]);
      _exchangeRateController.text = (results[0] as double).toStringAsFixed(2);
      _gatewayFeeController.text = (results[1] as double).toStringAsFixed(2);
      _rechargeEnabled = results[2] as bool;

      final versionCfg = results[3] as Map<String, dynamic>;
      _latestVersionController.text =
          versionCfg['latest_version'] as String? ?? '1.0.0';
      _minVersionController.text =
          versionCfg['min_supported_version'] as String? ?? '1.0.0';
      _apkUrlController.text =
          versionCfg['apk_download_url'] as String? ?? '';
      _androidStoreUrlController.text =
          versionCfg['android_store_url'] as String? ?? '';
      _iosStoreUrlController.text =
          versionCfg['ios_store_url'] as String? ?? '';
      _maintenanceMode = versionCfg['maintenance_mode'] as bool? ?? false;
    } catch (e) {
      debugPrint('[GlobalConfigScreen] Error loading config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveVersionConfig() async {
    // Validate semver format x.y.z
    final semverRegex = RegExp(r'^\d+\.\d+\.\d+$');
    if (!semverRegex.hasMatch(_latestVersionController.text.trim()) ||
        !semverRegex.hasMatch(_minVersionController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formato inválido. Usa x.y.z (ej: 1.0.1)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingVersion = true);
    final success = await _configService.updateVersionConfig({
      'latest_version': _latestVersionController.text.trim(),
      'min_supported_version': _minVersionController.text.trim(),
      'apk_download_url': _apkUrlController.text.trim(),
      'android_store_url': _androidStoreUrlController.text.trim(),
      'ios_store_url': _iosStoreUrlController.text.trim(),
      'maintenance_mode': _maintenanceMode,
    });
    if (mounted) {
      setState(() => _isSavingVersion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Versión actualizada correctamente'
              : 'Error al guardar la versión'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleRecharge(bool value) async {
    setState(() => _isTogglingRecharge = true);
    final success = await _configService.setRechargeEnabled(value);
    if (mounted) {
      setState(() {
        if (success) _rechargeEnabled = value;
        _isTogglingRecharge = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (value ? 'Recarga habilitada' : 'Recarga en mantenimiento')
              : 'Error al cambiar estado de recarga'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final exchangeRate = double.parse(_exchangeRateController.text);
      final gatewayFee = double.parse(_gatewayFeeController.text);
      
      final rateSuccess = await _configService.updateExchangeRate(exchangeRate);
      final feeSuccess = await _configService.updateGatewayFeePercentage(gatewayFee);
      
      if (mounted) {
        if (rateSuccess && feeSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuración guardada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar configuración'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPurple),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Configuración Global',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configuraciones que afectan el funcionamiento de la aplicación.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 32),

            // Exchange Rate Section
            _buildConfigCard(
              title: 'Tasa de Cambio BCV',
              subtitle: 'Tasa USD → VES para cálculo de retiros',
              icon: Icons.currency_exchange,
              child: TextFormField(
                controller: _exchangeRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Ej: 56.50',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixText: 'Bs. ',
                  prefixStyle: const TextStyle(color: AppTheme.accentGold),
                  suffixText: 'por 1 USD',
                  suffixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryPurple),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) return 'Ingrese un valor válido';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 24),

            // Gateway Fee Section
            _buildConfigCard(
              title: 'Comisión de Pasarela (Visualización)',
              subtitle: 'Porcentaje de comisión de Pago a Pago',
              icon: Icons.percent,
              warning: 'Este valor debe coincidir con la comisión configurada en Pago a Pago '
                  'para mostrar el estimado correcto al usuario.',
              child: TextFormField(
                controller: _gatewayFeeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Ej: 3.0',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  suffixText: '%',
                  suffixStyle: const TextStyle(color: AppTheme.accentGold, fontSize: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryPurple),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0) return 'Ingrese un valor válido (0 o más)';
                  if (parsed > 100) return 'El porcentaje no puede ser mayor a 100';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 24),

            // Recharge Maintenance Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _rechargeEnabled
                      ? Colors.white.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_rechargeEnabled
                              ? Colors.green
                              : Colors.orange)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _rechargeEnabled
                          ? Icons.add_card
                          : Icons.construction,
                      color: _rechargeEnabled ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Botón de Recarga',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _rechargeEnabled
                              ? 'Disponible — los usuarios pueden recargar'
                              : 'En mantenimiento — botón deshabilitado',
                          style: TextStyle(
                            color: _rechargeEnabled
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isTogglingRecharge
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryPurple,
                          ),
                        )
                      : Switch(
                          value: _rechargeEnabled,
                          onChanged: _toggleRecharge,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.orange,
                          inactiveTrackColor: Colors.orange.withOpacity(0.3),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Version Configuration Section
            _buildVersionCard(),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'GUARDAR CONFIGURACIÓN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update_alt,
                    color: AppTheme.primaryPurple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Control de Versiones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fuerza actualizaciones y administra la URL de descarga del APK',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'La "Versión mínima" es la que bloquea usuarios con APK antigua. '
                    '"Versión publicada" es solo informativa. '
                    'Ambas usan formato x.y.z (ej: 1.0.1).',
                    style: TextStyle(
                        color: Colors.blue.shade200, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Latest version
          _buildVersionField(
            controller: _latestVersionController,
            label: 'Versión publicada',
            hint: '1.0.0',
            helper: 'Versión del APK que subiste al servidor',
          ),

          const SizedBox(height: 16),

          // Min supported version
          _buildVersionField(
            controller: _minVersionController,
            label: 'Versión mínima requerida',
            hint: '1.0.0',
            helper: 'Los APKs más antiguos quedarán bloqueados',
            accentColor: AppTheme.accentGold,
          ),

          const SizedBox(height: 16),

          // ── Descarga directa APK ──────────────────────────────────
          _buildUrlField(
            controller: _apkUrlController,
            label: 'URL descarga APK (Android sin Store)',
            hint: 'https://tudominio.com/download/app.apk',
            icon: Icons.android_rounded,
            iconColor: Colors.green,
          ),

          const SizedBox(height: 16),

          // ── Store URLs (opcionales, solo cuando estén publicadas) ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store_rounded,
                        color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'URLs de tiendas oficiales (opcional)',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Déjalas vacías hasta que la app esté publicada en cada tienda. '
                  'Cuando tengan valor, tienen prioridad sobre la URL del APK.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 11),
                ),
                const SizedBox(height: 14),
                _buildUrlField(
                  controller: _androidStoreUrlController,
                  label: 'Play Store URL (Android)',
                  hint:
                      'https://play.google.com/store/apps/details?id=com.map.hunter',
                  icon: Icons.shop_rounded,
                  iconColor: Colors.green.shade400,
                ),
                const SizedBox(height: 12),
                _buildUrlField(
                  controller: _iosStoreUrlController,
                  label: 'App Store URL (iOS)',
                  hint: 'https://apps.apple.com/app/idXXXXXXXXX',
                  icon: Icons.apple_rounded,
                  iconColor: Colors.white70,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Maintenance mode toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _maintenanceMode
                  ? Colors.orange.withOpacity(0.08)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _maintenanceMode
                    ? Colors.orange.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.construction_rounded,
                  color: _maintenanceMode ? Colors.orange : Colors.white38,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modo Mantenimiento',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _maintenanceMode
                            ? 'Activo — todos los usuarios ven pantalla de mantenimiento'
                            : 'Inactivo — la app funciona normalmente',
                        style: TextStyle(
                          color: _maintenanceMode
                              ? Colors.orange.shade300
                              : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _maintenanceMode,
                  onChanged: (v) => setState(() => _maintenanceMode = v),
                  activeColor: Colors.orange,
                  inactiveThumbColor: Colors.white38,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Save version button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSavingVersion ? null : _saveVersionConfig,
              icon: _isSavingVersion
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 20),
              label: const Text('GUARDAR VERSIÓN',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
        prefixIcon: Icon(icon, color: iconColor ?? Colors.white38, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryPurple),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
      ),
    );
  }

  Widget _buildVersionField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.primaryPurple;
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
        helperText: helper,
        helperStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        prefixIcon: Icon(Icons.tag_rounded, color: color.withOpacity(0.7), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    String? warning,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryPurple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        color: Colors.amber.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
