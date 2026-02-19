import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../game/providers/power_effect_provider.dart';
import '../../game/models/clue.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'wallet_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/utils/global_keys.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import '../../../shared/widgets/master_tutorial_content.dart';

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
    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4), // Espacio para el efecto de doble borde
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: currentRed, width: 2),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: currentRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¿Estás seguro que deseas cerrar sesión?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          playerProvider.logout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'SALIR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
              border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.6), width: 2), // Borde morado sólido interno
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
    final nameController = TextEditingController(text: player.name);
    final emailController = TextEditingController(text: player.email);
    bool isSaving = false;

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
              const Text("NOMBRE DE USUARIO",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.accentGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Correo
              const Text("CORREO ELECTRÓNICO",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.accentGold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        final newEmail = emailController.text.trim();

                        if (newName.isEmpty || newEmail.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Todos los campos son obligatorios")),
                          );
                          return;
                        }

                        // Validar palabras inadecuadas
                        if (InputSanitizer.hasInappropriateContent(newName)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "El nombre contiene palabras no permitidas"),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);

                        try {
                          final playerProvider = Provider.of<PlayerProvider>(
                              context,
                              listen: false);
                          await playerProvider.updateProfile(
                            name: newName != player.name ? newName : null,
                            email: newEmail != player.email ? newEmail : null,
                          );

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text("Perfil actualizado correctamente"),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
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
                    ? const LoadingIndicator(fontSize: 14, color: Colors.black)
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
    );
  }

  void _showDeleteConfirmation() {
// [FIX] Controller lifecycle managed manually to prevent "used after disposed" error
    final passwordController = TextEditingController();
    bool isDeleting = false;
    bool obscurePassword = true;
    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                        const Icon(Icons.warning_amber_rounded, color: currentRed, size: 28),
                        const SizedBox(width: 12),
                        const Flexible(
                          child: Text(
                            "Borrar Cuenta",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Esta acción ELIMINARÁ permanentemente:",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                      style: TextStyle(color: currentRed, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isDeleting,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Contraseña",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: currentRed.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: currentRed),
                        ),
                        prefixIcon: const Icon(Icons.lock, color: currentRed, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isDeleting ? null : () async {
                              final password = passwordController.text.trim();
                              if (password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Debes ingresar tu contraseña"), backgroundColor: currentRed),
                                );
                                return;
                              }
                              setDialogState(() => isDeleting = true);
                              try {
                                final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                                // [FIX] Limpiar efectos de sabotaje ANTES del borrado
                                if (context.mounted) {
                                  context.read<PowerEffectProvider>().resetState();
                                }
                                await playerProvider.deleteAccount(password);
                                if (!ctx.mounted) return;
                                if (playerProvider.isLoggedIn) {
                          Navigator.pop(ctx);
                        } else {
                          // Logged out successfully - dialog dies with route
                        }
                                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                                if (context.mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                                }
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setDialogState(() => isDeleting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e"), backgroundColor: currentRed),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isDeleting
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text("Borrar", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      // [FIX] Dispose controller ONLY after dialog is closed
      passwordController.dispose();
    });
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
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2), // Borde sólido interno
            ),
            child: const Center(
              child: Text("Inicia una visión recolectar sellos",
                  style: TextStyle(color: Colors.white24, fontSize: 14)))
          ),
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
                        child: Text(
                          "Centro de Ayuda", 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white38, size: 20),
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
                          content: Text("Contactando con el sistema central..."), 
                          backgroundColor: AppTheme.primaryPurple
                        ),
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

  void _showTermsDialog() {
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: currentGold),
                    const SizedBox(width: 12),
                    const Text('Términos',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: Text(
                      'Al utilizar el protocolo Asthoria, aceptas que toda actividad de exploración queda bajo tu responsabilidad. '
                      'El equipo de MapHunter no se hace responsable por encuentros con entidades digitales o físicas durante la recolección de sellos.\n\n'
                      'Tus datos están protegidos por encriptación de grado militar y nunca serán compartidos fuera de la red local del evento. '
                      'Cualquier intento de sabotaje o hackeo del sistema resultará en la expulsión inmediata y pérdida deXP.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
