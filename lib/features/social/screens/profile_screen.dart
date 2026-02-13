import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
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
                  style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 16)),
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
                    _buildGamerCard(player, isDarkMode),
                    
                    const SizedBox(height: 24),
                    
                    // 2. TRÉBOLES DORADOS - NEW ANIMATED SECTION
                    _buildGoldenCloversSection(gameProvider, isDarkMode),
                    
                    const SizedBox(height: 24),
                    
                    const SizedBox(height: 40),
                    const Text("ASTHORIA PROTOCOL v1.0.4", 
                      style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 4)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        );

    final content = widget.hideScaffold 
        ? mainScroll 
        : AnimatedCyberBackground(child: mainScroll);

    if (widget.hideScaffold) return content;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      body: content,
    );
  }

  void _showLogoutDialog(PlayerProvider playerProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Provider.of<PlayerProvider>(context, listen: false).isDarkMode ? AppTheme.cardBg : Colors.white,
        title: Text('Cerrar Sesión',
            style: TextStyle(color: Provider.of<PlayerProvider>(context, listen: false).isDarkMode ? Colors.white : const Color(0xFF1A1A1D))),
        content: Text(
          '¿Estás seguro que deseas cerrar sesión?',
          style: TextStyle(color: Provider.of<PlayerProvider>(context, listen: false).isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              playerProvider.logout();
              // AuthMonitor will handle navigation
            },
            child: const Text('Salir',
                style: TextStyle(color: AppTheme.dangerRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildGamerCard(dynamic player, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.cardBg.withOpacity(0.8) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(isDarkMode ? 0.3 : 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(isDarkMode ? 0.2 : 0.1), 
            blurRadius: 30, 
            offset: const Offset(0, 10)
          )
        ]
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: player.experienceProgress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accentGold),
                ),
              ),
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.secondaryPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.5), blurRadius: 15)
                    ]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(47.5),
                  child: Builder(
                    builder: (context) {
                      final avatarId = player.avatarId;

                      // 1. Prioridad: Avatar Local
                      if (avatarId != null && avatarId.isNotEmpty) {
                        return Image.asset(
                          'assets/images/avatars/$avatarId.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              _getAvatarIcon(player.profession),
                              size: 55,
                              color: Colors.white),
                        );
                      }

                      // 2. Fallback: Foto de perfil (URL)
                      if (player.avatarUrl != null &&
                          player.avatarUrl!.startsWith('http')) {
                        return Image.network(
                          player.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              _getAvatarIcon(player.profession),
                              size: 55,
                              color: Colors.white),
                        );
                      }

                      // 3. Fallback: Icono de profesión
                      return Icon(_getAvatarIcon(player.profession),
                          size: 55, color: Colors.white);
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.accentGold,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, color: Colors.black45)
                      ]),
                  child: Text("LVL ${player.level}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black)),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Text(player.name.toUpperCase(), 
            style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(player.profession.toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.secondaryPink,
                  fontSize: 12,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w300)),

          const SizedBox(height: 30),

          // Single Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCompact(Icons.star, "${player.totalXP}", "XP TOTAL", AppTheme.secondaryPink, isDarkMode),
              _buildVerticalDivider(),
              _buildStatCompact(Icons.eco, "${player.clovers}", "TRÉBOLES", Colors.green, isDarkMode),
              _buildVerticalDivider(),
              _buildStatCompact(Icons.emoji_events, "${player.eventsCompleted?.length ?? 0}", "EVENTOS", Colors.cyan, isDarkMode),
            ],
          ),

          const SizedBox(height: 24),

          // Horizontal Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black12,
              thickness: 1,
            ),
          ),

          const SizedBox(height: 24),

          // Edit/Delete Profile Buttons
          Row(
            children: [
              Expanded(
                child: _buildProfileButton(
                  icon: Icons.edit,
                  label: "Editar Perfil",
                  color: AppTheme.primaryPurple,
                  onTap: () => _showEditProfileSheet(player),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProfileButton(
                  icon: Icons.delete_outline,
                  label: "Borrar Cuenta",
                  color: AppTheme.dangerRed,
                  onTap: () => _showDeleteConfirmation(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Support Button
          // Support Button
          Row(
            children: [
              Expanded(
                child: _buildProfileButton(
                  icon: Icons.logout,
                  label: "Cerrar Sesión",
                  color: AppTheme.dangerRed,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.cardBg,
                        title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
                        content: const Text("¿Estás seguro que deseas salir?", style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Salir", style: TextStyle(color: AppTheme.dangerRed)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await context.read<PlayerProvider>().logout();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
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
    );
  }

  Widget _buildProfileButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
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
                  : const Text("GUARDAR CAMBIOS", style: TextStyle(fontWeight: FontWeight.bold)),
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
    final passwordController = TextEditingController();
    bool isDeleting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.3)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.dangerRed, size: 28),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  "Borrar Cuenta",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      color: AppTheme.dangerRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
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
                      borderSide: BorderSide(
                          color: AppTheme.dangerRed.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.dangerRed),
                    ),
                    prefixIcon: const Icon(Icons.lock,
                        color: AppTheme.dangerRed, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        setDialogState(
                            () => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting
                  ? null
                  : () {
                      passwordController.dispose();
                      Navigator.pop(ctx);
                    },
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      final password = passwordController.text.trim();

                      if (password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Debes ingresar tu contraseña"),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isDeleting = true);

                      try {
                        final playerProvider =
                            Provider.of<PlayerProvider>(context, listen: false);
                        await playerProvider.deleteAccount(password);

                        if (!ctx.mounted) return;
                        passwordController.dispose();
                        Navigator.pop(ctx); // Cerrar diálogo

                        // Restablecer modo UI inmersivo antes de navegar
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.immersiveSticky);

                        // Forzar navegación al login
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login', (route) => false);
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;

                        setDialogState(() => isDeleting = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isDeleting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Borrar",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildGoldenCloversSection(GameProvider gameProvider, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("TRÉBOLES DORADOS",
                style: TextStyle(
                    color: AppTheme.accentGold,
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            Text("${gameProvider.completedClues}/${gameProvider.totalClues}",
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          ),
          child: gameProvider.clues.isEmpty
              ? const Center(
                  child: Text("Inicia una misión para recolectar tréboles",
                      style: TextStyle(color: Colors.white24, fontSize: 12)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  itemCount: gameProvider.clues.length,
                  itemBuilder: (context, index) {
                    final clue = gameProvider.clues[index];
                    final bool isCollected = clue.isCompleted;

                    return _buildStampItem(clue, isCollected, index);
                  },
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

  Widget _buildStatCompact(IconData icon, String value, String label, Color color, bool isDarkMode) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D), fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38, fontSize: 9, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 35, color: Provider.of<PlayerProvider>(context, listen: false).isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05));
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.accentGold),
            SizedBox(width: 12),
            Text("Centro de Ayuda", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿Necesitas ayuda con el protocolo Asthoria?",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildSupportOption(
              icon: Icons.chat_bubble_outline,
              label: "Contactar Soporte Técnico",
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Contactando con el sistema central..."), backgroundColor: AppTheme.primaryPurple),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption({required IconData icon, required String label, required VoidCallback onTap}) {
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
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          ],
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
