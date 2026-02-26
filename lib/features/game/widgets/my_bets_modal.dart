import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../services/betting_service.dart';
import '../../../shared/widgets/coin_image.dart';

class MyBetsModal extends StatefulWidget {
  final String eventId;
  const MyBetsModal({super.key, required this.eventId});

  @override
  State<MyBetsModal> createState() => _MyBetsModalState();
}

class _MyBetsModalState extends State<MyBetsModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bets = [];

  @override
  void initState() {
    super.initState();
    _loadBets();
  }

  Future<void> _loadBets() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.userId;
    if (userId == null) return;

    final bettingService = BettingService(Supabase.instance.client);
    final bets = await bettingService.fetchUserBets(widget.eventId, userId);
    
    if (mounted) {
      setState(() {
        _bets = bets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Mis Apuestas Activas",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(color: Colors.white12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                : _bets.isEmpty
                    ? const Center(
                        child: Text(
                          "No has realizado apuestas en este evento.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bets.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final bet = _bets[index];
                          final amount = bet['amount'];
                          final racerName = bet['profiles']?['name'] ?? 'Corredor Desconocido';
                          // Parse date if needed, or just show amount/racer

                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.accentGold,
                                child: Text('🎫'),
                              ),
                              title: Text(
                                racerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    'Apuesta: $amount ',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const CoinImage(size: 14),
                                ],
                              ),
                              trailing: const Icon(Icons.check_circle, color: Colors.green),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
 