import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../layouts/screens/home_screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';

class StoryScreen extends StatefulWidget {
  final String eventId;

  const StoryScreen({super.key, required this.eventId});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with TickerProviderStateMixin {
  int _currentLine = 0;
  bool _isFinished = false;

  final List<String> _lines = [
    "Año 2084. El mundo digital y el físico se han fusionado.",
    "Bajo las calles neón de la ciudad, se ocultan secretos de una era olvidada.",
    "Tú, un Cazador de élite, has sido convocado para recuperar las Reliquias de Red.",
    "El administrador ha aprobado tu incursión. Estás dentro.",
    "Recuerda: El tiempo es dinero, y los rivales no perdonan.",
    "¡Tu búsqueda comienza ahora!"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1000),
                  child: Text(
                    _lines[_currentLine],
                    key: ValueKey<int>(_currentLine),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                if (!_isFinished)
                  TextButton(
                    onPressed: () {
                      if (_currentLine < _lines.length - 1) {
                        setState(() {
                          _currentLine++;
                          if (_currentLine == _lines.length - 1) {
                            _isFinished = true;
                          }
                        });
                      }
                    },
                    child: const Text('CORREO ENTRANTE... [CONTINUAR]', 
                      style: TextStyle(color: AppTheme.accentGold, letterSpacing: 2)
                    ),
                  ),
                if (_isFinished)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Forzar un refresco del perfil para asegurar que el avatar esté cargado
                        try {
                          await Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
                        } catch (e) {
                          debugPrint('Error refreshing profile in StoryScreen: $e');
                        }
                        
                        if (!mounted) return;
                        
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => HomeScreen(eventId: widget.eventId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('INICIAR MISIÓN', 
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
