import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';

class PaymentMethodSelector extends StatelessWidget {
  final Function(String) onMethodSelected;

  const PaymentMethodSelector({
    super.key, 
    required this.onMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isDarkMode = playerProvider.isDarkMode;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.cardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: AppTheme.accentGold.withOpacity(0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2)
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Selecciona Método de Pago',
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildMethodTile(
            context,
            isDarkMode: isDarkMode,
            id: 'pago_movil',
            name: 'Pago Móvil / Transferencia',
            icon: Icons.phone_android,
            color: AppTheme.accentGold,
            description: 'Recarga instantánea en Bolívares'
          ),
          
          const SizedBox(height: 12),
          
          _buildMethodTile(
            context,
            isDarkMode: isDarkMode,
            id: 'crypto', // Placeholder
            name: 'Cripto (Próximamente)',
            icon: Icons.currency_bitcoin,
            color: Colors.grey,
            description: 'USDT, BTC, ETH',
            enabled: false,
          ),

          const SizedBox(height: 12),

          _buildMethodTile(
            context,
            isDarkMode: isDarkMode,
            id: 'zelle', // Placeholder
            name: 'Zelle (Próximamente)',
            icon: Icons.attach_money,
            color: Colors.grey,
            description: 'Recarga en Dólares',
            enabled: false,
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMethodTile(BuildContext context, {
    required bool isDarkMode,
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    required String description,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onMethodSelected(id) : null,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled ? color.withOpacity(0.3) : (isDarkMode ? Colors.white10 : Colors.black12),
              ),
              borderRadius: BorderRadius.circular(15),
              color: enabled ? color.withOpacity(0.05) : Colors.transparent,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: enabled ? color.withOpacity(0.2) : (isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: enabled ? color : (isDarkMode ? Colors.white24 : Colors.black12), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: enabled ? (isDarkMode ? Colors.white : const Color(0xFF1A1A1D)) : (isDarkMode ? Colors.white54 : Colors.black38),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: enabled ? (isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)) : (isDarkMode ? Colors.white24 : Colors.black12),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
