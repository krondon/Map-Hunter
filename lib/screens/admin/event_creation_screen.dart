import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../theme/app_theme.dart';

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
  String? _locationName;
  double? _latitude;
  double? _longitude;
  String _clue = '';
  String _pin = '';
  int _maxParticipants = 0;
  int _numberOfClues = 0;
  List<Map<String, dynamic>> _clueForms = [];
  int _currentClueIndex = 0;
  DateTime _selectedDate = DateTime.now();

  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isFormValid = false;

  // // Para mostrar el nombre del estado/ciudad si se desea
  // final List<String> _states = [
  //   'Amazonas',
  //   'Anzoátegui',
  //   'Apure',
  //   'Aragua',
  //   'Barinas',
  //   'Bolívar',
  //   'Carabobo',
  //   'Cojedes',
  //   'Delta Amacuro',
  //   'Distrito Capital',
  //   'Falcón',
  //   'Guárico',
  //   'La Guaira',
  //   'Lara',
  //   'Mérida',
  //   'Miranda',
  //   'Monagas',
  //   'Nueva Esparta',
  //   'Portuguesa',
  //   'Sucre',
  //   'Táchira',
  //   'Trujillo',
  //   'Yaracuy',
  //   'Zulia'
  // ];

  void _checkFormValidity() {
    bool isValid = true;

    // Validamos campos de texto (basado en las variables que actualizas en onChanged)
    if (_title.isEmpty) isValid = false;
    if (_description.isEmpty) isValid = false;
    if (_maxParticipants <= 0) isValid = false;
    if (_pin.length != 6) isValid = false; // El PIN debe ser exacto
    if (_clue.isEmpty) isValid = false;

    // Validamos Imagen y Mapa
    if (_selectedImage == null) isValid = false;
    if (_latitude == null || _longitude == null) isValid = false;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _selectLocationOnMap() async {
    // Obtener ubicación actual para centrar el mapa
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {}
    final latlng.LatLng initial = position != null
        ? latlng.LatLng(position.latitude, position.longitude)
        : const latlng.LatLng(10.4806, -66.9036); // Caracas por defecto

    latlng.LatLng? picked;
    String? address;
    latlng.LatLng temp = initial;
    final MapController mapController = MapController();
    final TextEditingController searchController = TextEditingController();
    Timer? debounce;
    List<dynamic> suggestions = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> searchLocation() async {
              final query = searchController.text;
              if (query.isEmpty) {
                setStateDialog(() => suggestions = []);
                return;
              }

              final apiKey = 'pk.45e576837f12504a63c6d1893820f1cf';
              final url = Uri.parse(
                  'https://us1.locationiq.com/v1/search.php?key=$apiKey&q=$query&format=json&limit=5&countrycodes=ve');

              try {
                final response = await http.get(url);
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  if (data is List) {
                    setStateDialog(() {
                      suggestions = data;
                    });
                  }
                }
              } catch (e) {
                debugPrint('Error searching: $e');
              }
            }

            void selectSuggestion(dynamic suggestion) {
              final lat = double.parse(suggestion['lat']);
              final lon = double.parse(suggestion['lon']);
              final display = suggestion['display_name'];
              final newPos = latlng.LatLng(lat, lon);

              setStateDialog(() {
                temp = newPos;
                suggestions = [];
                searchController.text = display;
              });
              mapController.move(newPos, 15);
              FocusScope.of(context).unfocus();
            }

            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              contentPadding: const EdgeInsets.all(15),
              content: SizedBox(
                width: 350,
                height: 450,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar dirección...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: searchLocation,
                          ),
                        ),
                        onChanged: (value) {
                          if (debounce?.isActive ?? false) debounce!.cancel();
                          debounce =
                              Timer(const Duration(milliseconds: 400), () {
                            searchLocation();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                center: initial,
                                zoom: 14,
                                cameraConstraint: CameraConstraint.contain(
                                  bounds: LatLngBounds(
                                    const latlng.LatLng(
                                        0.5, -73.5), // Suroeste de Venezuela
                                    const latlng.LatLng(
                                        12.5, -59.5), // Noreste de Venezuela
                                  ),
                                ),
                                minZoom: 5,
                                onTap: (tapPos, latLng) {
                                  setStateDialog(() {
                                    temp = latLng;
                                    suggestions = [];
                                  });
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.juegoqr.app',
                                  tileProvider: NetworkTileProvider(),
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      width: 40,
                                      height: 40,
                                      point: temp,
                                      child: const Icon(Icons.location_on,
                                          color: Colors.red, size: 40),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (suggestions.isNotEmpty)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 200,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: suggestions.length,
                                    separatorBuilder: (_, __) => const Divider(
                                        height: 1, color: Colors.white10),
                                    itemBuilder: (context, index) {
                                      final item = suggestions[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          item['display_name'] ?? '',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () => selectSuggestion(item),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Validación geográfica estricta para Venezuela
                                    if (temp.latitude < 0.5 ||
                                        temp.latitude > 12.5 ||
                                        temp.longitude < -73.5 ||
                                        temp.longitude > -59.5) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              '⚠️ Por favor selecciona una ubicación dentro de Venezuela'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    picked = temp;
                                    Navigator.of(context).pop();
                                  },
                                  child:
                                      const Text('Seleccionar esta ubicación'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      // Llamar a LocationIQ para obtener la dirección
      final apiKey =
          'pk.45e576837f12504a63c6d1893820f1cf'; // LocationIQ API Key
      final url = Uri.parse(
          'https://us1.locationiq.com/v1/reverse.php?key=$apiKey&lat=${picked!.latitude}&lon=${picked!.longitude}&format=json');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          address = data['display_name'] ?? 'Ubicación seleccionada';
        } else {
          address = 'Ubicación seleccionada';
        }
      } catch (_) {
        address = 'Ubicación seleccionada';
      }
      setState(() {
        _latitude = picked!.latitude;
        _longitude = picked!.longitude;
        _locationName = address;
        _checkFormValidity();
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _checkFormValidity(); // <--- AGREGAR ESTO
      });
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
      debugPrint(
          "Enviando Evento: Título='$_title', Desc='$_description', Clue='$_clue'");

      if (_latitude == null || _longitude == null || _locationName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('⚠️ Debes seleccionar la ubicación en el mapa')),
        );
        return;
      }

      setState(() => _isLoading = true);

      final newEvent = GameEvent(
        id: DateTime.now().toString(),
        title: _title,
        description: _description,
        locationName: _locationName!,
        latitude: _latitude!,
        longitude: _longitude!,
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
          _resetForm();
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

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _title = '';
      _description = '';
      _locationName = null;
      _latitude = null;
      _longitude = null;
      _clue = '';
      _pin = '';
      _maxParticipants = 0;
      _numberOfClues = 0;
      _clueForms = [];
      _currentClueIndex = 0;
      _selectedImage = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Estilo común para inputs
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppTheme.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryPurple),
      ),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
    );

    // Retornamos un Container/SingleChildScrollView en lugar de Scaffold
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.darkGradient,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(
              maxWidth: 900), // Limitar ancho en monitores grandes
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Form(
              key: _formKey,
              onChanged: _checkFormValidity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título de la Sección
                  const Text(
                    "Crear Nueva Competencia",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Configura los detalles del evento, ubicación y pistas.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // Tarjeta Principal del Formulario
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                        color: const Color(
                            0xFF161B33), // Fondo ligeramente diferente al fondo general
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Información Básica",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGold)),
                        const SizedBox(height: 20),

                        // 1. Título
                        TextFormField(
                          initialValue: _title,
                          decoration: inputDecoration.copyWith(
                              labelText: 'Título del Evento',
                              hintText: 'Ej. Búsqueda del Tesoro Caracas'),
                          style: const TextStyle(color: Colors.white),
                          validator: (v) =>
                              v!.isEmpty ? 'Campo requerido' : null,
                          onChanged: (v) => _title = v,
                          onSaved: (v) => _title = v!,
                        ),
                        const SizedBox(height: 20),

                        // 2. Descripción
                        TextFormField(
                          initialValue: _description,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Descripción',
                            hintText: 'Detalles sobre la competencia...',
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          validator: (v) =>
                              v!.isEmpty ? 'Campo requerido' : null,
                          onChanged: (v) => _description = v,
                          onSaved: (v) => _description = v!,
                        ),
                        const SizedBox(height: 20),

                        // 3. Imagen
                        InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    style: BorderStyle.solid),
                                image: _selectedImage != null
                                    ? DecorationImage(
                                        image: NetworkImage(_selectedImage!
                                            .path), // Nota: Web usa path como URL blob a veces, o bytes
                                        fit: BoxFit.cover,
                                        opacity: 0.5)
                                    : null),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedImage != null
                                      ? Icons.check_circle
                                      : Icons.add_photo_alternate,
                                  size: 40,
                                  color: _selectedImage != null
                                      ? Colors.green
                                      : AppTheme.primaryPurple,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                    _selectedImage != null
                                        ? "Imagen seleccionada: ${_selectedImage!.name}"
                                        : "Subir Imagen de Portada",
                                    style: TextStyle(
                                        color: _selectedImage != null
                                            ? Colors.greenAccent
                                            : Colors.white70))
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        const Text("Configuración del Juego",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryPink)),
                        const SizedBox(height: 20),

                        // Fila: Lugar (mapa) y Capacidad
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _selectLocationOnMap,
                                    icon: const Icon(Icons.map),
                                    label: const Text(
                                        'Seleccionar ubicación en el mapa'),
                                  ),
                                  if (_locationName != null &&
                                      _latitude != null &&
                                      _longitude != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Ubicación: $_locationName\nLat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: TextFormField(
                                initialValue: _maxParticipants == 0
                                    ? ''
                                    : _maxParticipants.toString(),
                                decoration: inputDecoration.copyWith(
                                    labelText: 'Max. Jugadores'),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                                onChanged: (v) {
                                  if (v.isNotEmpty)
                                    _maxParticipants = int.tryParse(v) ?? 0;
                                },
                                onSaved: (v) =>
                                    _maxParticipants = int.parse(v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Fila: PIN y Pista Inicial
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _pin,
                                // 1. Muestra el teclado numérico
                                keyboardType: TextInputType.number,
                                // 2. Solo permite dígitos y máximo 6 caracteres
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                decoration: inputDecoration.copyWith(
                                  labelText: 'PIN de Acceso',
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: Colors.white54),
                                  hintText: '123456', // Opcional: ayuda visual
                                ),
                                style: const TextStyle(color: Colors.white),
                                // 3. Valida que no esté vacío y que tenga exactamente 6 números
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Requerido';
                                  if (v.length != 6)
                                    return 'El PIN debe ser de 6 dígitos';
                                  return null;
                                },
                                onChanged: (v) => _pin = v,
                                onSaved: (v) => _pin = v!,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: _clue,
                                decoration: inputDecoration.copyWith(
                                    labelText:
                                        'Pista Inicial (aparece antes de empezar)',
                                    prefixIcon: const Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.white54)),
                                style: const TextStyle(color: Colors.white),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                                onChanged: (v) => _clue = v,
                                onSaved: (v) => _clue = v!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Generador de Pistas
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text("Generador de Pistas",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      initialValue: _numberOfClues.toString(),
                                      textAlign: TextAlign.center,
                                      // *** Puntos de restricción (1) ***
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(
                                            2), // Max. 2 dígitos
                                      ],
                                      decoration: inputDecoration.copyWith(
                                          contentPadding:
                                              const EdgeInsets.all(10),
                                          isDense: true,
                                          // Opcional: Mostrar un hint de la restricción
                                          hintText: 'Max 12'),
                                      style:
                                          const TextStyle(color: Colors.white),
                                      onChanged: (v) {
                                        int? parsedValue = int.tryParse(v);

                                        // Aplicar la restricción al estado
                                        if (parsedValue != null) {
                                          // Si el valor es mayor a 12, se queda en 12. Si es 0 o menos, se queda en 0.
                                          if (parsedValue > 12) {
                                            _numberOfClues = 12;
                                            // Opcional: Forzar la actualización del campo visual si se excede 12
                                            // Es mejor dejar que el validador maneje la retroalimentación
                                          } else if (parsedValue < 0) {
                                            _numberOfClues = 0;
                                          } else {
                                            _numberOfClues = parsedValue;
                                          }
                                        } else if (v.isEmpty) {
                                          _numberOfClues = 0;
                                        }
                                        // Se debe llamar a setState aquí para reflejar el cambio en el campo
                                        // (si quieres que se limite visualmente al escribir un 13)
                                        setState(() {
                                          // Esto asegura que el campo se limite visualmente si el usuario intenta escribir más de 12
                                          _numberOfClues;
                                        });
                                      },
                                      // Opcional, pero recomendado: validar para mostrar el error al usuario
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Requerido';
                                        int? num = int.tryParse(v);
                                        if (num == null || num <= 0)
                                          return 'Mín. 1';
                                        if (num > 12) return 'Máximo 12 pistas';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      // *** Punto de restricción (2) - Lógica en la función ***
                                      if (_numberOfClues > 12) {
                                        _numberOfClues =
                                            12; // Asegura que el valor de estado no exceda
                                      }
                                      if (_numberOfClues <= 0) {
                                        // Opcional: Mostrar un mensaje al usuario
                                        return; // No hacer nada si no hay pistas
                                      }
                                      // Llama a la función de generación con el valor validado
                                      _generateClueForms();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGold,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text("Generar"),
                                  ),
                                ],
                              ),
                              if (_clueForms.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: _currentClueIndex > 0
                                          ? () => setState(
                                              () => _currentClueIndex--)
                                          : null,
                                      icon: const Icon(Icons.arrow_back_ios,
                                          color: Colors.white),
                                    ),
                                    Text(
                                      "Pista ${_currentClueIndex + 1} de ${_clueForms.length}",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      onPressed: _currentClueIndex <
                                              _clueForms.length - 1
                                          ? () => setState(
                                              () => _currentClueIndex++)
                                          : null,
                                      icon: const Icon(Icons.arrow_forward_ios,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    key: ValueKey<int>(_currentClueIndex),
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          initialValue:
                                              _clueForms[_currentClueIndex]
                                                  ['title'],
                                          decoration: inputDecoration.copyWith(
                                              labelText: 'Título de la Pista'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) =>
                                              _clueForms[_currentClueIndex]
                                                  ['title'] = v,
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          initialValue:
                                              _clueForms[_currentClueIndex]
                                                  ['description'],
                                          decoration: inputDecoration.copyWith(
                                              labelText: 'Descripción'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) =>
                                              _clueForms[_currentClueIndex]
                                                  ['description'] = v,
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          initialValue:
                                              _clueForms[_currentClueIndex]
                                                  ['riddle_question'],
                                          decoration: inputDecoration.copyWith(
                                              labelText: 'Pregunta / Acertijo'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) =>
                                              _clueForms[_currentClueIndex]
                                                  ['riddle_question'] = v,
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          initialValue:
                                              _clueForms[_currentClueIndex]
                                                  ['riddle_answer'],
                                          decoration: inputDecoration.copyWith(
                                              labelText: 'Respuesta Correcta'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) =>
                                              _clueForms[_currentClueIndex]
                                                  ['riddle_answer'] = v,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: _clueForms[
                                                            _currentClueIndex]
                                                        ['xp_reward']
                                                    .toString(),
                                                decoration: inputDecoration
                                                    .copyWith(labelText: 'XP'),
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                onChanged: (v) => _clueForms[
                                                            _currentClueIndex]
                                                        ['xp_reward'] =
                                                    int.tryParse(v) ?? 0,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: _clueForms[
                                                            _currentClueIndex]
                                                        ['coin_reward']
                                                    .toString(),
                                                decoration:
                                                    inputDecoration.copyWith(
                                                        labelText: 'Monedas'),
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                onChanged: (v) => _clueForms[
                                                            _currentClueIndex]
                                                        ['coin_reward'] =
                                                    int.tryParse(v) ?? 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Botón de Acción Final
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            // 4. LÓGICA DEL BOTÓN MODIFICADA
                            // Si es válido y no está cargando, ejecuta _submitForm.
                            // Si no, es null (deshabilitado).
                            onPressed: (_isFormValid && !_isLoading)
                                ? _submitForm
                                : null,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                // El color se ajusta solo cuando está disabled,
                                // pero si quieres forzar estilo visual puedes hacerlo aquí
                                disabledBackgroundColor:
                                    Colors.grey.withOpacity(0.3),
                                disabledForegroundColor: Colors.white30,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 10,
                                shadowColor:
                                    AppTheme.primaryPurple.withOpacity(0.5)),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text("PUBLICAR COMPETENCIA",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
