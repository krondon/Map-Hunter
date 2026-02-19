import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/game/providers/game_provider.dart';
import 'features/auth/providers/player_provider.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/inventory_service.dart';
import 'features/auth/services/power_service.dart';
import 'features/admin/services/admin_service.dart';
import 'features/game/providers/game_request_provider.dart';
import 'features/game/repositories/game_request_repository.dart';
import 'core/theme/app_theme.dart';

import 'features/game/providers/event_provider.dart';
import 'features/admin/screens/auth_save.dart';
import 'features/game/services/game_service.dart';
import 'features/events/services/event_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? envError;
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    envError = e.toString();
    debugPrint("Warning: Could not load .env file: $e");
  }

  try {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
          "Supabase URL or Anon Key is missing in .env file. Error: $envError");
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  } catch (e) {
    debugPrint("Error initializing Supabase: $e");
    runApp(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Error al inicializar la app:\n$e",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ),
      ),
    ));
    return;
  }

  // Configuración de orientación para móvil
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const TreasureHuntAdminApp());
}

class TreasureHuntAdminApp extends StatelessWidget {
  const TreasureHuntAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final supabase = Supabase.instance.client;
          return GameProvider(gameService: GameService(supabase));
        }),
        ChangeNotifierProvider(create: (_) {
          final supabase = Supabase.instance.client;
          final authService = AuthService(supabaseClient: supabase);
          return PlayerProvider(
            supabaseClient: supabase,
            authService: authService,
            adminService: AdminService(
              supabaseClient: supabase,
              authService: authService,
            ),
            inventoryService: InventoryService(supabaseClient: supabase),
            powerService: PowerService(supabaseClient: supabase),
          );
        }),
        ChangeNotifierProvider(create: (_) {
          final supabase = Supabase.instance.client;
          return GameRequestProvider(
            repository: GameRequestRepository(supabaseClient: supabase),
          );
        }),
        ChangeNotifierProvider(create: (_) {
          final supabase = Supabase.instance.client;
          return EventProvider(eventService: EventService(supabase));
        }),
      ],
      child: MaterialApp(
        title: 'MapHunter Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // Usamos AuthGate para manejar la sesión
        home: const AuthGate(),
      ),
    );
  }
}
