import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart'; // Mantener import aunque no se use en home, por si acaso
import 'providers/game_provider.dart';
import 'providers/player_provider.dart';
import 'providers/game_request_provider.dart';
import 'theme/app_theme.dart';

import 'providers/event_provider.dart'; 
import 'screens/admin/admin_login_screen.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // Configuración de orientación para móvil (útil también para admin en móvil)
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
  
  runApp(const TreasureHuntAdminApp());
}

class TreasureHuntAdminApp extends StatelessWidget {
  const TreasureHuntAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => GameRequestProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: MaterialApp(
        title: 'Treasure Hunt Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // FORZAMOS LA PANTALLA DE ADMIN
        home: const AdminLoginScreen(),
      ),
    );
  }
}
