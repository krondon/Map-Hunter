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
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/inventory_service.dart';
import 'features/auth/services/power_service.dart';
import 'features/admin/services/admin_service.dart';
import 'features/game/providers/game_request_provider.dart';
import 'core/theme/app_theme.dart';

import 'features/game/providers/event_provider.dart'; 
import 'features/game/providers/power_effect_provider.dart';
import 'features/game/providers/power_interfaces.dart';
import 'features/game/providers/connectivity_provider.dart';
import 'features/admin/screens/admin_login_screen.dart'; 
import 'shared/widgets/sabotage_overlay.dart';
import 'shared/widgets/connectivity_monitor.dart';
import 'shared/utils/global_keys.dart'; // Importar llaves globales
import 'features/auth/widgets/auth_monitor.dart'; // Importar AuthMonitor
import 'shared/widgets/game_session_monitor.dart'; // Nuevo
import 'features/mall/providers/store_provider.dart';
import 'core/providers/app_mode_provider.dart';

import 'features/game/services/game_service.dart';

import 'features/mall/services/store_service.dart';
import 'features/events/services/event_service.dart';

// --- NEW: Phase 1 Refactoring Imports ---
import 'core/repositories/lives_repository.dart';
import 'core/repositories/mock_payment_repository.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'features/wallet/providers/payment_method_provider.dart';
import 'features/wallet/repositories/payment_method_repository.dart';
import 'features/auth/providers/player_inventory_provider.dart';
import 'features/auth/providers/player_stats_provider.dart';
import 'features/game/services/game_stream_service.dart';
import 'features/wallet/services/payment_service.dart';
import 'core/services/effect_timer_service.dart';
import 'features/game/repositories/power_repository_impl.dart';
import 'features/game/strategies/power_strategy_factory.dart';
import 'features/game/repositories/game_request_repository.dart';

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  
  runApp(const TreasureHuntApp());
}

class TreasureHuntApp extends StatelessWidget {
  const TreasureHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AdminService>(create: (_) => AdminService(supabaseClient: Supabase.instance.client)),
        
        // --- NEW: Infrastructure Layer (DIP) ---
        Provider<SupabaseLivesRepository>(create: (_) => SupabaseLivesRepository()),
        Provider<MockPaymentRepository>(create: (_) => MockPaymentRepository()),
        Provider<GameStreamService>(create: (_) => GameStreamService()),
        
        // --- Shared AuthService (Single Source of Truth) ---
        Provider<AuthService>(create: (_) => AuthService(supabaseClient: Supabase.instance.client)),

        // --- Existing Providers ---
        ChangeNotifierProvider(create: (context) {
          final supabase = Supabase.instance.client;
          final authService = Provider.of<AuthService>(context, listen: false); // Use shared instance
          
          final provider = PlayerProvider(
            supabaseClient: supabase,
            authService: authService,
            adminService: Provider.of<AdminService>(context, listen: false),
            inventoryService: InventoryService(supabaseClient: supabase),
            powerService: PowerService(supabaseClient: supabase),
          );
          
          // Register cleanup for logout
          authService.onLogout(() async => provider.resetState());
          
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
           final supabase = Supabase.instance.client;
           return EventProvider(eventService: EventService(supabase));
        }),
        // --- NEW: Phase 2 - Game Request Repository ---
        Provider<GameRequestRepository>(
          create: (_) => GameRequestRepository(supabaseClient: Supabase.instance.client),
        ),
        ChangeNotifierProvider(create: (context) {
          final repository = Provider.of<GameRequestRepository>(context, listen: false);
          return GameRequestProvider(repository: repository);
        }),
        ChangeNotifierProvider(create: (context) {
           final supabase = Supabase.instance.client;
           final authService = Provider.of<AuthService>(context, listen: false);
           
           final provider = GameProvider(gameService: GameService(supabase));
           
           // Register cleanup for logout
           authService.onLogout(() async => provider.resetState());
           
           return provider;
        }),
        Provider(create: (_) {
            final supabase = Supabase.instance.client;
            return PenaltyService(supabase);
        }),
        ChangeNotifierProvider(create: (_) {
            final supabase = Supabase.instance.client;
            return StoreProvider(storeService: StoreService(supabase));
        }),
        ChangeNotifierProvider(create: (context) {
           final supabase = Supabase.instance.client;
           final timerService = EffectTimerService();
           final repository = PowerRepositoryImpl(supabaseClient: supabase);
           final strategyFactory = PowerStrategyFactory(supabase);
           
           final provider = PowerEffectProvider(
             repository: repository,
             timerService: timerService,
             strategyFactory: strategyFactory,
           );
           final authService = Provider.of<AuthService>(context, listen: false);
           authService.onLogout(() async => provider.resetState());
           return provider;
        }),
        // ISP Proxies
        ListenableProxyProvider<PowerEffectProvider, PowerEffectReader>(
           update: (_, provider, __) => provider,
        ),
        ListenableProxyProvider<PowerEffectProvider, PowerEffectManager>(
           update: (_, provider, __) => provider,
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        
        // --- NEW: SRP-Segregated Providers ---
        ChangeNotifierProvider(create: (context) {
          final supabase = Supabase.instance.client;
          final authService = Provider.of<AuthService>(context, listen: false);
          
          final provider = PlayerInventoryProvider(
            inventoryService: InventoryService(supabaseClient: supabase),
          );
          
          // Register cleanup for logout
          authService.onLogout(() async => provider.resetState());
          
          return provider;
        }),
        ChangeNotifierProvider(create: (context) {
          final livesRepo = Provider.of<SupabaseLivesRepository>(context, listen: false);
          return PlayerStatsProvider(livesRepository: livesRepo);
        }),
        ChangeNotifierProvider(create: (context) {
          final paymentRepo = Provider.of<MockPaymentRepository>(context, listen: false);
          // Create PaymentService here or perform specialized DI if needed.
          // Since it's stateless (depends only on Supabase), we can create it here.
          final supabase = Supabase.instance.client;
          final paymentService = PaymentService(supabase);
          
          return WalletProvider(
            paymentRepository: paymentRepo,
            paymentService: paymentService,
          );
        }),
        
        // --- NEW: Payment Method Management ---
        Provider<PaymentMethodRepository>(
          create: (_) => PaymentMethodRepository(supabaseClient: Supabase.instance.client),
        ),
        ChangeNotifierProvider(create: (context) {
          final repo = Provider.of<PaymentMethodRepository>(context, listen: false);
          final authService = Provider.of<AuthService>(context, listen: false);
          
          final provider = PaymentMethodProvider(repository: repo);
          
          // Register cleanup for logout
          authService.onLogout(() async => provider.resetState());
          
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'MapHunter',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return AuthMonitor(
            child: ConnectivityMonitor(
              child: GameSessionMonitor( // Monitoreo de reinicio
                child: SabotageOverlay(child: child ?? const SizedBox()),
              ),
            ),
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