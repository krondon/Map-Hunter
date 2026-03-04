import 'dart:async';
import 'package:flutter/foundation.dart';

/// Controla la frecuencia de actualización del leaderboard.
///
/// Problema que resuelve:
/// Con 50 jugadores, cada pista completada o vida perdida dispara un Postgres
/// Change que llama `notifyListeners()` directamente. En ráfagas de actividad,
/// esto causa 50+ reconstrucciones/segundo del widget del podio.
///
/// Solución:
/// Acumula cambios durante [interval] y emite solo una actualización al final
/// del período de silencio (trailing debounce). Si la ráfaga dura más de
/// [maxWait], fuerza una actualización para no parecer congelado.
class LeaderboardDebouncer {
  final Duration interval;
  final Duration maxWait;

  Timer? _debounceTimer;
  Timer? _maxWaitTimer;
  VoidCallback? _pendingCallback;
  bool _hasPendingUpdate = false;

  LeaderboardDebouncer({
    this.interval = const Duration(milliseconds: 2000),
    this.maxWait = const Duration(milliseconds: 5000),
  });

  /// Registra que hay un cambio pendiente en el leaderboard.
  ///
  /// [callback] será llamado después de [interval] de inactividad,
  /// o después de [maxWait] si hay actualizaciones continuas.
  void schedule(VoidCallback callback) {
    _pendingCallback = callback;
    _hasPendingUpdate = true;

    // Reiniciar el timer de debounce
    _debounceTimer?.cancel();
    _debounceTimer = Timer(interval, _flush);

    // Iniciar timer de maxWait solo si no está corriendo
    _maxWaitTimer ??= Timer(maxWait, () {
      _maxWaitTimer = null;
      if (_hasPendingUpdate) {
        _flush();
      }
    });
  }

  void _flush() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _maxWaitTimer?.cancel();
    _maxWaitTimer = null;

    if (_hasPendingUpdate && _pendingCallback != null) {
      _hasPendingUpdate = false;
      _pendingCallback!();
    }
  }

  /// Fuerza ejecución inmediata (e.g., al inicializar la pantalla del podio).
  void flush() => _flush();

  void dispose() {
    _debounceTimer?.cancel();
    _maxWaitTimer?.cancel();
  }
}
