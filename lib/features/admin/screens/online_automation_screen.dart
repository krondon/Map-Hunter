import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_config_service.dart';

class OnlineAutomationScreen extends StatefulWidget {
  const OnlineAutomationScreen({super.key});

  @override
  State<OnlineAutomationScreen> createState() => _OnlineAutomationScreenState();
}

class _OnlineAutomationScreenState extends State<OnlineAutomationScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _config = {};
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final configService = AppConfigService(supabaseClient: _supabase);
    final settings = await configService.getAutoEventSettings();
    setState(() {
      _config = settings;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final configService = AppConfigService(supabaseClient: _supabase);
      final success = await configService.updateAutoEventSettings(_config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? 'Configuración guardada' : 'Error al guardar'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving config: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerManual() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'automate-online-events',
        body: {'trigger': 'manual'},
      );

      final data = response.data;
      final bool isSuccess =
          response.status == 200 && (data is Map && data['success'] == true);

      if (mounted) {
        final cluesCount = data is Map ? data['cluesSaved'] ?? 0 : 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSuccess
                ? 'Evento generado con $cluesCount minijuegos'
                : 'Error: ${data?['error'] ?? 'Fallo en la generación'}'),
            backgroundColor: isSuccess ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error de red: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildToggleCard(),
                  const SizedBox(height: 20),
                  _buildSettingsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automatización Online',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              'Configura la creación automática de competencias.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _triggerManual,
          icon: const Icon(Icons.flash_on),
          label: const Text('Generar Ahora'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryPink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard() {
    final bool isEnabled = _config['enabled'] == true;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isEnabled ? AppTheme.primaryPurple : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              color: isEnabled ? AppTheme.primaryPurple : Colors.white24,
              size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnabled
                      ? 'Automatización ACTIVA'
                      : 'Automatización DESACTIVADA',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Si está activa, el sistema generará eventos según el intervalo definido.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (val) {
              setState(() => _config['enabled'] = val);
              _saveConfig();
            },
            activeColor: AppTheme.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parámetros de Generación',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save, color: AppTheme.primaryPurple)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSlider('Intervalo (minutos)', 'interval_minutes', 10, 1440, 1),
          _buildSlider('Copa Mín. Jugadores', 'min_players', 2, 20, 1),
          _buildSlider('Copa Máx. Jugadores', 'max_players', 20, 50, 1),
          _buildSlider('Cant. Mín. Minijuegos', 'min_games', 2, 6, 1),
          _buildSlider('Cant. Máx. Minijuegos', 'max_games', 6, 15, 1),
          _buildSlider('Entry Fee Mín (🍀)', 'min_fee', 0, 50, 5),
          _buildSlider('Entry Fee Máx (🍀)', 'max_fee', 50, 200, 5),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label, String key, double min, double max, double divisions) {
    final value = (_config[key] as num?)?.toDouble() ?? min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(value.toInt().toString(),
                style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / (divisions)).toInt(),
          activeColor: AppTheme.primaryPurple,
          inactiveColor: Colors.white10,
          onChanged: (val) => setState(() => _config[key] = val.toInt()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
