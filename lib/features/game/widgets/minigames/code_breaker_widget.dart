import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../models/clue.dart';
import '../../../../core/theme/app_theme.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class CodeBreakerWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const CodeBreakerWidget(
      {super.key, required this.clue, required this.onSuccess});

  @override
  State<CodeBreakerWidget> createState() => _CodeBreakerWidgetState();
}

class _CodeBreakerWidgetState extends State<CodeBreakerWidget> {
  String _enteredCode = "";
  bool _isError = false;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool showShop = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _showShopButton = showShop;
    });
  }

  int _attempts = 3;

  void _checkCode() {
    final expected = widget.clue.riddleAnswer?.trim() ?? "";
    if (_enteredCode == expected) {
      widget.onSuccess();
    } else {
      setState(() {
        _enteredCode = "";
        _isError = true;
        _attempts--;
      });

      if (_attempts <= 0) {
        _loseLife("Demasiados intentos fallidos.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Código Incorrecto. Intentos: $_attempts'),
            backgroundColor: AppTheme.dangerRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _loseLife(String reason) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas.",
            retry: false,
            showShop: true);
      } else {
        setState(() {
          _attempts = 3;
          _isError = false;
          _enteredCode = "";
        });
        _showOverlayState(
            title: "¡FALLASTE!",
            message: "$reason",
            retry: true,
            showShop: false);
      }
    }
  }

  void _onDigitPress(String digit) {
    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (_enteredCode.length < 4) {
      setState(() {
        _enteredCode += digit;
        _isError = false;
      });
    }
  }

  void _onDelete() {
    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (_enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
        _isError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryPurple.withValues(alpha: 0.3),
                        AppTheme.secondaryPink.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 35,
                    color: AppTheme.accentGold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CAJA FUERTE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.clue.riddleQuestion ??
                      "Ingresa el código de 4 dígitos",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),

                // Display de dígitos
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final hasDigit = index < _enteredCode.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 45,
                      height: 50,
                      decoration: BoxDecoration(
                        color: hasDigit
                            ? AppTheme.successGreen.withValues(alpha: 0.2)
                            : const Color.fromRGBO(0, 0, 0, 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isError
                              ? AppTheme.dangerRed
                              : (hasDigit
                                  ? AppTheme.successGreen
                                  : Colors.grey),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          hasDigit ? _enteredCode[index] : '',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _isError ? AppTheme.dangerRed : Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 15),

                // Teclado numérico
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) {
                      return _buildKey(
                        icon: Icons.backspace_outlined,
                        onTap: _showOverlay ? null : _onDelete,
                        color: AppTheme.warningOrange,
                      );
                    }
                    if (index == 10) {
                      return _buildKey(
                        text: '0',
                        onTap: _showOverlay ? null : () => _onDigitPress('0'),
                      );
                    }
                    if (index == 11) {
                      return _buildKey(
                        icon: Icons.check_circle,
                        onTap: _showOverlay
                            ? null
                            : (_enteredCode.length == 4 ? _checkCode : null),
                        color: AppTheme.successGreen,
                      );
                    }
                    final digit = '${index + 1}';
                    return _buildKey(
                      text: digit,
                      onTap: _showOverlay ? null : () => _onDigitPress(digit),
                    );
                  },
                ),
              ],
            ),
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                      });
                      // Reset has already been done in logic
                    }
                  : null,
              onGoToShop: _showShopButton
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MallScreen()),
                      );
                      // Check lives upon return
                      if (!context.mounted) return;
                      final player =
                          Provider.of<PlayerProvider>(context, listen: false)
                              .currentPlayer;
                      if ((player?.lives ?? 0) > 0) {
                        setState(() {
                          _canRetry = true;
                          _showShopButton = false;
                          _overlayTitle = "¡VIDAS OBTENIDAS!";
                          _overlayMessage = "Puedes continuar jugando.";
                        });
                      }
                    }
                  : null,
              onExit: () {
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKey({
    String? text,
    IconData? icon,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: onTap != null
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withValues(alpha: 0.2),
                      AppTheme.secondaryPink.withValues(alpha: 0.2),
                    ],
                  )
                : null,
          ),
          child: Center(
            child: text != null
                ? Text(
                    text,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.white,
                    ),
                  )
                : Icon(icon, color: color ?? Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
