import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../game/widgets/minigames/memory_sequence_minigame.dart';
import '../../../game/models/clue.dart';

class SequenceConfigScreen extends StatefulWidget {
  const SequenceConfigScreen({super.key});

  @override
  State<SequenceConfigScreen> createState() => _SequenceConfigScreenState();
}

class _SequenceConfigScreenState extends State<SequenceConfigScreen> {
  // Configuración del minijuego
  int _difficultyLevel = 3; // Niveles de secuencia
  double _timeLimit = 30.0; // Segundos

  void _testMinigame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemorySequenceMinigame(
          clue: OnlineClue(
            id: 'test-sequence',
            title: 'Test Memory Sequence',
            description: 'Test Description',
            hint: 'Test Hint',
            type: ClueType.minigame,
            puzzleType: PuzzleType.memorySequence,
          ),
          onSuccess: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Juego completado con éxito!')),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Secuencia de Código'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajustes del Minijuego',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Dificultad (Longitud de Secuencia)
            Text('Longitud de Secuencia: $_difficultyLevel'),
            Slider(
              value: _difficultyLevel.toDouble(),
              min: 3,
              max: 10,
              divisions: 7,
              label: _difficultyLevel.toString(),
              onChanged: (value) {
                setState(() {
                  _difficultyLevel = value.toInt();
                });
              },
            ),
            
            const SizedBox(height: 20),

            // Tiempo Limite (Simulado)
            Text('Tiempo Límite: ${_timeLimit.toInt()} segundos'),
            Slider(
              value: _timeLimit,
              min: 10,
              max: 120,
              divisions: 11,
              label: '${_timeLimit.toInt()}s',
              onChanged: (value) {
                setState(() {
                  _timeLimit = value;
                });
              },
            ),

            const SizedBox(height: 40),

            Center(
              child: ElevatedButton.icon(
                onPressed: _testMinigame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('PROBAR MINIGUARD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
