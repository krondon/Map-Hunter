import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clue.dart';

class RiddleScreen extends StatefulWidget {
  final Clue clue;

  const RiddleScreen({super.key, required this.clue});

  @override
  State<RiddleScreen> createState() => _RiddleScreenState();
}

class _RiddleScreenState extends State<RiddleScreen> {
  final _answerController = TextEditingController();
  bool _showError = false;
  bool _isLoading = false; 

  Future<void> _checkAnswer() async {
    if (_isLoading) return; 

    final userAnswer = _answerController.text.trim().toLowerCase();
    final correctAnswer = widget.clue.riddleAnswer?.trim().toLowerCase() ?? '';

    if (userAnswer == correctAnswer) {
      setState(() => _isLoading = true); 
      
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

      try {
        final success = await gameProvider.completeCurrentClue(
          widget.clue.riddleAnswer ?? userAnswer, 
          clueId: widget.clue.id
        );

        if (!mounted) return; 

        if (success) {
          // CORRECCIÓN: Actualizar datos desde el servidor
          await playerProvider.refreshProfile();
          
          if (mounted) _showSuccessDialog();
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar el progreso.')),
          );
        }
      } catch (e) {
        debugPrint("Error en completeCurrentClue: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error interno: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }

    } else {
      setState(() {
        _showError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respuesta incorrecta. ¡Inténtalo de nuevo!'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

void _showSuccessDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 60, color: AppTheme.successGreen),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Acertijo Resuelto!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            '+${widget.clue.xpReward} XP  |  +${widget.clue.coinReward} Monedas',
            style: const TextStyle(color: AppTheme.accentGold, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(); 
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                Navigator.of(context).pop(true); 
              }
            });
          },
          child: const Text('Continuar'),
        ),
      ),
    ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    // UI sin cambios
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolver Acertijo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryPurple, width: 2),
                  ),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    size: 50,
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'ACERTIJO',
                style: TextStyle(
                  color: AppTheme.secondaryPink,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.clue.riddleQuestion ?? '¿?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _answerController,
                enabled: !_isLoading, 
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe tu respuesta aquí...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  errorText: _showError ? 'Respuesta incorrecta' : null,
                  prefixIcon: const Icon(Icons.edit, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  if (_showError) setState(() => _showError = false);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _checkAnswer, 
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text(
                    'VERIFICAR RESPUESTA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}