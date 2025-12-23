import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PowerEffectProvider extends ChangeNotifier {
  StreamSubscription? _subscription;
  StreamSubscription? _casterSubscription; // Nueva suscripción para detectar reflejos salientes
  Timer? _expiryTimer;
  Timer? _defenseFeedbackTimer;
  bool _shieldActive = false;
  String? _listeningForId;
  String? get listeningForId => _listeningForId;
  
  bool _isManualCasting = false; // Flag para distinguir casting manual vs automático (reflejo)
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



  String? _returnedAgainstCasterId;
  String? get returnedAgainstCasterId => _returnedAgainstCasterId;

  String? _returnedPowerSlug;
  String? get returnedPowerSlug => _returnedPowerSlug;

  final Map<String, String> _powerIdToSlugCache = {};
  final Map<String, Duration> _powerSlugToDurationCache = {};

  // Guardamos el slug del poder activo (ej: 'black_screen', 'freeze')
  String? _activePowerSlug;
  String? _activeEffectId;
  String? _activeEffectCasterId;
  DateTime? _activePowerExpiresAt; // Nueva variable

  DateTime? get activePowerExpiresAt => _activePowerExpiresAt; // Nuevo getter

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

  bool get isReturnArmed => _returnArmed;

  void setManualCasting(bool value) {
    _isManualCasting = value;
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
      _casterSubscription?.cancel();
      return;
    }

    if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
      _clearEffect();
      _subscription?.cancel();
      _casterSubscription?.cancel();
      return;
    }

    _subscription?.cancel();
    _casterSubscription?.cancel();
    _expiryTimer?.cancel();
    _listeningForId = myGamePlayerId;

    // 1. Escuchar ataques ENTRANTES (Target = YO)
    _subscription = supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('target_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
          await _processEffects(data);
        }, onError: (e) {
          debugPrint('PowerEffectProvider stream error: $e');
        });

    // 2. Escuchar ataques SALIENTES (Caster = YO) para detectar reflejos
    _casterSubscription = supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('caster_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
          await _processOutgoingEffects(data);
        }, onError: (e) {
          debugPrint('PowerEffectProvider outgoing stream error: $e');
        });
  }

  Future<void> _processOutgoingEffects(List<Map<String, dynamic>> data) async {
    // DIAGNÓSTICO PROFUNDO
    debugPrint("DEBUG OUTGOING: _isManualCasting? $_isManualCasting");
    debugPrint("DEBUG OUTGOING: data length? ${data.length}");

    // Si estamos lanzando manualmente, ignoramos esto (es un ataque normal)
    if (_isManualCasting) {
       debugPrint("DEBUG OUTGOING: Ignorando porque es manual");
       return;
    }
    if (data.isEmpty) return;

    // Buscamos si hay algún efecto ofensivo reciente que hayamos "lanzado" automáticamente
    final now = DateTime.now().toUtc();
    for (final effect in data) {
      final createdAtStr = effect['created_at'];
      final createdAt = DateTime.parse(createdAtStr);
      final ageSeconds = now.difference(createdAt).inSeconds;
      
      debugPrint("DEBUG OUTGOING CHECK: ID ${effect['id']} - Age: ${ageSeconds}s");
      
      // Ampliamos un poco el rango por temas de sync (5s -> 10s)
      if (ageSeconds > 10) {
         debugPrint("DEBUG OUTGOING: Muy viejo");
         continue;
      }

      final slug = await _resolveEffectSlug(effect);
      debugPrint("DEBUG OUTGOING: Slug resuelto: $slug");

      final bool isOffensive = slug == 'black_screen' ||
            slug == 'freeze' ||
            slug == 'life_steal' ||
            slug == 'blur_screen';
      
      debugPrint("DEBUG OUTGOING: ¿Es ofensivo? $isOffensive");
        
      if (isOffensive) {
         // ¡BINGO! Hemos lanzado un ataque ofensivo PERO no estábamos en modo manual.
         // Esto significa que fue un REFLEJO automático del backend.
         final originalAttackerId = effect['target_id']?.toString();
         
         debugPrint("REFLEJO DETECTADO: Devolvimos $slug a $originalAttackerId");
         
         // IMPORTANTE: Quitamos la condición _activePowerSlug == null por si acaso
         if (originalAttackerId != null) {
            // Mostramos el feedback de defensa
            debugPrint("!!! ACTIVANDO FEEDBACK DE DEFENSA !!!");
            _returnedAgainstCasterId = originalAttackerId;
            _returnedPowerSlug = slug;
            _registerDefenseAction(DefenseAction.returned);
         }
      }
    }
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

    debugPrint('DEBUG: validEffects count: ${validEffects.length}');
    for (var e in validEffects) {
       final s = await _resolveEffectSlug(e);
       debugPrint('DEBUG: Found effect slug: $s, ID: ${e['id']}');
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

    // Nueva lógica: Detectar si tenemos "return" activo buscando en los efectos válidos
    final activeReturnEffect = await () async {
      for (final eff in validEffects) {
        final s = await _resolveEffectSlug(eff);
        if (s == 'return') return eff;
      }
      return null;
    }();

    final hasReturnActive = activeReturnEffect != null || _returnArmed;

    // Buscamos si hay ALGÚN efecto ofensivo que debamos devolver (no necesariamente el último)
    Map<String, dynamic>? offensiveEffectToReturn;
    String? offensiveSlug;

    if (hasReturnActive) {
      for (final eff in validEffects) {
        final slug = await _resolveEffectSlug(eff);
        final casterId = eff['caster_id']?.toString();
        
        final bool isOffensive = slug == 'black_screen' ||
            slug == 'freeze' ||
            slug == 'life_steal' ||
            slug == 'blur_screen';
        
        final bool isSelf = casterId == _listeningForId;

        if (isOffensive && !isSelf && casterId != null) {
          offensiveEffectToReturn = eff;
          offensiveSlug = slug;
          break; // Encontramos uno, lo devolvemos
        }
      }
    }

    // SI ENCONTRAMOS UN ATAQUE PARA DEVOLVER -> EJECUTAMOS LA DEFENSA
    if (offensiveEffectToReturn != null && offensiveSlug != null) {
        final casterId = offensiveEffectToReturn['caster_id']?.toString();
        
        // Guardamos quién nos atacó para mostrar el feedback visual
        if (casterId != null) {
           _returnedAgainstCasterId = casterId;
           _returnedPowerSlug = offensiveSlug;
        }
        
        _returnArmed = false;
        _registerDefenseAction(DefenseAction.returned);

        // 1) Borrar el efecto entrante
        final incomingId = offensiveEffectToReturn['id'];
        if (incomingId != null) {
          try {
            await supabase.from('active_powers').delete().eq('id', incomingId);
          } catch (e) {
            debugPrint('PowerEffectProvider: error borrando efecto: $e');
          }
        }

        // 2) Insertar efecto reflejado
        try {
          final nowUtc = DateTime.now().toUtc();
          final duration = await _getPowerDurationFromDb(powerSlug: offensiveSlug!);
          final expiresAt = nowUtc.add(duration).toIso8601String();
          final payload = <String, dynamic>{
            'target_id': casterId,
            'caster_id': _listeningForId,
            'power_slug': offensiveSlug,
            'expires_at': expiresAt,
          };
          if (offensiveEffectToReturn['event_id'] != null) {
            payload['event_id'] = offensiveEffectToReturn['event_id'];
          }
          await supabase.from('active_powers').insert(payload);
          // Nota: No actualizamos _activePowerExpiresAt aquí porque es un evento "saliente"
        } catch (e) {
          debugPrint('PowerEffectProvider: error reflejando efecto: $e');
        }

        // Limpiamos UI para que el ataque no se vea
        _activePowerSlug = null;
        _activeEffectId = null;
        _activeEffectCasterId = null;
        notifyListeners();
        return;
    }

    // SI NO HAY DEVOLUCIÓN, SEGUIMOS CON LA LÓGICA NORMAL (MOSTRAR EL ÚLTIMO EFECTO)
    final latestEffect = validEffects.last;
    final latestSlug = await _resolveEffectSlug(latestEffect);
    _activeEffectId = latestEffect['id']?.toString();
    _activeEffectCasterId = latestEffect['caster_id']?.toString();

    if (_shieldActive) {
      _activePowerSlug = null;
      _registerDefenseAction(DefenseAction.shieldBlocked);
      debugPrint(
          'PowerEffectProvider: Ataque interceptado por escudo, ignorando.');
      return;
    }

    _activePowerSlug = latestSlug;

    // Guardamos la fecha exacta para la UI
    _activePowerExpiresAt = DateTime.parse(latestEffect['expires_at']);

    // Aplicación real de life_steal para la víctima (RLS-safe):
    // el propio cliente víctima se descuenta a sí mismo vía PlayerProvider/RPC.
    // final effectId = _activeEffectId;
    if (latestSlug == 'life_steal' &&
        _activeEffectId != _lastLifeStealHandledEffectId &&
        _lifeStealVictimHandler != null) {
      _lastLifeStealHandledEffectId = _activeEffectId;

      // Llamamos al handler que restará la vida localmente
      _lifeStealVictimHandler!(_activeEffectId!, _activeEffectCasterId);
    }
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

    if (durationRemaining <= Duration.zero) {
      _clearEffect();
      return;
    }

    _expiryTimer = Timer(durationRemaining, () {
      _clearEffect();
    });

    debugPrint('¿Llegó Life Steal?: ${latestSlug == 'life_steal'}');
    debugPrint('ID del Atacante: $_activeEffectCasterId');
    debugPrint('Expira en: ${expiresAt.difference(now).inSeconds} segundos');

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

  Future<Duration> _getPowerDurationFromDb({required String powerSlug}) async {
    final cached = _powerSlugToDurationCache[powerSlug];
    if (cached != null) return cached;

    final supabase = _supabaseClient;
    if (supabase == null) return Duration.zero;

    try {
      final row = await supabase
          .from('powers')
          .select('duration')
          .eq('slug', powerSlug)
          .maybeSingle();

      final seconds = (row?['duration'] as num?)?.toInt() ?? 0;
      final duration =
          seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
      _powerSlugToDurationCache[powerSlug] = duration;
      return duration;
    } catch (e) {
      debugPrint('_getPowerDurationFromDb($powerSlug) error: $e');
      return Duration.zero;
    }
  }

  void _clearEffect() {
    _expiryTimer?.cancel();
    _activePowerSlug = null;
    _activeEffectId = null;
    _activeEffectCasterId = null;
    _activePowerExpiresAt = null;
    // No limpiamos _returnedAgainstCasterId aquí para que persista el feedback visual
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

    // Duración diferenciada: Returned es un evento más importante => 4s
    final duration = action == DefenseAction.returned 
        ? const Duration(seconds: 4) 
        : const Duration(seconds: 2);

    _defenseFeedbackTimer = Timer(duration, () {
      // Evitamos borrar si se registró un nuevo evento dentro de la ventana.
      final elapsed =
          DateTime.now().difference(_lastDefenseActionAt ?? DateTime.now());
      if (elapsed.inMilliseconds >= duration.inMilliseconds) {
        _lastDefenseAction = null;
        _returnedAgainstCasterId = null; // Limpiamos el ID del atacante al terminar el feedback
        _returnedByPlayerName = null; // IMPORTANTE: Limpiar también el nombre del que nos reflejó
        _returnedPowerSlug = null;
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
    _casterSubscription?.cancel();
    _expiryTimer?.cancel();
    _defenseFeedbackTimer?.cancel();
    super.dispose();
  }
}

enum DefenseAction { shieldBlocked, returned }
