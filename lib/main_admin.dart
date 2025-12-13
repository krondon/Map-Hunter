import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/game/providers/game_provider.dart';
import 'features/auth/providers/player_provider.dart';
import 'features/game/providers/game_request_provider.dart';
import 'core/theme/app_theme.dart';

import 'features/game/providers/event_provider.dart'; 
import 'features/admin/screens/auth_save.dart';

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
        // Usamos AuthGate para manejar la sesión
        home: const AuthGate(),
      ),
    );
  }
}
