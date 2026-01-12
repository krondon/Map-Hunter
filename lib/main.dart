import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importar dotenv
import 'package:supabase_flutter/supabase_flutter.dart'; // Importar Supabase

// Imports existentes
import 'features/auth/screens/splash_screen.dart';
import 'features/game/providers/game_provider.dart';
import 'features/game/services/penalty_service.dart';
import 'features/auth/providers/player_provider.dart';
import 'features/game/providers/game_request_provider.dart';
import 'core/theme/app_theme.dart';

import 'features/game/providers/event_provider.dart'; 
import 'features/game/providers/power_effect_provider.dart';
import 'features/admin/screens/admin_login_screen.dart'; 
import 'shared/widgets/sabotage_overlay.dart';
import 'shared/utils/global_keys.dart'; // Importar llaves globales
import 'features/auth/widgets/auth_monitor.dart'; // Importar AuthMonitor
import 'features/mall/providers/store_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // 3. La configuración de orientación y UI Overlay es solo para MÓVIL (Android/iOS)
  // En Web esto puede causar errores o no es necesario.
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0E27),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
  
  runApp(const TreasureHuntApp());
}

class TreasureHuntApp extends StatelessWidget {
  const TreasureHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => GameRequestProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        Provider(create: (_) => PenaltyService()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => PowerEffectProvider()),
      ],
      child: MaterialApp(
        title: 'Treasure Hunt RPG',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return AuthMonitor(
            child: SabotageOverlay(child: child ?? const SizedBox()),
          );
        },
        
        // 5. LÓGICA PRINCIPAL:
        // Si estamos en WEB -> Muestra la pantalla de Login de Admin
        // Si estamos en MÓVIL o WINDOWS (para pruebas) -> Muestra el Splash Screen normal para usuarios
        home: kIsWeb 
            ? const AdminLoginScreen() 
            : const SplashScreen(),
      ),
    );
  }
}