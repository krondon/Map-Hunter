import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importar dotenv
import 'package:supabase_flutter/supabase_flutter.dart'; // Importar Supabase

// Imports existentes
import 'screens/splash_screen.dart';
import 'providers/game_provider.dart';
import 'providers/player_provider.dart';
import 'providers/game_request_provider.dart';
import 'theme/app_theme.dart';

// 2. Imports nuevos para el Administrador
import 'providers/event_provider.dart'; 
import 'screens/admin/admin_login_screen.dart'; 

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
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => GameRequestProvider()),
        
        // 4. Agregamos el Provider de Eventos para que funcione en la Web
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: MaterialApp(
        title: 'Treasure Hunt RPG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        
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