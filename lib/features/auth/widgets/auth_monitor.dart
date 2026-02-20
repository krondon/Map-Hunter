import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/player_provider.dart';
import '../../../shared/utils/global_keys.dart';
import '../screens/login_screen.dart';
import '../../admin/screens/admin_login_screen.dart';
import '../../game/providers/game_provider.dart';
import '../../game/screens/game_request_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../layouts/screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/reset_password_screen.dart';
import 'dart:async';

/// AuthMonitor: Gestiona la navegación basada en el estado de autenticación
/// y el estado del usuario respecto a eventos (Gatekeeper).
///
/// Principios SOLID aplicados:
/// - S: Responsabilidad única - manejar navegación basada en estado
/// - D: Depende de abstracciones (providers) no implementaciones concretas
class AuthMonitor extends StatefulWidget {
  final Widget child;

  const AuthMonitor({super.key, required this.child});

  @override
  State<AuthMonitor> createState() => _AuthMonitorState();
}

class _AuthMonitorState extends State<AuthMonitor> {
  bool? _wasLoggedIn;
  bool _hasRedirected = false;
  bool _isCheckingStatus = false;
  StreamSubscription<AuthState>? _authSubscription;
  bool _showMask = false; // [FIX] To hide old screen during logout transition

  @override
  void initState() {
    super.initState();
    _subscribeToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('AuthMonitor: Auth Event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('AuthMonitor: Password Recovery detected! Redirecting...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToResetPassword();
        });
      }
    });
  }

  void _navigateToResetPassword() {
    if (rootNavigatorKey.currentState != null) {
      rootNavigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        (route) => false,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isLoggedIn = playerProvider.isLoggedIn;

    // Si detectamos que el usuario está logueado, verificar su estado de evento
    if (isLoggedIn && !_hasRedirected && !_isCheckingStatus) {
      _hasRedirected = false;

      // Verificar si es un cold start (primera vez que detectamos login)
      if (_wasLoggedIn == null || _wasLoggedIn == false) {
        _checkUserEventStatusAndNavigate();
      }
    }

    // Detectar Logout (True -> False) y evitar loops con _hasRedirected
    if (_wasLoggedIn == true && !isLoggedIn && !_hasRedirected) {
      debugPrint(
          "AuthMonitor: Logout detectado. Iniciando secuencia de redirección...");
      _hasRedirected = true;

      // [FIX] Activar máscara inmediatamente para ocultar la pantalla anterior
      setState(() => _showMask = true);

      // [FIX] Pequeño delay para permitir que diálogos cierren limpiamente
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          debugPrint("AuthMonitor: Ejecutando navegación al Login ahora.");
          _navigateToLogin();

          // [FIX] Desactivar máscara después de iniciar la navegación
          // Usamos addPostFrameCallback para asegurar que la nueva ruta ya se está construyendo
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showMask = false);
          });
        }
      });
    }

    // Si el usuario se loguea, resetear el flag para permitir futuras redirecciones de logout
    if (isLoggedIn && _wasLoggedIn == false) {
      _hasRedirected = false;
    }

    _wasLoggedIn = isLoggedIn;
  }

  /// Verifica el estado del usuario respecto a eventos y navega según corresponda.
  /// Esta es la lógica principal del Gatekeeper.
  Future<void> _checkUserEventStatusAndNavigate() async {
    if (_isCheckingStatus) return;

    _isCheckingStatus = true;

    try {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final player = playerProvider.currentPlayer;

      if (player == null) {
        _isCheckingStatus = false;
        return;
      }

      // Admins van directamente al Dashboard (no aplica el Gatekeeper)
      if (player.role == 'admin') {
        _isCheckingStatus = false;
        return; // El LoginScreen ya maneja esto
      }

      debugPrint(
          'AuthMonitor: Checking user event status for ${player.userId}');

      // Verificar estado usando el Gatekeeper de GameProvider
      final statusResult =
          await gameProvider.checkUserEventStatus(player.userId);

      debugPrint('AuthMonitor: User status is ${statusResult.status}');

      if (!mounted) {
        _isCheckingStatus = false;
        return;
      }

      // Navegar según el estado (con delay para permitir que el widget tree se estabilice)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        switch (statusResult.status) {
          // === CASOS DE BLOQUEO ===
          case UserEventStatus.banned:
            debugPrint('AuthMonitor: User banned, logging out...');
            await playerProvider.logout();
            _navigateToLogin();
            break;

          case UserEventStatus.waitingApproval:
            // CAMBIO: No redirigir automáticamente. Dejar que el usuario elija en ScenariosScreen.
            debugPrint(
                'AuthMonitor: User waiting approval - continue to ScenariosScreen');
            break;

          // === CASOS DE FLUJO ABIERTO ===
          // El usuario siempre va al catálogo donde puede elegir entrar al evento
          case UserEventStatus.inGame:
          case UserEventStatus.readyToInitialize:
          case UserEventStatus.rejected:
          case UserEventStatus.noEvent:
            // Dejar que el flujo normal continúe hacia ScenariosScreen
            debugPrint('AuthMonitor: Open flow - continue to ScenariosScreen');
            break;
        }

        _isCheckingStatus = false;
      });
    } catch (e) {
      debugPrint('AuthMonitor: Error checking user status: $e');
      _isCheckingStatus = false;
    }
  }

  void _navigateToLogin() {
    if (rootNavigatorKey.currentState != null) {
      rootNavigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  void _navigateToHome(String eventId) {
    if (rootNavigatorKey.currentState != null) {
      rootNavigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(eventId: eventId)),
        (route) => false,
      );
    }
  }

  void _navigateToGameRequest(String eventId) {
    if (rootNavigatorKey.currentState != null) {
      rootNavigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => GameRequestScreen(eventId: eventId)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showMask)
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
