import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../features/game/providers/connectivity_provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../core/services/connectivity_service.dart';
import '../utils/global_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/admin/screens/admin_login_screen.dart';
import 'low_signal_overlay.dart';

/// Widget que monitorea la conectividad y toma acciones
/// cuando se pierde la conexión:
/// - En minijuego: pierde vida + logout
/// - En otras pantallas: solo logout
class ConnectivityMonitor extends StatefulWidget {
  final Widget child;

  const ConnectivityMonitor({super.key, required this.child});

  @override
  State<ConnectivityMonitor> createState() => _ConnectivityMonitorState();
}

class _ConnectivityMonitorState extends State<ConnectivityMonitor> {
  Timer? _countdownTimer;
  int _secondsRemaining = 25;
  bool _showOverlay = false;
  bool _hasTriggeredDisconnect = false;
  ConnectivityProvider? _connectivityProvider;

  @override
  void initState() {
    super.initState();
    // Post-frame callback to register listener to avoid building blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectivityProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      _connectivityProvider?.addListener(_onConnectivityChanged);
      // Check initial status
      _onConnectivityChanged();
    });
  }

  @override
  void dispose() {
    _connectivityProvider?.removeListener(_onConnectivityChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted || _hasTriggeredDisconnect) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer == null) {
      _cancelCountdown();
      return;
    }

    final status = _connectivityProvider?.status ?? ConnectivityStatus.online;

    if (status == ConnectivityStatus.online) {
      _cancelCountdown();
    } else if (status == ConnectivityStatus.lowSignal ||
        status == ConnectivityStatus.offline) {
      if (!_showOverlay) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    if (_countdownTimer != null) return;

    setState(() {
      _showOverlay = true;
      _secondsRemaining = 25;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });

        if (_secondsRemaining <= 0) {
          timer.cancel();
          _handleDisconnect();
        }
      }
    });
  }

  void _cancelCountdown() {
    if (_showOverlay || _countdownTimer != null) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      if (mounted) {
        setState(() {
          _showOverlay = false;
          _secondsRemaining = 25;
        });
      }
    }
  }

  Future<void> _handleDisconnect() async {
    if (_hasTriggeredDisconnect || !mounted) return;
    _hasTriggeredDisconnect = true;

    _countdownTimer?.cancel();
    _countdownTimer = null;

    final connectivity = context.read<ConnectivityProvider>();
    final playerProvider = context.read<PlayerProvider>();

    String message;

    // Si estaba en minijuego, pierde vida
    if (connectivity.isInMinigame) {
      final eventId = connectivity.currentEventId;

      // 1. Guardar penalización pendiente LOCALMENTE (Por si no hay internet ahora)
      unawaited(SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('pending_life_loss', true);
        if (eventId != null) {
          prefs.setString('pending_life_loss_event', eventId);
        }
        debugPrint('ConnectivityMonitor: Penalización guardada localmente');
      }));

      // 2. Intentar enviar al servidor de todos modos (Last chance)
      unawaited(
        playerProvider.loseLife(eventId: eventId).timeout(
              const Duration(seconds: 1),
              onTimeout: () =>
                  debugPrint('ConnectivityMonitor: LoseLife timeout sync'),
            ),
      );
      message =
          '¡Perdiste conexión durante el minijuego!\nHas perdido una vida.';
    } else {
      message =
          'Perdiste conexión a internet.\nPor favor, reconéctate e inicia sesión.';
    }

    // 1. Mostrar mensaje y redirigir INMEDIATAMENTE
    _showDisconnectMessage(message);

    // 2. Ejecutar limpieza de sesión en segundo plano
    unawaited(
      playerProvider.logout().timeout(
            const Duration(seconds: 2),
            onTimeout: () => debugPrint('ConnectivityMonitor: Logout timeout'),
          ),
    );

    // 3. Detener monitoreo local
    connectivity.stopMonitoring();

    // 4. Resetear estado del overlay y flags para la próxima sesión
    if (mounted) {
      setState(() {
        _showOverlay = false;
        _secondsRemaining = 25;
        _hasTriggeredDisconnect = false;
      });
    }
  }

  void _showDisconnectMessage(String message) {
    if (rootNavigatorKey.currentState == null) return;

    // Navegar a login
    rootNavigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => kIsWeb ? const AdminLoginScreen() : const LoginScreen(),
      ),
      (route) => false,
    );

    // Mostrar SnackBar después de un frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigatorKey.currentContext != null) {
        ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Overlay de señal baja
        if (_showOverlay)
          Positioned.fill(
            child: LowSignalOverlay(
              secondsRemaining: _secondsRemaining,
            ),
          ),
      ],
    );
  }
}
