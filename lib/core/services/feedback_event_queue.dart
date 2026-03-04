import 'dart:async';
import 'dart:collection';

/// Cola de eventos con garantía de entrega "at-least-once".
///
/// A diferencia de un [BroadcastStream], esta cola ALMACENA eventos que llegan
/// mientras no hay listeners activos y los entrega en cuanto se registra uno.
///
/// Ideal para: animaciones de "escudo roto", "ataque recibido", feedback efímero.
/// No usar para: estado persistente (usar ChangeNotifier para eso).
///
/// Uso en PowerEffectProvider:
/// ```dart
/// final _feedbackQueue = FeedbackEventQueue<PowerFeedbackEvent>();
///
/// // Emitir (en lugar de _feedbackStreamController.add):
/// _feedbackQueue.add(PowerFeedbackEvent(PowerFeedbackType.shieldBroken));
///
/// // Exponer stream:
/// Stream<PowerFeedbackEvent> get feedbackStream => _feedbackQueue.stream;
/// ```
class FeedbackEventQueue<T> {
  final int maxSize;
  final Duration ttl;

  final Queue<_TimestampedEvent<T>> _pending = Queue();
  final StreamController<T> _controller = StreamController<T>.broadcast();

  int _listenerCount = 0;
  bool get _hasActiveListeners => _listenerCount > 0;

  FeedbackEventQueue({
    this.maxSize = 20,
    this.ttl = const Duration(seconds: 10),
  });

  /// Stream de eventos para consumo en la UI.
  ///
  /// El primer listener que se conecte recibirá todos los eventos almacenados
  /// en la cola (eventos que llegaron mientras no había listeners activos).
  Stream<T> get stream => _streamWithDrain();

  Stream<T> _streamWithDrain() async* {
    _listenerCount++;

    // Drenar cola de eventos buffereados al nuevo listener
    _drainPendingEvents();

    try {
      await for (final event in _controller.stream) {
        yield event;
      }
    } finally {
      _listenerCount--;
    }
  }

  /// Agrega un evento.
  ///
  /// Si hay listeners activos → entrega inmediata via stream.
  /// Si no hay listeners → bufferiza para entrega diferida (evita event drops).
  void add(T event) {
    if (_hasActiveListeners) {
      _controller.add(event);
    } else {
      _pending.add(_TimestampedEvent(event: event, createdAt: DateTime.now()));

      // Evitar acumulación ilimitada
      while (_pending.length > maxSize) {
        _pending.removeFirst();
      }
    }
  }

  /// Drena eventos buffereados al stream, descartando los que superaron el TTL.
  void _drainPendingEvents() {
    if (_pending.isEmpty) return;

    final now = DateTime.now();
    final fresh = <T>[];

    while (_pending.isNotEmpty) {
      final item = _pending.removeFirst();
      if (now.difference(item.createdAt) <= ttl) {
        fresh.add(item.event);
      }
      // Eventos más viejos que TTL → descartados silenciosamente
    }

    // scheduleMicrotask: no bloquear el frame de build actual
    for (final event in fresh) {
      scheduleMicrotask(() => _controller.add(event));
    }
  }

  /// Limpia eventos pendientes sin disparar listeners (logout/resetState).
  void clear() => _pending.clear();

  void dispose() {
    _pending.clear();
    _controller.close();
  }
}

class _TimestampedEvent<T> {
  final T event;
  final DateTime createdAt;

  const _TimestampedEvent({required this.event, required this.createdAt});
}
