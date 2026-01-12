import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';

class FlagsMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const FlagsMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<FlagsMinigame> createState() => _FlagsMinigameState();
}

class _FlagsMinigameState extends State<FlagsMinigame> {
  int _score = 0;
  final int _targetScore = 10; // Más banderas para que no sea tan corto
  int _currentQuestionIndex = 0;
  bool _isGameOver = false;

  late List<Map<String, String>> _shuffledQuestions;
  
  // Timer State
  Timer? _timer;
  int _secondsRemaining = 45; // Menos tiempo para presionar un poco más
  
  // Estado Local
  List<String>? _currentOptions;
  int _localAttempts = 3; 

  // Lista de países balanceada (Nivel Intermedio)
  final List<Map<String, String>> _allCountries = [
    {'code': 've', 'name': 'Venezuela'},
    {'code': 'es', 'name': 'España'},
    {'code': 'us', 'name': 'Estados Unidos'},
    {'code': 'fr', 'name': 'Francia'},
    {'code': 'de', 'name': 'Alemania'},
    {'code': 'jp', 'name': 'Japón'},
    {'code': 'br', 'name': 'Brasil'},
    {'code': 'ar', 'name': 'Argentina'},
    {'code': 'mx', 'name': 'México'},
    {'code': 'it', 'name': 'Italia'},
    {'code': 'ca', 'name': 'Canadá'},
    {'code': 'pt', 'name': 'Portugal'},
    {'code': 'au', 'name': 'Australia'},
    {'code': 'kr', 'name': 'Corea del Sur'},
    {'code': 'ch', 'name': 'Suiza'},
    {'code': 'gr', 'name': 'Grecia'},
    {'code': 'be', 'name': 'Bélgica'},
    {'code': 'nl', 'name': 'Países Bajos'},
    {'code': 'se', 'name': 'Suecia'},
    {'code': 'no', 'name': 'Noruega'},
    {'code': 'dk', 'name': 'Dinamarca'},
    {'code': 'fi', 'name': 'Finlandia'},
    {'code': 'pl', 'name': 'Polonia'},
    {'code': 'tr', 'name': 'Turquía'},
    {'code': 'za', 'name': 'Sudáfrica'},
    {'code': 'eg', 'name': 'Egipto'},
    {'code': 'th', 'name': 'Tailandia'},
    {'code': 'vn', 'name': 'Vietnam'},
    {'code': 'ph', 'name': 'Filipinas'},
    {'code': 'my', 'name': 'Malasia'},
    {'code': 'id', 'name': 'Indonesia'},
    {'code': 'co', 'name': 'Colombia'},
    {'code': 'cl', 'name': 'Chile'},
    {'code': 'pe', 'name': 'Perú'},
    {'code': 'uy', 'name': 'Uruguay'},
  ];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _loseGlobalLife("¡Se acabó el tiempo!", timeOut: true);
      }
    });
  }

  void _startNewGame() {
    final random = Random();
    var questions = List<Map<String, String>>.from(_allCountries);
    questions.shuffle(random);
    // Tomar suficientes para el target
    _shuffledQuestions = questions.take(_targetScore).toList();
    
    _score = 0;
    _currentQuestionIndex = 0;
    _isGameOver = false;
    _secondsRemaining = 45; 
    _currentOptions = null; 
    _localAttempts = 3; 
    _startTimer();
    setState(() {});
  }

  void _handleOptionSelected(String selectedName) {
    if (_isGameOver) return;

    final correctAnswer = _shuffledQuestions[_currentQuestionIndex]['name'];
    
    if (selectedName == correctAnswer) {
      _score++;
      _currentOptions = null;
      
      if (_score >= _targetScore) {
        _winGame();
      } else {
        setState(() {
          _currentQuestionIndex++;
        });
      }
    } else {
      setState(() {
        _localAttempts--;
      });

      if (_localAttempts <= 0) {
        _loseGlobalLife("¡Demasiados errores!");
      } else {
        // Al fallar, barajamos las opciones para que no sea solo adivinar por eliminación estática
        setState(() {
          _currentOptions = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Incorrecto. Te quedan $_localAttempts intentos."),
            backgroundColor: AppTheme.warningOrange,
            duration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  void _loseGlobalLife(String reason, {bool timeOut = false}) {
    _timer?.cancel();
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
      gameProvider.loseLife(playerProvider.currentPlayer!.id).then((_) {
         if (!mounted) return;
         if (gameProvider.lives <= 0) {
            _showGameOverDialog("Te has quedado sin vidas globales.");
         } else {
            _showTryAgainDialog(reason);
         }
      });
    }
  }

  void _showTryAgainDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡Fallaste!", style: TextStyle(color: AppTheme.dangerRed)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            const Text("Has perdido 1 vida ❤️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text("Reintentar"),
          ),
          TextButton(
            onPressed: () {
               Navigator.pop(context); // Dialog
               Navigator.pop(context); // Screen
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("GAME OVER", style: TextStyle(color: AppTheme.dangerRed)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context); // Dialog
               Navigator.pop(context); // Screen
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  void _winGame() {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    widget.onSuccess();
  }

  List<String> _generateOptions() {
    if (_currentOptions != null) return _currentOptions!;

    final currentCountry = _shuffledQuestions[_currentQuestionIndex];
    final random = Random();
    
    var options = _allCountries
        .where((c) => c['name'] != currentCountry['name'])
        .map((c) => c['name']!)
        .toList();
    
    options.shuffle(random);
    var finalOptions = options.take(2).toList();
    finalOptions.add(currentCountry['name']!);
    finalOptions.shuffle(random);
    
    _currentOptions = finalOptions; 
    return finalOptions;
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver && _score >= _targetScore) {
        return const Center(child: CircularProgressIndicator()); 
    }
    
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;

    final currentCountry = _shuffledQuestions[_currentQuestionIndex];
    final currentOptions = _generateOptions();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // HEADER: TIMER & INTENTOS LOCALES
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isLowTime ? AppTheme.dangerRed.withOpacity(0.2) : Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isLowTime ? AppTheme.dangerRed : AppTheme.accentGold),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: isLowTime ? AppTheme.dangerRed : AppTheme.accentGold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "$minutes:$seconds",
                    style: TextStyle(
                      color: isLowTime ? AppTheme.dangerRed : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            const Text(
              "¿DE QUÉ PAÍS ES ESTA BANDERA?",
              style: TextStyle(color: AppTheme.primaryPurple, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Aciertos: $_score / $_targetScore",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 20),
                // Intentos Locales (Visual)
                Row(
                  children: List.generate(3, (index) {
                    return Icon(
                      index < _localAttempts ? Icons.favorite : Icons.favorite_border,
                      color: AppTheme.secondaryPink,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bandera
            Container(
              height: 150,
              width: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))
                ],
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage("https://flagcdn.com/w640/${currentCountry['code']}.png"),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Opciones
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: currentOptions.map((option) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleOptionSelected(option),
                  child: Text(
                    option,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                );
              }).toList(),
            ),
            // Espacio extra para evitar que el overlay del footer tape las opciones
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}