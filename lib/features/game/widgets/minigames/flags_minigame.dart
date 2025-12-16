import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';

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
  final int _targetScore = 5; // Cantidad de banderas a adivinar para ganar
  int _currentQuestionIndex = 0;
  bool _isGameOver = false;

  late List<Map<String, String>> _shuffledQuestions;
  
  // Timer State
  Timer? _timer;
  int _secondsRemaining = 60; // 1 minuto para 5 banderas
  
  // Opciones persistentes para la pregunta actual (para que no se rebarajen si falla)
  List<String>? _currentOptions;

  // Lista de países y sus códigos ISO para la API de banderas
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
    {'code': 'gb', 'name': 'Reino Unido'},
    {'code': 'cn', 'name': 'China'},
    {'code': 'kr', 'name': 'Corea del Sur'},
    {'code': 'in', 'name': 'India'},
    {'code': 'ru', 'name': 'Rusia'},
    {'code': 'au', 'name': 'Australia'},
    {'code': 'cl', 'name': 'Chile'},
    {'code': 'co', 'name': 'Colombia'},
    {'code': 'pe', 'name': 'Perú'},
    // DIFÍCILES
    {'code': 'bt', 'name': 'Bután'},
    {'code': 'np', 'name': 'Nepal'},
    {'code': 'sc', 'name': 'Seychelles'},
    {'code': 'ki', 'name': 'Kiribati'},
    {'code': 'kz', 'name': 'Kazajistán'},
    {'code': 'lk', 'name': 'Sri Lanka'},
    {'code': 'mn', 'name': 'Mongolia'},
    {'code': 'pap', 'name': 'Papúa Nueva Guinea'},
    {'code': 'sz', 'name': 'Esuatini'},
    {'code': 'tm', 'name': 'Turkmenistán'},
    {'code': 'uz', 'name': 'Uzbekistán'},
    {'code': 'kg', 'name': 'Kirguistán'},
    {'code': 'tj', 'name': 'Tayikistán'},
    {'code': 'tv', 'name': 'Tuvalu'},
    {'code': 'nr', 'name': 'Nauru'},
    {'code': 'fm', 'name': 'Micronesia'},
    {'code': 'ws', 'name': 'Samoa'},
    {'code': 'to', 'name': 'Tonga'},
    {'code': 'vu', 'name': 'Vanuatu'},
    {'code': 'sb', 'name': 'Islas Salomón'},
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
        _loseLife("¡Se acabó el tiempo!", timeOut: true);
      }
    });
  }

  void _startNewGame() {
    // Seleccionar 5 preguntas aleatorias
    final random = Random();
    var questions = List<Map<String, String>>.from(_allCountries);
    questions.shuffle(random);
    _shuffledQuestions = questions.take(_targetScore).toList();
    
    _score = 0;
    _currentQuestionIndex = 0;
    _isGameOver = false;
    _secondsRemaining = 60; // Reiniciar tiempo
    _currentOptions = null; // Resetear opciones
    _startTimer();
    setState(() {});
  }

  void _handleOptionSelected(String selectedName) {
    if (_isGameOver) return;

    final correctAnswer = _shuffledQuestions[_currentQuestionIndex]['name'];
    
    if (selectedName == correctAnswer) {
      // Respuesta Correcta
      _score++;
      _currentOptions = null; // Limpiar para que la siguiente pregunta genere nuevas opciones
      
      if (_score >= _targetScore) {
        // Gano el juego total
        _winGame();
      } else {
        // Siguiente pregunta
        setState(() {
          _currentQuestionIndex++;
        });
      }
    } else {
      // Respuesta Incorrecta
      // NO cambiamos de pregunta, solo quitamos vida
      _loseLife("Incorrecto. Intenta de nuevo.");
    }
  }

  void _loseLife(String reason, {bool timeOut = false}) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      playerProvider.currentPlayer!.lives--;
      playerProvider.notifyListeners();

      if (playerProvider.currentPlayer!.lives <= 0) {
        _timer?.cancel();
        _showGameOverDialog("Te has quedado sin vidas.");
      } else if (timeOut) {
         _showGameOverDialog("Tiempo agotado.");
      } else {
        // NO mostramos diálogo intrusivo por cada error, solo un snackbar o feedback visual rápido
        // para no interrumpir el flujo si solo debe reintentar la misma bandera.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reason -1 Vida 💔'),
            backgroundColor: AppTheme.dangerRed,
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }
  }



  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("GAME OVER", style: TextStyle(color: AppTheme.dangerRed, fontSize: 24, fontWeight: FontWeight.bold)),
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
    // Si ya tenemos opciones generadas para esta pregunta (porque falló antes), las reusamos
    if (_currentOptions != null) return _currentOptions!;

    final currentCountry = _shuffledQuestions[_currentQuestionIndex];
    final random = Random();
    
    // Crear lista de opciones incorrectas
    var options = _allCountries
        .where((c) => c['name'] != currentCountry['name'])
        .map((c) => c['name']!)
        .toList();
    
    options.shuffle(random);
    
    // Tomar 3 incorrectas y agregar la correcta
    var finalOptions = options.take(3).toList();
    finalOptions.add(currentCountry['name']!);
    
    // Barajar las opciones finales
    finalOptions.shuffle(random);
    
    _currentOptions = finalOptions; // Guardar para persistencia
    return finalOptions;
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameOver && _score >= _targetScore) {
        return const Center(child: CircularProgressIndicator()); 
        // O un mensaje de victoria mientras sale el dialogo
    }


    
    // Formatear tiempo mm:ss
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;

    final currentCountry = _shuffledQuestions[_currentQuestionIndex];
    final currentOptions = _generateOptions();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // TIMER DISPLAY
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
                  fontFamily: 'monospace', // Para que no salten los números
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
            Consumer<PlayerProvider>(
              builder: (context, playerProvider, _) {
                final lives = playerProvider.currentPlayer?.lives ?? 0;
                return Row(
                  children: List.generate(3, (index) {
                    return Icon(
                      index < lives ? Icons.favorite : Icons.favorite_border,
                      color: AppTheme.dangerRed,
                      size: 20,
                    );
                  }),
                );
              },
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
      ],
    );
  }
}
