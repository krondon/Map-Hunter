import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_config_service.dart';
import '../../wallet/models/withdrawal_plan.dart';
import '../../wallet/services/withdrawal_plan_service.dart';

/// Admin screen for managing withdrawal plans.
/// 
/// Allows editing clovers_cost, amount_usd, and is_active status.
/// Also displays and allows updating the BCV exchange rate.
class WithdrawalPlansManagementScreen extends StatefulWidget {
  const WithdrawalPlansManagementScreen({super.key});

  @override
  State<WithdrawalPlansManagementScreen> createState() => _WithdrawalPlansManagementScreenState();
}

class _WithdrawalPlansManagementScreenState extends State<WithdrawalPlansManagementScreen> {
  late WithdrawalPlanService _planService;
  late AppConfigService _configService;
  List<WithdrawalPlan> _plans = [];
  bool _isLoading = true;
  String? _error;
  
  // Exchange rate state
  double _exchangeRate = 0.0;
  bool _isLoadingRate = true;
  bool _isUpdatingRate = false;
  final _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _planService = WithdrawalPlanService(supabaseClient: Supabase.instance.client);
    _configService = AppConfigService(supabaseClient: Supabase.instance.client);
    _loadData();
  }
  
  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPlans(),
      _loadExchangeRate(),
    ]);
  }

  Future<void> _loadExchangeRate() async {
    setState(() => _isLoadingRate = true);
    try {
      final rate = await _configService.getExchangeRate();
      setState(() {
        _exchangeRate = rate;
        _rateController.text = rate.toStringAsFixed(2);
        _isLoadingRate = false;
      });
    } catch (e) {
      setState(() => _isLoadingRate = false);
    }
  }

  Future<void> _updateExchangeRate() async {
    final newRate = double.tryParse(_rateController.text);
    if (newRate == null || newRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una tasa válida'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isUpdatingRate = true);
    final success = await _configService.updateExchangeRate(newRate);
    setState(() => _isUpdatingRate = false);
    
    if (mounted) {
      if (success) {
        setState(() => _exchangeRate = newRate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tasa actualizada a $newRate Bs/USD'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar la tasa'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plans = await _planService.fetchAllPlans();
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePlan(WithdrawalPlan plan, {int? cloversCost, double? amountUsd, bool? isActive}) async {
    try {
      await _planService.updatePlan(
        plan.id,
        cloversCost: cloversCost,
        amountUsd: amountUsd,
        isActive: isActive,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan "${plan.name}" actualizado'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadPlans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  void _showEditDialog(WithdrawalPlan plan) {
    final cloversController = TextEditingController(text: plan.cloversCost.toString());
    final amountController = TextEditingController(text: plan.amountUsd.toStringAsFixed(2));
    bool isActive = plan.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                Text(plan.icon ?? '💸', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(
                  'Editar ${plan.name}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clovers Cost
                  const Text('Costo en Tréboles', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cloversController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      suffixText: '🍀',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.accentGold),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount USD
                  const Text('Monto a Recibir (USD)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: const TextStyle(color: AppTheme.accentGold),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.accentGold),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // VES Preview
                  if (_exchangeRate > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Al usuario se le enviará: \$${(double.tryParse(amountController.text) ?? 0) * _exchangeRate} VES',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Active Toggle
                  SwitchListTile(
                    title: const Text('Plan Activo', style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      isActive ? 'Visible para usuarios' : 'Oculto para usuarios',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    value: isActive,
                    activeColor: AppTheme.accentGold,
                    onChanged: (value) => setState(() => isActive = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () {
                  final newClovers = int.tryParse(cloversController.text);
                  final newAmount = double.tryParse(amountController.text);
                  
                  if (newClovers == null || newClovers <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Costo en tréboles inválido')),
                    );
                    return;
                  }
                  
                  if (newAmount == null || newAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Monto USD inválido')),
                    );
                    return;
                  }
                  
                  Navigator.pop(ctx);
                  _updatePlan(
                    plan,
                    cloversCost: newClovers,
                    amountUsd: newAmount,
                    isActive: isActive,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Planes de Retiro',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Exchange Rate Card
                    _buildExchangeRateCard(),
                    const SizedBox(height: 24),
                    // Section Title
                    const Text(
                      'Planes Disponibles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Plans List
                    ..._plans.map((plan) => _buildPlanCard(plan)),
                  ],
                ),
    );
  }

  Widget _buildExchangeRateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentGold.withOpacity(0.2),
            AppTheme.accentGold.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.currency_exchange, color: AppTheme.accentGold, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasa de Cambio BCV', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('USD → VES para retiros', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingRate)
            const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_exchangeRate.toStringAsFixed(2)} Bs/USD',
                    style: const TextStyle(color: AppTheme.accentGold, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nueva Tasa',
                    labelStyle: const TextStyle(color: Colors.white60),
                    prefixText: 'Bs ',
                    prefixStyle: const TextStyle(color: AppTheme.accentGold),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppTheme.accentGold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isUpdatingRate ? null : _updateExchangeRate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
                child: _isUpdatingRate 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Actualizar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(WithdrawalPlan plan) {
    // Calculate VES preview
    final vesAmount = plan.amountUsd * _exchangeRate;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isActive 
              ? AppTheme.accentGold.withOpacity(0.3) 
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: plan.isActive 
                  ? AppTheme.accentGold.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(plan.icon ?? '💸', style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        color: plan.isActive ? Colors.white : Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!plan.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('INACTIVO', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Costo: ${plan.cloversCost} 🍀',
                  style: TextStyle(
                    color: plan.isActive ? Colors.white70 : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Recibe: ${vesAmount.toStringAsFixed(2)} VES',
                  style: TextStyle(
                    color: plan.isActive ? Colors.white54 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount USD
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.formattedAmountUsd,
                style: TextStyle(
                  color: plan.isActive ? AppTheme.accentGold : Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('USD', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 8),
          
          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white54),
            onPressed: () => _showEditDialog(plan),
            tooltip: 'Editar',
          ),
        ],
      ),
    );
  }
}
