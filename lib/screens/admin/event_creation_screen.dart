import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';

class EventCreationScreen extends StatefulWidget {
  const EventCreationScreen({super.key});

  @override
  State<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends State<EventCreationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Variables para guardar los datos
  String _title = '';
  String _description = '';
  String? _location;
  String _clue = '';
  String _pin = '';
  int _maxParticipants = 0;
  int _numberOfClues = 0;
  List<Map<String, dynamic>> _clueForms = [];
  int _currentClueIndex = 0;
  DateTime _selectedDate = DateTime.now();

  XFile? _selectedImage;
  bool _isLoading = false;

  final List<String> _states = [
    'Amazonas', 'Anzoátegui', 'Apure', 'Aragua', 'Barinas', 'Bolívar',
    'Carabobo', 'Cojedes', 'Delta Amacuro', 'Distrito Capital', 'Falcón',
    'Guárico', 'La Guaira', 'Lara', 'Mérida', 'Miranda', 'Monagas',
    'Nueva Esparta', 'Portuguesa', 'Sucre', 'Táchira', 'Trujillo',
    'Yaracuy', 'Zulia'
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  void _generateClueForms() {
    if (_numberOfClues > 0) {
      setState(() {
        _currentClueIndex = 0;
        if (_clueForms.length < _numberOfClues) {
          final newItems = _numberOfClues - _clueForms.length;
          for (int i = 0; i < newItems; i++) {
            _clueForms.add({
              'title': 'Pista ${_clueForms.length + 1}',
              'description': '',
              'riddle_question': '',
              'riddle_answer': '',
              'xp_reward': 50,
              'coin_reward': 10,
            });
          }
        } else {
          _clueForms = _clueForms.sublist(0, _numberOfClues);
        }
      });
    } else {
      setState(() => _clueForms = []);
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading) return;

    // Aunque save() ayuda, onChanged es la clave aquí debido al ListView
    _formKey.currentState?.save();

    if (_formKey.currentState!.validate()) {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Debes seleccionar una imagen')),
        );
        return;
      }

      // DEBUG: Verifica en consola que los datos no estén vacíos
      debugPrint("Enviando Evento: Título='$_title', Desc='$_description', Clue='$_clue'");

      setState(() => _isLoading = true);

      final newEvent = GameEvent(
        id: DateTime.now().toString(),
        title: _title,
        description: _description,
        location: _location!,
        date: _selectedDate,
        createdByAdminId: 'admin_1',
        imageUrl: _selectedImage!.name, 
        clue: _clue,
        maxParticipants: _maxParticipants,
        pin: _pin,
      );

      final provider = Provider.of<EventProvider>(context, listen: false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Creando evento y pistas...')),
      );

      String? createdEventId;

      try {
        createdEventId = await provider.createEvent(newEvent, _selectedImage);

        if (createdEventId != null && _clueForms.isNotEmpty) {
          await Supabase.instance.client.functions.invoke(
            'admin-actions/create-clues-batch',
            body: {
              'eventId': createdEventId,
              'clues': _clueForms,
            },
            method: HttpMethod.post,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Competencia creada con éxito')),
          );
          Navigator.pop(context);
        }
      } catch (error) {
        if (createdEventId != null) {
          try {
            await provider.deleteEvent(createdEventId);
          } catch (e) {
            debugPrint('Rollback fallido: $e');
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al crear evento: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: const Color.fromARGB(255, 38, 13, 109),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      labelStyle: const TextStyle(color: Colors.white70), // Mejora visual
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: Colors.white),
            SizedBox(width: 10),
            Text("Crear Competencia"),
          ],
        ),
      ),
      body: Center(
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Form(
                key: _formKey,
                // Usamos ListView, por lo que los elementos off-screen se destruyen.
                // onChanged es vital aquí.
                child: ListView(
                  children: [
                    const Text("Nueva Competencia",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // 1. Título
                    TextFormField(
                      initialValue: _title, // IMPORTANTE: Mantiene el valor al hacer scroll
                      decoration: inputDecoration.copyWith(
                          labelText: 'Título del Evento'),
                      style: const TextStyle(color: Colors.white),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onChanged: (v) => _title = v, // IMPORTANTE: Guarda al escribir
                      onSaved: (v) => _title = v!,
                    ),
                    const SizedBox(height: 15),

                    // 2. Descripción
                    TextFormField(
                      initialValue: _description, // IMPORTANTE
                      decoration: inputDecoration.copyWith(labelText: 'Descripción'),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onChanged: (v) => _description = v, // IMPORTANTE
                      onSaved: (v) => _description = v!,
                    ),
                    const SizedBox(height: 15),

                    // 3. Imagen
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 17, 5, 83),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image),
                            label: const Text("Subir Imagen"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade50,
                              foregroundColor: Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              _selectedImage == null
                                  ? "Ninguna imagen seleccionada"
                                  : "✅ ${_selectedImage!.name}",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _selectedImage == null ? Colors.grey : Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 4. Pista (General)
                    TextFormField(
                      initialValue: _clue,
                      decoration: inputDecoration.copyWith(
                          labelText: 'Pista Principal (Clue)',
                          prefixIcon: const Icon(Icons.lightbulb, color: Colors.white70)),
                      style: const TextStyle(color: Colors.white),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onChanged: (v) => _clue = v, // IMPORTANTE
                      onSaved: (v) => _clue = v!,
                    ),
                    const SizedBox(height: 15),

                    // 4.1 PIN
                    TextFormField(
                      initialValue: _pin,
                      decoration: inputDecoration.copyWith(
                          labelText: 'PIN de Acceso',
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70)),
                      style: const TextStyle(color: Colors.white),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onChanged: (v) => _pin = v, // IMPORTANTE
                      onSaved: (v) => _pin = v!,
                    ),
                    const SizedBox(height: 15),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 5. Lugar
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: inputDecoration.copyWith(
                                labelText: 'Lugar / Ubicación',
                                prefixIcon: const Icon(Icons.map, color: Colors.white70)),
                            dropdownColor: const Color.fromARGB(255, 38, 13, 109), // Coherencia visual
                            style: const TextStyle(color: Colors.white),
                            value: _location,
                            items: _states.map((state) {
                              return DropdownMenuItem(
                                value: state,
                                child: Text(state),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _location = value;
                              });
                            },
                            validator: (v) => v == null ? 'Campo requerido' : null,
                            onSaved: (v) => _location = v,
                          ),
                        ),
                        const SizedBox(width: 15),
                        // 6. Capacidad
                        Expanded(
                          child: TextFormField(
                            initialValue: _maxParticipants == 0 ? '' : _maxParticipants.toString(),
                            decoration: inputDecoration.copyWith(
                                labelText: 'Max Participantes',
                                prefixIcon: const Icon(Icons.group, color: Colors.white70)),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            onChanged: (v) {
                              if(v.isNotEmpty) _maxParticipants = int.tryParse(v) ?? 0;
                            },
                            onSaved: (v) => _maxParticipants = int.parse(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 7. Número de Pistas
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _numberOfClues.toString(),
                            decoration: inputDecoration.copyWith(
                                labelText: 'Número de Pistas',
                                prefixIcon: const Icon(Icons.format_list_numbered, color: Colors.white70)),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            onChanged: (v) {
                               if (v.isNotEmpty) {
                                _numberOfClues = int.tryParse(v) ?? 0;
                              }
                            },
                            onSaved: (v) => _numberOfClues = int.parse(v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _generateClueForms,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text("Generar"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 8. Pistas dinámicas
                    if (_clueForms.isNotEmpty) ...[
                      const Divider(height: 40, thickness: 2),
                      // ... (El resto de tu código de pistas se mantiene igual ya que usaba onChanged correctamente)
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Pista ${_currentClueIndex + 1} de ${_clueForms.length}",
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _currentClueIndex > 0
                                    ? () => setState(() => _currentClueIndex--)
                                    : null,
                                icon: const Icon(Icons.arrow_back_ios),
                              ),
                              IconButton(
                                onPressed: _currentClueIndex < _clueForms.length - 1
                                    ? () => setState(() => _currentClueIndex++)
                                    : null,
                                icon: const Icon(Icons.arrow_forward_ios),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              key: ValueKey('title_${_currentClueIndex}'),
                              initialValue: _clueForms[_currentClueIndex]['title'],
                              decoration: inputDecoration.copyWith(labelText: 'Título de la Pista'),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) => _clueForms[_currentClueIndex]['title'] = v,
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              key: ValueKey('desc_${_currentClueIndex}'),
                              initialValue: _clueForms[_currentClueIndex]['description'],
                              decoration: inputDecoration.copyWith(labelText: 'Descripción / Pista'),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 3,
                              onChanged: (v) => _clueForms[_currentClueIndex]['description'] = v,
                            ),
                            // ... Agrega el resto de campos de pistas aquí ...
                             const SizedBox(height: 15),
                             TextFormField(
                              key: ValueKey('riddle_q_${_currentClueIndex}'),
                              initialValue: _clueForms[_currentClueIndex]['riddle_question'],
                              decoration: inputDecoration.copyWith(labelText: 'Pregunta del Acertijo'),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) => _clueForms[_currentClueIndex]['riddle_question'] = v,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              key: ValueKey('riddle_a_${_currentClueIndex}'),
                              initialValue: _clueForms[_currentClueIndex]['riddle_answer'],
                              decoration: inputDecoration.copyWith(labelText: 'Respuesta del Acertijo'),
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) => _clueForms[_currentClueIndex]['riddle_answer'] = v,
                            ),
                          ],
                        ),
                      ),
                       const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentClueIndex > 0)
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _currentClueIndex--),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text("Anterior"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                            )
                          else
                            const SizedBox(),
                            
                          if (_currentClueIndex < _clueForms.length - 1)
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _currentClueIndex++),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text("Siguiente"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 30),

                    // Botón Guardar
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                          backgroundColor: Colors.indigo,
                          foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _submitForm,
                        child: const Text("CREAR EVENTO",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)))
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}