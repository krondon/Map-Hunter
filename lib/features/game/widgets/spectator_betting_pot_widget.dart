import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../services/betting_service.dart';
import 'package:intl/intl.dart';

class SpectatorBettingPotWidget extends StatefulWidget {
  final String eventId;

  const SpectatorBettingPotWidget({super.key, required this.eventId});

  @override
  State<SpectatorBettingPotWidget> createState() => _SpectatorBettingPotWidgetState();
}

class _SpectatorBettingPotWidgetState extends State<SpectatorBettingPotWidget> {
  late BettingService _bettingService;
  Timer? _pollTimer;
  int _currentPot = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bettingService = BettingService(Supabase.instance.client);
    _fetchPot();
    // Poll every 10 seconds — lightweight RPC call (single aggregated row).
    // Replaces Realtime subscription which no longer delivers other users'
    // bet events after the permissive RLS policy was removed.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchPot());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPot() async {
    final pot = await _bettingService.getEventBettingPot(widget.eventId);
    if (mounted) {
      setState(() {
        _currentPot = pot;
        _isLoading = false;
      });
    }
  }

  Future<void> _showDebugInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('debug_betting_status', params: {'p_event_id': widget.eventId});
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Info'),
            content: SingleChildScrollView(child: Text(response.toString())),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedPot = NumberFormat.currency(locale: "es_CO", symbol: "", decimalDigits: 0).format(_currentPot);

    return GestureDetector(
      onLongPress: _showDebugInfo,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(4), // Espacio para el efecto de doble borde
        decoration: BoxDecoration(
          color: AppTheme.dGoldMain.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.dGoldMain.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.dGoldMain.withOpacity(0.5),
                  width: 2, // Borde sólido interno tipo "Profile"
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "POTE DE APUESTAS",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _isLoading
                          ? SizedBox(
                              width: 100,
                              height: 20,
                              child: LinearProgressIndicator(
                                color: AppTheme.dGoldMain,
                                backgroundColor: Colors.white10,
                              ),
                            )
                          : Text(
                              "$formattedPot 🍀",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                                shadows: [
                                  Shadow(
                                    color: AppTheme.dGoldMain.withOpacity(0.8),
                                    blurRadius: 12,
                                  )
                                ],
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
