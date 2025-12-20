import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PowerEffectProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _subscription;
  Timer? _expiryTimer;
  Timer? _defenseFeedbackTimer;
  bool _shieldActive = false;
  String? _listeningForId;
  bool _returnArmed = false;
  Future<bool> Function(String powerSlug, String targetGamePlayerId)? _returnHandler;
  DefenseAction? _lastDefenseAction;
  DateTime? _lastDefenseActionAt;
  
  // Guardamos el slug del poder activo (ej: 'black_screen', 'freeze')
  String? _activePowerSlug;
  String? _activeEffectId;
  String? _activeEffectCasterId;

  String? get activePowerSlug => _activePowerSlug;
  String? get activeEffectId => _activeEffectId;
  String? get activeEffectCasterId => _activeEffectCasterId;
  DefenseAction? get lastDefenseAction => _lastDefenseAction;

  void setShielded(bool value, {String? sourceSlug}) {
    final shouldEnable = value || _isShieldSlug(sourceSlug);
    _shieldActive = shouldEnable;

    // Si activamos el escudo, limpiamos cualquier efecto activo.
    if (_shieldActive) {
      _clearEffect();
    } else {
      notifyListeners();
    }
  }

  void armReturn() {
    _returnArmed = true;
  }

  void configureReturnHandler(
      Future<bool> Function(String powerSlug, String targetGamePlayerId) handler) {
    _returnHandler = handler;
  }

  // Iniciar la escucha de ataques dirigidos a este jugador específico
  void startListening(String? myGamePlayerId) {
    if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
      _clearEffect();
      _subscription?.cancel();
      return;
    }

    _subscription?.cancel();
    _expiryTimer?.cancel();
    _listeningForId = myGamePlayerId;

    _subscription = _supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('target_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
          await _processEffects(data);
        }, onError: (e) {
          debugPrint('PowerEffectProvider stream error: $e');
        });
  }

  Future<void> _processEffects(List<Map<String, dynamic>> data) async {
    _expiryTimer?.cancel(); // Limpiar temporizadores previos

    if (data.isEmpty) {
      _clearEffect();
      return;
    }

    // Filtro adicional por target para evitar overlays en el atacante u oyentes stale
    final filtered = data.where((effect) {
      final targetId = effect['target_id'];
      return _listeningForId != null && targetId == _listeningForId;
    }).toList();

    if (filtered.isEmpty) {
      _clearEffect();
      return;
    }

    // Buscamos el efecto más reciente que aún no haya expirado
    final now = DateTime.now().toUtc();
    final validEffects = filtered.where((effect) {
      final expiresAt = DateTime.parse(effect['expires_at']);
      return expiresAt.isAfter(now);
    }).toList();

    if (validEffects.isEmpty) {
      _clearEffect();
      return;
    }

    // Tomamos el efecto más reciente
    final latestEffect = validEffects.last;
    final latestSlug = latestEffect['power_slug'];
    _activeEffectId = latestEffect['id']?.toString();
    _activeEffectCasterId = latestEffect['caster_id']?.toString();

    // Devolución (return): si está armada y llega un ataque ofensivo,
    // reflejamos el efecto al atacante y NO aplicamos el overlay al defensor.
    if (_returnArmed) {
      final casterId = latestEffect['caster_id']?.toString();
      final slugToReturn = latestSlug?.toString();
      final bool isOffensive = slugToReturn == 'black_screen' ||
          slugToReturn == 'freeze' ||
          slugToReturn == 'life_steal';

      if (casterId != null && slugToReturn != null && isOffensive) {
        _returnArmed = false;
        _registerDefenseAction(DefenseAction.returned);

        // 1) Borrar el efecto entrante para que no siga impactando al defensor.
        final incomingId = latestEffect['id'];
        if (incomingId != null) {
          try {
            await _supabase.from('active_powers').delete().eq('id', incomingId);
          } catch (e) {
            debugPrint('PowerEffectProvider: no se pudo borrar efecto entrante: $e');
          }
        }

        // 2) Insertar efecto reflejado al atacante (sin consumir inventario extra).
        try {
          final expiresAt = (latestEffect['expires_at']?.toString()) ??
              DateTime.now().toUtc().add(const Duration(seconds: 6)).toIso8601String();
          final payload = <String, dynamic>{
            'target_id': casterId,
            'caster_id': _listeningForId,
            'power_slug': slugToReturn,
            'expires_at': expiresAt,
          };
          if (latestEffect['event_id'] != null) {
            payload['event_id'] = latestEffect['event_id'];
          }
          await _supabase.from('active_powers').insert(payload);
        } catch (e) {
          debugPrint('PowerEffectProvider: error reflejando efecto: $e');
        }

        // Asegurar que el defensor no muestre overlay del ataque entrante.
        _activePowerSlug = null;
        _activeEffectId = null;
        _activeEffectCasterId = null;
        notifyListeners();
        return;
      }
    }

    if (_shieldActive) {
      _activePowerSlug = null;
      _registerDefenseAction(DefenseAction.shieldBlocked);
      debugPrint('PowerEffectProvider: Ataque interceptado por escudo, ignorando.');
      return;
    }

    _activePowerSlug = latestSlug;

    // Manejo de devolución reactiva
    if (_returnArmed && _returnHandler != null) {
      final casterId = latestEffect['caster_id'];
      final slugToReturn = latestSlug;
      if (casterId != null && slugToReturn != null) {
        _returnArmed = false;
        _returnHandler!(slugToReturn, casterId);
        _registerDefenseAction(DefenseAction.returned);
        debugPrint('PowerEffectProvider: Devolución activada contra $casterId');
      }
    }
    
    // Programamos la limpieza automática para el momento exacto de la expiración
    final expiresAt = DateTime.parse(latestEffect['expires_at']);
    final durationRemaining = expiresAt.difference(now);
    
    _expiryTimer = Timer(durationRemaining, () {
      _activePowerSlug = null;
      _activeEffectId = null;
      _activeEffectCasterId = null;
      notifyListeners();
    });

    notifyListeners();
  }

  void _clearEffect() {
    _expiryTimer?.cancel();
    _activePowerSlug = null;
    _activeEffectId = null;
    _activeEffectCasterId = null;
    notifyListeners();
  }

  void clearActiveEffect() {
    _clearEffect();
  }

  void _registerDefenseAction(DefenseAction action) {
    _defenseFeedbackTimer?.cancel();
    _lastDefenseAction = action;
    _lastDefenseActionAt = DateTime.now();
    notifyListeners();

    _defenseFeedbackTimer = Timer(const Duration(seconds: 2), () {
      // Evitamos borrar si se registró un nuevo evento dentro de la ventana.
      final elapsed = DateTime.now().difference(_lastDefenseActionAt ?? DateTime.now());
      if (elapsed.inSeconds >= 2) {
        _lastDefenseAction = null;
        notifyListeners();
      }
    });
  }

  bool _isShieldSlug(String? slug) {
    if (slug == null) return false;
    return slug == 'shield';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _expiryTimer?.cancel();
    _defenseFeedbackTimer?.cancel();
    super.dispose();
  }
}

enum DefenseAction { shieldBlocked, returned }