import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../wallet/models/clover_plan.dart';
import '../../wallet/services/clover_plan_service.dart';

/// Admin screen for managing clover purchase plans.
/// 
/// Allows editing price_usd, clovers_quantity, and is_active status.
class CloverPlansManagementScreen extends StatefulWidget {
  const CloverPlansManagementScreen({super.key});

  @override
  State<CloverPlansManagementScreen> createState() => _CloverPlansManagementScreenState();
}

class _CloverPlansManagementScreenState extends State<CloverPlansManagementScreen> {
  late CloverPlanService _planService;
  List<CloverPlan> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _planService = CloverPlanService(supabaseClient: Supabase.instance.client);
    _loadPlans();
  }


  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use fetchAllPlans for admin (includes inactive)
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

  Future<void> _updatePlan(CloverPlan plan, {double? priceUsd, int? cloversQuantity, bool? isActive}) async {
    try {
      await _planService.updatePlan(
        plan.id,
        priceUsd: priceUsd,
        cloversQuantity: cloversQuantity,
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

  void _showEditDialog(CloverPlan plan) {
    final priceController = TextEditingController(text: plan.priceUsd.toStringAsFixed(2));
    final cloversController = TextEditingController(text: plan.cloversQuantity.toString());
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
                Text(
                  plan.iconUrl ?? '🍀',
                  style: const TextStyle(fontSize: 24),
                ),
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
                  // Price USD
                  const Text('Precio (USD)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
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
                  
                  // Clovers Quantity
                  const Text('Cantidad de Tréboles', style: TextStyle(color: Colors.white70)),
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
                  final newPrice = double.tryParse(priceController.text);
                  final newClovers = int.tryParse(cloversController.text);
                  
                  if (newPrice == null || newPrice <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Precio inválido')),
                    );
                    return;
                  }
                  
                  if (newClovers == null || newClovers <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cantidad inválida')),
                    );
                    return;
                  }
                  
                  Navigator.pop(ctx);
                  _updatePlan(
                    plan,
                    priceUsd: newPrice,
                    cloversQuantity: newClovers,
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
          'Gestión de Planes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPlans,
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
                        onPressed: _loadPlans,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section Title
                    const Text(
                      'Planes de Tréboles',
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

  Widget _buildPlanCard(CloverPlan plan) {
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
              child: Text(
                plan.iconUrl ?? '🍀',
                style: const TextStyle(fontSize: 28),
              ),
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
                        child: const Text(
                          'INACTIVO',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.cloversQuantity} Tréboles',
                  style: TextStyle(
                    color: plan.isActive ? Colors.white70 : Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.formattedPrice,
                style: TextStyle(
                  color: plan.isActive ? AppTheme.accentGold : Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'USD',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
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
