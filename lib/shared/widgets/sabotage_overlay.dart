import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/game/providers/power_effect_provider.dart';
import '../../features/game/widgets/effects/blind_effect.dart';
import '../../features/game/widgets/effects/freeze_effect.dart';
import '../../features/game/widgets/effects/blur_effect.dart';
import '../../features/game/widgets/effects/life_steal_effect.dart';
import '../../features/game/widgets/effects/return_success_effect.dart';
import '../../features/game/widgets/effects/return_rejection_effect.dart';
import '../../features/game/widgets/effects/invisibility_effect.dart';
import '../models/player.dart';
import '../../features/auth/providers/player_provider.dart';

class SabotageOverlay extends StatefulWidget {
  final Widget child;
  const SabotageOverlay({super.key, required this.child});

  @override
  State<SabotageOverlay> createState() => _SabotageOverlayState();
}

class _SabotageOverlayState extends State<SabotageOverlay> {
  String? _lifeStealBannerText;
  Timer? _lifeStealBannerTimer;
  String? _lastLifeStealEffectId;

  @override
  void dispose() {
    _lifeStealBannerTimer?.cancel();
    super.dispose();
  }

  void _showLifeStealBanner(String message,
      {Duration duration = const Duration(seconds: 3)}) {
    _lifeStealBannerTimer?.cancel();
    setState(() {
      _lifeStealBannerText = message;
    });
    _lifeStealBannerTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _lifeStealBannerText = null;
      });
    });
  }

  String _resolvePlayerNameFromLeaderboard(String? casterGamePlayerId) {
    if (casterGamePlayerId == null || casterGamePlayerId.isEmpty)
      return 'Un rival';
    final gameProvider = context.read<GameProvider>();
    final match = gameProvider.leaderboard.whereType<Player>().firstWhere(
          (p) =>
              p.gamePlayerId == casterGamePlayerId ||
              p.id == casterGamePlayerId,
          orElse: () =>
              Player(id: '', name: 'Un rival', email: '', avatarUrl: ''),
        );
    return match.name.isNotEmpty ? match.name : 'Un rival';
  }

  @override
  Widget build(BuildContext context) {
    final powerProvider = Provider.of<PowerEffectProvider>(context);
    final activeSlug = powerProvider.activePowerSlug;
    final defenseAction = powerProvider.lastDefenseAction;
    final playerProvider = Provider.of<PlayerProvider>(context);
    // Detectamos si el usuario actual es invisible según el PlayerProvider
  final isPlayerInvisible = playerProvider.currentPlayer?.isInvisible ?? false;

    // Banner life_steal (Point B): sólo banner, no bloquea interacción.
    if (activeSlug == 'life_steal') {
      final effectId = powerProvider.activeEffectId;
      if (effectId != null && effectId != _lastLifeStealEffectId) {
        _lastLifeStealEffectId = effectId;
        final attackerName = _resolvePlayerNameFromLeaderboard(
            powerProvider.activeEffectCasterId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showLifeStealBanner('¡$attackerName te ha quitado una vida!');
        });
      }
    }

    

    return Stack(
      children: [
        widget.child, // El juego base siempre debajo

        // Capas de sabotaje (se activan según el slug recibido de la DB)
        if (activeSlug == 'black_screen') const BlindEffect(),
        if (activeSlug == 'freeze') const FreezeEffect(),
        if (defenseAction == DefenseAction.returned)
      ReturnRejectionEffect(returnedBy: powerProvider.returnedByPlayerName),
        if (activeSlug == 'life_steal')
          LifeStealEffect(
              casterName: _resolvePlayerNameFromLeaderboard(
                  powerProvider.activeEffectCasterId)),
        // Por ahora: invisibility NO debe hacer nada.
        // blur_screen reutiliza el efecto visual de invisibility para los rivales.
        // --- ATAQUES RECIBIDOS ---
      if (activeSlug == 'blur_screen') const BlurScreenEffect(), // El efecto que marea
      
      // --- ESTADOS BENEFICIOSOS (BUFFS) ---
     if (isPlayerInvisible || activeSlug == 'invisibility') 
        const InvisibilityEffect(),

        if (activeSlug == 'return' && powerProvider.activeEffectCasterId != powerProvider.listeningForId)
        const ReturnSuccessEffect(),

        if (defenseAction == DefenseAction.shieldBlocked)
      _DefenseFeedbackToast(action: defenseAction),

        if (_lifeStealBannerText != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_lifeStealBannerText),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lifeStealBannerText!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Feedback rápido para el atacante cuando su acción fue bloqueada o devuelta.
        _DefenseFeedbackToast(action: defenseAction),
      ],
    );
  }
}

class _DefenseFeedbackToast extends StatelessWidget {
  final DefenseAction? action;

  const _DefenseFeedbackToast({required this.action});

  @override
  Widget build(BuildContext context) {
    // Si la acción es 'returned', devolvemos shrink porque el mensaje detallado 
    // (ReturnRejectionEffect) ya se está mostrando en el Stack principal.
    if (action == null || action == DefenseAction.returned) {
      return const SizedBox.shrink();
    }

    // Aquí solo llegamos si action == DefenseAction.shieldBlocked
    const String message = '🛡️ ¡ATAQUE BLOQUEADO POR ESCUDO!';

    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(action),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}