import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_login_screen.dart';
import 'dashboard-screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 1. Prioridad: Si el snapshot tiene datos (evento de auth), úsalo.
        if (snapshot.hasData) {
          final session = snapshot.data?.session;
          if (session != null) {
            return const DashboardScreen();
          } else {
            // Si el evento dice que no hay sesión (ej. SIGN_OUT), vamos al login
            return const AdminLoginScreen();
          }
        }

        // 2. Si estamos esperando el primer evento del stream...
        // Verificamos si YA existe una sesión recuperada por initialize()
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          return const DashboardScreen();
        }

        // 3. Si no hay datos en el stream y no hay sesión actual, mostramos carga
        // (Esto evita el parpadeo del Login si la recuperación es lenta)
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}