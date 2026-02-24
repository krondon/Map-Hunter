import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../game/providers/power_effect_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../game/models/clue.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'wallet_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../game/screens/game_mode_selector_screen.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/utils/global_keys.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final bool hideScaffold;
  const ProfileScreen({super.key, this.hideScaffold = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final gameProvider = Provider.of<GameProvider>(context);
    final player = playerProvider.currentPlayer;
    final isDarkMode = playerProvider.isDarkMode;

    if (player == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }

    final mainScroll = CustomScrollView(
      slivers: [
        if (!widget.hideScaffold)
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            backgroundColor: Colors.black.withOpacity(0.5),
            title: const Text('ID DE JUGADOR',
                style: TextStyle(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.dangerRed),
                onPressed: () {
                  _showLogoutDialog(playerProvider);
                },
              ),
            ],
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 1. GAMER CARD WITH NEON GLOW
                _buildGamerCard(player, isDarkMode, playerProvider),

                const SizedBox(height: 24),

                // 2. TRÉBOLES DORADOS - NEW ANIMATED SECTION
                _buildGoldenCloversSection(gameProvider, isDarkMode),

                const SizedBox(height: 24),

                const SizedBox(height: 40),
                const Text("ASTHORIA PROTOCOL v1.0.4",
                    style: TextStyle(
                        color: Colors.white10, fontSize: 10, letterSpacing: 4)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );

    final content = widget.hideScaffold
        ? mainScroll
        : AnimatedCyberBackground(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/fotogrupalnoche.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
                mainScroll,
              ],
            ),
          );

    if (widget.hideScaffold) return content;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      body: content,
    );
  }

  void _showLogoutDialog(PlayerProvider playerProvider) {
    final isDarkMode = playerProvider.isDarkMode;
    // FORCED DARK: Always use dark cyberpunk styling
    final Color surfaceColor = const Color(0xFF151517).withOpacity(0.95);
    final Color textColor = Colors.white;
    final Color textSecColor = Colors.white70;
    final Color accentColor = AppTheme.dGoldMain;

    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accentColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.15),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon with glow
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accentColor.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Icon(Icons.games_rounded,
                                color: accentColor, size: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '¿Qué deseas hacer?',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                accentColor.withOpacity(0.3),
                                accentColor,
                                accentColor.withOpacity(0.3)
                              ]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Puedes cambiar de modo de juego o cerrar tu sesión.',
                            style: TextStyle(
                                color: textSecColor, fontSize: 14, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // CAMBIAR MODO
                          _buildGradientButton(
                            icon: Icons.swap_horiz_rounded,
                            label: 'CAMBIAR MODO',
                            gradientColors: [
                              AppTheme.dGoldMain,
                              const Color(0xFFE5A700)
                            ],
                            textColor: Colors.black,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const GameModeSelectorScreen()),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // CERRAR SESIÓN
                          _buildGradientButton(
                            icon: Icons.logout_rounded,
                            label: 'CERRAR SESIÓN',
                            gradientColors: [
                              AppTheme.dangerRed,
                              const Color(0xFFB71C1C)
                            ],
                            textColor: Colors.white,
                            onTap: () {
                              Navigator.pop(context);
                              playerProvider.logout();
                              // AuthMonitor handles navigation to LoginScreen
                            },
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancelar',
                                style: TextStyle(
                                    color: textSecColor.withOpacity(0.5),
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 20),
          label: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: textColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _buildGamerCard(
      dynamic player, bool isDarkMode, PlayerProvider playerProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4), // Espacio para el efecto de doble borde
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF150826).withOpacity(0.4),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: AppTheme.primaryPurple.withOpacity(0.6),
                  width: 2), // Borde morado sólido interno
            ),
            child: Stack(
              children: [
                // Level Badge (Top Right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withOpacity(0.4),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Text(
                      "LVL ${player.level}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Section
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryPurple,
                                  AppTheme.secondaryPink.withOpacity(0.5)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(55),
                              child: Builder(
                                builder: (context) {
                                  final avatarId = player.avatarId;
                                  if (avatarId != null && avatarId.isNotEmpty) {
                                    return Image.asset(
                                      'assets/images/avatars/$avatarId.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person,
                                          size: 55,
                                          color: Colors.white),
                                    );
                                  }
                                  if (player.avatarUrl != null &&
                                      player.avatarUrl!.startsWith('http')) {
                                    return Image.network(
                                      player.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person,
                                          size: 55,
                                          color: Colors.white),
                                    );
                                  }
                                  return const Icon(Icons.person,
                                      size: 55, color: Colors.white);
                                },
                              ),
                            ),
                          ),
                        ),
                        // Camera Overlay
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF1A1A1D), width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Name and Profession
                    Text(
                      player.name.toUpperCase(),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      player.profession.toUpperCase(),
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatWidget(
                            const Icon(Icons.stars,
                                color: AppTheme.secondaryPink, size: 28),
                            "${player.totalXP}",
                            "XP Total"),
                        _buildStatWidget(
                            const Text("🍀", style: TextStyle(fontSize: 24)),
                            "${player.clovers}",
                            "Tréboles"),
                        _buildStatWidget(
                            const Icon(Icons.emoji_events,
                                color: AppTheme.accentGold, size: 28),
                            "${player.eventsCompleted?.length ?? 0}",
                            "Eventos"),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Divider(color: Colors.white.withOpacity(0.1), height: 1),

                    const SizedBox(height: 32),

                    // Buttons Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileButton(
                            icon: Icons.edit_outlined,
                            label: "Editar Perfil",
                            color: AppTheme.primaryPurple,
                            onTap: () => _showEditProfileSheet(player),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileButton(
                            icon: Icons.backspace_outlined,
                            label: "Borrar Cuenta",
                            color: AppTheme.dangerRed,
                            onTap: () => _showDeleteConfirmation(),
                            isRed: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Buttons Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileButton(
                            icon: Icons.logout,
                            label: "Cerrar Sesión",
                            color: Colors.orangeAccent,
                            onTap: () {
                              _showLogoutDialog(playerProvider);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileButton(
                            icon: Icons.support_agent,
                            label: "Soporte",
                            color: AppTheme.accentGold,
                            onTap: _showSupportDialog,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isRed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isRed ? color : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet(dynamic player) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: player.name);
    final emailController = TextEditingController(text: player.email);
    final phoneController = TextEditingController(text: player.phone ?? '');
    bool isSaving = false;

    // Registration-matching banned words
    final bannedWords = [
      'admin',
      'root',
      'moderator',
      'tonto',
      'estupido',
      'idiota',
      'groseria',
      'puto',
      'mierda',
    ];

    InputDecoration _fieldDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: AppTheme.accentGold, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accentGold),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "EDITAR PERFIL",
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Nombre
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(50),
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZñÑáéíóúÁÉÍÓÚ\s]')),
                    ],
                    decoration: _fieldDecoration(
                        'NOMBRE COMPLETO', Icons.person_outline),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu nombre';
                      }
                      if (!value.trim().contains(' ')) {
                        return 'Ingresa Nombre y Apellido';
                      }
                      final lowerName = value.toLowerCase();
                      for (final word in bannedWords) {
                        if (lowerName.contains(word)) {
                          return 'El nombre contiene palabras no permitidas';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Correo
                  TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldDecoration(
                        'CORREO ELECTRÓNICO', Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu email';
                      }
                      final emailRegex =
                          RegExp(r'^[\w.\-]+@[\w.\-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Formato de email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Teléfono
                  TextFormField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: _fieldDecoration(
                        'TELÉFONO (04XX...)', Icons.phone_android_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu teléfono';
                      }
                      if (value.length < 11) {
                        return 'Ingresa el número completo (11 dígitos)';
                      }
                      final prefixRegex = RegExp(r'^04(12|14|24|16|26|22)');
                      if (!prefixRegex.hasMatch(value)) {
                        return 'Prefijo inválido (ej: 0412...)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final newName = nameController.text.trim();
                            final newEmail =
                                emailController.text.trim().toLowerCase();
                            final newPhone = phoneController.text.trim();

                            // Check if email is changing
                            final emailIsChanging =
                                newEmail != (player.email ?? '').toLowerCase();

                            // Force sending the email if it hasn't been verified yet
                            final sendEmail =
                                emailIsChanging || !player.emailVerified;

                            // Show confirmation dialog if email changes
                            if (emailIsChanging) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1A1A1D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color:
                                          AppTheme.accentGold.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: AppTheme.accentGold),
                                      SizedBox(width: 8),
                                      Text("Cambio de Email",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16)),
                                    ],
                                  ),
                                  content: const Text(
                                    "Al cambiar tu correo, se enviará un email de verificación. "
                                    "No podrás participar en eventos hasta que lo verifiques.\n\n"
                                    "¿Deseas continuar?",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogCtx, false),
                                      child: const Text("CANCELAR",
                                          style:
                                              TextStyle(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogCtx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentGold,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: const Text("SÍ, CAMBIAR"),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                            }

                            setModalState(() => isSaving = true);

                            try {
                              final playerProvider =
                                  Provider.of<PlayerProvider>(context,
                                      listen: false);
                              final emailChanged =
                                  await playerProvider.updateProfile(
                                name: newName != player.name ? newName : null,
                                email: sendEmail ? newEmail : null,
                                phone: newPhone != (player.phone ?? '')
                                    ? newPhone
                                    : null,
                              );

                              if (mounted) {
                                Navigator.pop(ctx);

                                if (emailChanged) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.mark_email_read_outlined,
                                              color: Colors.white),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              "Se envió un email de verificación a tu nuevo correo. "
                                              "Verifícalo para continuar jugando.",
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 6),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Perfil actualizado correctamente"),
                                      backgroundColor: AppTheme.successGreen,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                setModalState(() => isSaving = false);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: AppTheme.dangerRed),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const LoadingIndicator(
                            fontSize: 14, color: Colors.black)
                        : const Text("GUARDAR CAMBIOS",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("CANCELAR",
                        style: TextStyle(color: Colors.white54)),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal while deleting
      builder: (context) => const _DeleteAccountDialog(),
    );
  }

  Widget _buildGoldenCloversSection(
      GameProvider gameProvider, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("SELLOS TEMPORALES",
                style: TextStyle(
                    color: AppTheme.accentGold,
                    letterSpacing: 2,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const Text("0/0", // Placeholder matching reference
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4), // Efecto de doble borde
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2), // Borde sólido interno
              ),
              child: const Center(
                  child: Text("Inicia una visión recolectar sellos",
                      style: TextStyle(color: Colors.white24, fontSize: 14)))),
        ),
      ],
    );
  }

  Widget _buildStampItem(Clue clue, bool isCollected, int index) {
    final gradient = _getStampGradient(index);

    return Container(
      width: 75,
      margin: const EdgeInsets.only(right: 15),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 1000 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCollected ? null : Colors.black45,
                      gradient:
                          isCollected ? LinearGradient(colors: gradient) : null,
                      border: Border.all(
                          color: isCollected ? Colors.white : Colors.white10,
                          width: isCollected ? 2 : 1),
                      boxShadow: isCollected
                          ? [
                              BoxShadow(
                                  color: gradient[0].withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1)
                            ]
                          : null,
                    ),
                    child: Icon(
                      _getStampIcon(index),
                      size: 24,
                      color: isCollected ? Colors.white : Colors.white10,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text("T${index + 1}",
              style: TextStyle(
                  fontSize: 10,
                  color: isCollected ? Colors.white70 : Colors.white10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAttributeBar(String label, int value, Color color) {
    double progress = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              Text("$value%",
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatWidget(Widget icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 30, child: Center(child: icon)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
        width: 1,
        height: 35,
        color: Provider.of<PlayerProvider>(context, listen: false).isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05));
  }

  IconData _getAvatarIcon(String profession) {
    switch (profession.toLowerCase()) {
      case 'speedrunner':
        return Icons.flash_on;
      case 'strategist':
        return Icons.psychology;
      case 'warrior':
        return Icons.shield;
      case 'balanced':
        return Icons.stars;
      case 'novice':
        return Icons.explore;
      default:
        return Icons.person;
    }
  }

  IconData _getStampIcon(int index) {
    return Icons.eco;
  }

  List<Color> _getStampGradient(int index) {
    return [const Color(0xFFFFD700), const Color(0xfff5c71a)];
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.weekend, 'Local'),
            _buildNavItem(1, Icons.explore, 'Escenarios'),
            _buildNavItem(2, Icons.account_balance_wallet, 'Recargas'),
            _buildNavItem(3, Icons.person, 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = index == 3; // Perfil is always selected in this screen
    return GestureDetector(
      onTap: () {
        // Navigation logic
        switch (index) {
          case 0: // Local
            _showComingSoonDialog(label);
            break;
          case 1: // Escenarios
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ScenariosScreen(),
              ),
            );
            break;
          case 2: // Recargas
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WalletScreen(),
              ),
            );
            break;
          case 3: // Perfil - already here
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentGold : Colors.white54,
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSupportDialog() {
    const Color currentGold = AppTheme.accentGold;
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentGold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentGold.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentGold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentGold.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, color: currentGold),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text("Centro de Ayuda",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close,
                            color: Colors.white38, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "¿Necesitas ayuda con el protocolo Asthoria?",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _buildSupportOption(
                    icon: Icons.chat_bubble_outline,
                    label: "Contactar Soporte Técnico",
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Contactando con el sistema central..."),
                            backgroundColor: AppTheme.primaryPurple),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSupportOption(
                    icon: Icons.description_outlined,
                    label: "Términos y Condiciones",
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTermsDialog();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentGold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showTermsDialog() async {
    // Construcción dinámica de la URL del proxy
    // Enrutador seguro en Vercel
    const String termsUrl = 'https://map-hunter.vercel.app/terms';

    final Uri url =
        Uri.parse('https://docs.google.com/gview?embedded=true&url=$termsUrl');

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir los Términos y Condiciones.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al abrir términos: $e');
    }
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.construction, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text(
              'Próximamente',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({super.key});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isDeleting = false;
  bool _obscurePassword = true;

  static const Color currentRed = Color(0xFFE33E5D);
  static const Color cardBg = Color(0xFF151517);

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: currentRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: currentRed.withOpacity(0.5), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: currentRed, width: 2),
            boxShadow: [
              BoxShadow(
                color: currentRed.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: currentRed, size: 28),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        "Borrar Cuenta",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Esta acción ELIMINARÁ permanentemente:",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  "• Todo tu progreso\n"
                  "• Tus items y monedas\n"
                  "• Tu historial de eventos\n"
                  "• Todos tus datos",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ingresa tu contraseña:",
                  style: TextStyle(
                      color: currentRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isDeleting,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Contraseña",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: currentRed.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: currentRed),
                    ),
                    prefixIcon:
                        const Icon(Icons.lock, color: currentRed, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isDeleting ? null : () => Navigator.pop(context),
                        child: const Text("Cancelar",
                            style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : _handleDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text("Borrar",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Debes ingresar tu contraseña"),
            backgroundColor: currentRed),
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // Limpiar efectos de sabotaje ANTES del borrado
      if (mounted) {
        context.read<PowerEffectProvider>().resetState();
      }

      await playerProvider.deleteAccount(password);

      if (!mounted) return;

      if (playerProvider.isLoggedIn) {
        // Si sigue logueado, es que falló algo sin lanzar excepción (raro pero posible)
        Navigator.pop(context);
      } else {
        // Logged out successfully
        Navigator.pop(context); // Close dialog
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: currentRed),
      );
    }
  }
}
