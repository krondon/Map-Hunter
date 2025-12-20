import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PowerEffectProvider extends ChangeNotifier {
  StreamSubscription? _subscription;
  Timer? _expiryTimer;
  Timer? _defenseFeedbackTimer;
  bool _shieldActive = false;
  String? _listeningForId;
  String? get listeningForId => _listeningForId;
  bool _returnArmed = false;
  Future<bool> Function(String powerSlug, String targetGamePlayerId)?
      _returnHandler;
  Future<void> Function(String effectId, String? casterGamePlayerId)?
      _lifeStealVictimHandler;
  DefenseAction? _lastDefenseAction;
  DateTime? _lastDefenseActionAt;

  String? _lastLifeStealHandledEffectId;
  String? _returnedByPlayerName;
  String? get returnedByPlayerName => _returnedByPlayerName;

  final Map<String, String> _powerIdToSlugCache = {};

  // Guardamos el slug del poder activo (ej: 'black_screen', 'freeze')
  String? _activePowerSlug;
  String? _activeEffectId;
  String? _activeEffectCasterId;

  String? get activePowerSlug => _activePowerSlug;
  String? get activeEffectId => _activeEffectId;
  String? get activeEffectCasterId => _activeEffectCasterId;
  DefenseAction? get lastDefenseAction => _lastDefenseAction;

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

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
      Future<bool> Function(String powerSlug, String targetGamePlayerId)
          handler) {
    _returnHandler = handler;
  }

  void configureLifeStealVictimHandler(
      Future<void> Function(String effectId, String? casterGamePlayerId)
          handler) {
    _lifeStealVictimHandler = handler;
  }

  // Iniciar la escucha de ataques dirigidos a este jugador específico
  void startListening(String? myGamePlayerId) {
    final supabase = _supabaseClient;
    if (supabase == null) {
      _clearEffect();
      _subscription?.cancel();
      return;
    }

    if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
      _clearEffect();
      _subscription?.cancel();
      return;
    }

    _subscription?.cancel();
    _expiryTimer?.cancel();
    _listeningForId = myGamePlayerId;

    _subscription = supabase
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

    final supabase = _supabaseClient;
    if (supabase == null) {
      _clearEffect();
      return;
    }

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

    // Tomamos el efecto más reciente (orden estable por created_at/expires_at)
    validEffects.sort((a, b) {
      DateTime parseDt(dynamic value) {
        if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
        try {
          return DateTime.parse(value.toString());
        } catch (_) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      final aCreated = parseDt(a['created_at']);
      final bCreated = parseDt(b['created_at']);
      if (aCreated != bCreated) return aCreated.compareTo(bCreated);
      final aExpires = parseDt(a['expires_at']);
      final bExpires = parseDt(b['expires_at']);
      return aExpires.compareTo(bExpires);
    });

    final latestEffect = validEffects.last;
    final latestSlug = await _resolveEffectSlug(latestEffect);
    _activeEffectId = latestEffect['id']?.toString();
    _activeEffectCasterId = latestEffect['caster_id']?.toString();

    // Devolución (return): si está armada y llega un ataque ofensivo,
    // reflejamos el efecto al atacante y NO aplicamos el overlay al defensor.
    if (_returnArmed) {
      final casterId = latestEffect['caster_id']?.toString();
      final slugToReturn = latestSlug?.toString();
      final bool isOffensive = slugToReturn == 'black_screen' ||
          slugToReturn == 'freeze' ||
          slugToReturn == 'life_steal' ||
          slugToReturn == 'blur_screen';

      if (casterId != null && slugToReturn != null && isOffensive) {
        _returnArmed = false;
        _registerDefenseAction(DefenseAction.returned);

        // 1) Borrar el efecto entrante para que no siga impactando al defensor.
        final incomingId = latestEffect['id'];
        if (incomingId != null) {
          try {
            await supabase.from('active_powers').delete().eq('id', incomingId);
          } catch (e) {
            debugPrint(
                'PowerEffectProvider: no se pudo borrar efecto entrante: $e');
          }
        }

        // 2) Insertar efecto reflejado al atacante (sin consumir inventario extra).
        try {
          final expiresAt = (latestEffect['expires_at']?.toString()) ??
              DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 6))
                  .toIso8601String();
          final payload = <String, dynamic>{
            'target_id': casterId,
            'caster_id': _listeningForId,
            'power_slug': slugToReturn,
            'expires_at': expiresAt,
          };
          if (latestEffect['event_id'] != null) {
            payload['event_id'] = latestEffect['event_id'];
          }
          await supabase.from('active_powers').insert(payload);
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
      debugPrint(
          'PowerEffectProvider: Ataque interceptado por escudo, ignorando.');
      return;
    }

    _activePowerSlug = latestSlug;

    // Aplicación real de life_steal para la víctima (RLS-safe):
    // el propio cliente víctima se descuenta a sí mismo vía PlayerProvider/RPC.
    // final effectId = _activeEffectId;
    // if (latestSlug == 'life_steal' &&
    //     effectId != null &&
    //     effectId.isNotEmpty &&
    //     effectId != _lastLifeStealHandledEffectId &&
    //     _lifeStealVictimHandler != null) {
    //   _lastLifeStealHandledEffectId = effectId;
    //   // Fire-and-forget para no bloquear la UI del overlay.
    //   () async {
    //     try {
    //       await _lifeStealVictimHandler!(effectId, _activeEffectCasterId);
    //     } catch (e) {
    //       debugPrint('PowerEffectProvider: life_steal handler error: $e');
    //     }
    //   }();
    // }

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

  Future<String?> _resolveEffectSlug(Map<String, dynamic> effect) async {
    final explicit = effect['power_slug'] ?? effect['slug'];
    if (explicit != null) return explicit.toString();

    final powerId = effect['power_id'];
    if (powerId == null) return null;
    final powerIdStr = powerId.toString();
    final cached = _powerIdToSlugCache[powerIdStr];
    if (cached != null) return cached;

    final supabase = _supabaseClient;
    if (supabase == null) return null;

    try {
      final res = await supabase
          .from('powers')
          .select('slug')
          .eq('id', powerIdStr)
          .maybeSingle();
      final slug = res?['slug']?.toString();
      if (slug != null && slug.isNotEmpty) {
        _powerIdToSlugCache[powerIdStr] = slug;
      }
      return slug;
    } catch (_) {
      return null;
    }
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
      final elapsed =
          DateTime.now().difference(_lastDefenseActionAt ?? DateTime.now());
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

// 3. AÑADE ESTE MÉTODO AL FINAL DE LA CLASE (antes del dispose)
void notifyPowerReturned(String byPlayerName) {
  _returnedByPlayerName = byPlayerName;
  
  // Esto activa el toast visual que ya tienes configurado
  _registerDefenseAction(DefenseAction.returned); 
  
  notifyListeners();
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
