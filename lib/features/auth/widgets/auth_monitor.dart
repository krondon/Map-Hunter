import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/player_provider.dart';
import '../../../shared/utils/global_keys.dart';
import '../screens/login_screen.dart';
import '../../admin/screens/admin_login_screen.dart';

class AuthMonitor extends StatefulWidget {
  final Widget child;

  const AuthMonitor({super.key, required this.child});

  @override
  State<AuthMonitor> createState() => _AuthMonitorState();
}

class _AuthMonitorState extends State<AuthMonitor> {
  bool? _wasLoggedIn;
  bool _hasRedirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isLoggedIn = playerProvider.isLoggedIn;

    // Si detectamos que el usuario está logueado, reseteamos el flag de redirección
    if (isLoggedIn) {
      _hasRedirected = false;
    }

    // Inicialización del estado previo
    if (_wasLoggedIn == null) {
      _wasLoggedIn = isLoggedIn;
      return;
    }

    // Detectar Logout (True -> False) y evitar loops con _hasRedirected
    if (_wasLoggedIn == true && !isLoggedIn && !_hasRedirected) {
      debugPrint("AuthMonitor: Logout detectado. Redirigiendo a Login...");
      _hasRedirected = true; // Marcar como redirigido para evitar bucles
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rootNavigatorKey.currentState != null) {
          rootNavigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => kIsWeb 
                   ? const AdminLoginScreen() 
                   : const LoginScreen(),
            ),
            (route) => false,
          );
        }
      });
    }

    _wasLoggedIn = isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
