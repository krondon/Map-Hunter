import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PowerEffectProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _subscription;
  Timer? _expiryTimer;
  
  // Guardamos el slug del poder activo (ej: 'black_screen', 'freeze')
  String? _activePowerSlug;
  String? get activePowerSlug => _activePowerSlug;

  // Iniciar la escucha de ataques dirigidos a este jugador específico
  void startListening(String myGamePlayerId) {
    _subscription?.cancel();
    _expiryTimer?.cancel();

    _subscription = _supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('target_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) {
          _processEffects(data);
        });
  }

  void _processEffects(List<Map<String, dynamic>> data) {
    _expiryTimer?.cancel(); // Limpiar temporizadores previos

    if (data.isEmpty) {
      _activePowerSlug = null;
      notifyListeners();
      return;
    }

    // Buscamos el efecto más reciente que aún no haya expirado
    final now = DateTime.now().toUtc();
    final validEffects = data.where((effect) {
      final expiresAt = DateTime.parse(effect['expires_at']);
      return expiresAt.isAfter(now);
    }).toList();

    if (validEffects.isEmpty) {
      _activePowerSlug = null;
    } else {
      // Tomamos el efecto más reciente
      final latestEffect = validEffects.last;
      _activePowerSlug = latestEffect['power_slug'];
      
      // Programamos la limpieza automática para el momento exacto de la expiración
      final expiresAt = DateTime.parse(latestEffect['expires_at']);
      final durationRemaining = expiresAt.difference(now);
      
      _expiryTimer = Timer(durationRemaining, () {
        _activePowerSlug = null;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}