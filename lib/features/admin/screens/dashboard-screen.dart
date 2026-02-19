import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../services/admin_service.dart';
import 'event_creation_screen.dart';
import '../providers/event_creation_provider.dart';
import 'competitions_management_screen.dart';
import 'user_management_screen.dart';
import 'admin_login_screen.dart';
import 'clover_plans_management_screen.dart';
import 'withdrawal_plans_management_screen.dart';
import 'global_config_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'minigames/sequence_config_screen.dart';
import 'minigames/drink_mixer_config_screen.dart';
import 'audit_logs_screen.dart';
import 'sponsors_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    "Dashboard",
    "Crear Evento",
    "Competencias",
    "Usuarios",
    "Compras",
    "Retiros",
    "Reportes",
    "Minijuegos",
    "Patrocinadores",
    "Auditoría",
    "Configuración"
  ];

  final List<IconData> _icons = [
    Icons.dashboard,
    Icons.add_circle_outline,
    Icons.emoji_events,
    Icons.people,
    Icons.local_offer,
    Icons.money_off,
    Icons.bar_chart,
    Icons.games,
    Icons.business_center,
    Icons.history_edu,
    Icons.settings,
  ];

  /// Método para resetear la vista al Dashboard principal.
  /// Se pasa como callback al EventCreationScreen.
  void _goToDashboard() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title:
            const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que deseas salir?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      // Reset system UI mode before logout
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await Provider.of<PlayerProvider>(context, listen: false).logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // DEFINIMOS LAS VISTAS DENTRO DEL BUILD
    // Esto es necesario para poder pasarle la función _goToDashboard
    final List<Widget> views = [
      _WelcomeDashboardView(
        onNavigate: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ), // Index 0

      // Index 1: Le pasamos el callback aquí
      ChangeNotifierProvider(
        create: (_) => EventCreationProvider(),
        child: EventCreationScreen(
          onEventCreated: _goToDashboard,
        ),
      ),

      const CompetitionsManagementScreen(), // Index 2
      const UserManagementScreen(), // Index 3
      const CloverPlansManagementScreen(), // Index 4 - Planes Compra
      const WithdrawalPlansManagementScreen(), // Index 5 - Planes Retiro
      const Center(
          child: Text('Reportes - En desarrollo',
              style: TextStyle(color: Colors.white54))), // Index 6 - Reportes
      const _MinigamesListView(), // Index 7 - Minijuegos
      const SponsorsManagementScreen(), // Index 8 - Patrocinadores
      const AuditLogsScreen(), // Index 9 - Auditoría
      const GlobalConfigScreen(), // Index 10 - Configuración
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: AppTheme.darkBg,
          body: SafeArea(
            child: Column(
              children: [
                // ------------------------------------------------
                // 1. HEADER SUPERIOR (Logo + Usuario)
                // ------------------------------------------------
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Logo / Título
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.admin_panel_settings,
                            color: AppTheme.primaryPurple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Sistema Admin", // Shortened title
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "MapHunter Admin",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Información de Usuario
                      Row(
                        children: [
                          // Ocutar email en pantallas muy pequeñas si es necesario,
                          // pero con Expanded en el titulo deberia bastar.
                          // Usaremos un constrained box para el email si queremos.
                          if (MediaQuery.of(context).size.width > 600) ...[
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: const [
                                Text(
                                  "Administrador",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "admin@system.com",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                          ],
                          CircleAvatar(
                            backgroundColor: AppTheme.secondaryPink,
                            radius: 16, // Smaller avatar
                            child: const Text("A",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.logout, color: Colors.white54),
                            tooltip: "Salir",
                            onPressed: () => _handleLogout(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ------------------------------------------------
                // 2. BARRA DE NAVEGACIÓN HORIZONTAL
                // ------------------------------------------------
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2342),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _titles.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndex == index;
                      return GestureDetector(
                        onTap: () {
                          // Usamos la lista local 'views' para verificar longitud
                          if (index < views.length) {
                            setState(() => _selectedIndex = index);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Módulo en desarrollo")));
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryPurple.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color:
                                        AppTheme.primaryPurple.withOpacity(0.5))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _icons[index],
                                size: 20,
                                color: isSelected
                                    ? AppTheme.primaryPurple
                                    : Colors.white54,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _titles[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryPurple
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ------------------------------------------------
                // 3. ÁREA DE CONTENIDO PRINCIPAL
                // ------------------------------------------------
                Expanded(
                  child: AnimatedCyberBackground(
                    child: IndexedStack(
                      // Usamos la lista local 'views'
                      index: _selectedIndex < views.length ? _selectedIndex : 0,
                      children: views,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// WIDGETS AUXILIARES
// ------------------------------------------------------------------

class _WelcomeDashboardView extends StatefulWidget {
  final void Function(int)? onNavigate;
  const _WelcomeDashboardView({this.onNavigate});

  @override
  State<_WelcomeDashboardView> createState() => _WelcomeDashboardViewState();
}

class _WelcomeDashboardViewState extends State<_WelcomeDashboardView> {
  String _activeUsers = "...";
  String _createdEvents = "...";
  String _pendingRequests = "...";

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final adminService = context.read<AdminService>();
      final stats = await adminService.fetchGeneralStats();

      if (mounted) {
        setState(() {
          _activeUsers = stats.activeUsers.toString();
          _createdEvents = stats.createdEvents.toString();
          _pendingRequests = stats.pendingRequests.toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) {
        setState(() {
          _activeUsers = "-";
          _createdEvents = "-";
          _pendingRequests = "-";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics, size: 80, color: Colors.white24),
              const SizedBox(height: 20),
              const Text(
                "Bienvenido al Panel de Administración",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Selecciona una opción del menú superior para comenzar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _SummaryCard(
                      title: "Usuarios Activos",
                      value: _activeUsers,
                      color: Colors.blue),
                  _SummaryCard(
                      title: "Eventos Creados",
                      value: _createdEvents,
                      color: Colors.orange),
                  _SummaryCard(
                    title: "Solicitudes Pendientes",
                    value: _pendingRequests,
                    color: Colors.purple,
                    onTap: () => widget.onNavigate
                        ?.call(2), // Navigate to Competitions (Index 2)
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinigamesListView extends StatelessWidget {
  const _MinigamesListView();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> minigames = [
      {
        'title': 'Secuencia de Memoria',
        'subtitle': 'Juego tipo Simon Dice con colores neón.',
        'icon': Icons.psychology,
        'color': Colors.cyanAccent,
        'screen': const SequenceConfigScreen(),
      },
      {
        'title': 'Cócteles de Neón',
        'subtitle': 'Mezcla de sabores y colores en el bar.',
        'icon': Icons.local_bar,
        'color': Colors.pinkAccent,
        'screen': const DrinkMixerConfigScreen(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Configuración de Minijuegos",
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Prueba y ajusta los parámetros de los desafíos del juego.",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: minigames.length,
              itemBuilder: (context, index) {
                final mg = minigames[index];
                return Card(
                  color: AppTheme.cardBg,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (mg['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(mg['icon'], color: mg['color']),
                    ),
                    title: Text(mg['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    subtitle: Text(mg['subtitle'],
                        style: const TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white24, size: 16),
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => mg['screen']));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard(
      {required this.title,
      required this.value,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
