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
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _configService.getExchangeRate(),
        _configService.getGatewayFeePercentage(),
        _configService.isRechargeEnabled(),
      ]);
      _exchangeRateController.text = (results[0] as double).toStringAsFixed(2);
      _gatewayFeeController.text = (results[1] as double).toStringAsFixed(2);
      _rechargeEnabled = results[2] as bool;
    } catch (e) {
      debugPrint('[GlobalConfigScreen] Error loading config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
