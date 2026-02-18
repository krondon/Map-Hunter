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
  late RealtimeChannel _subscription;
  int _currentPot = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bettingService = BettingService(Supabase.instance.client);
    _fetchPot();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription.unsubscribe();
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

  void _subscribe() {
    _subscription = _bettingService.subscribeToBets(widget.eventId, () {
      _fetchPot(); // Refresh on any change
    });
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
      onLongPress: _showDebugInfo, // Hidden debug feature
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dGoldMain.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dGoldMain.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "POTE DE APUESTAS",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              _isLoading
                  ? SizedBox(
                      width: 100,
                      height: 20,
                      child: LinearProgressIndicator(
                          color: AppTheme.dGoldMain, backgroundColor: Colors.white10),
                    )
                  : Text(
                      "$formattedPot 🍀",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        shadows: [
                          Shadow(
                              color: AppTheme.dGoldMain.withOpacity(0.8),
                              blurRadius: 8)
                        ],
                      ),
                    ),
            ],
          ),
        ],
      ),
    ));
  }
}
