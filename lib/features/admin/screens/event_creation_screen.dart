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
import '../../game/models/event.dart';
import '../../game/providers/event_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../game/models/clue.dart';
import '../widgets/qr_display_dialog.dart';
import '../widgets/store_edit_dialog.dart';
import '../../mall/providers/store_provider.dart';
import '../../mall/models/mall_store.dart';

class EventCreationScreen extends StatefulWidget {
  final VoidCallback? onEventCreated;
  final GameEvent? event;

  const EventCreationScreen({
    super.key, 
    this.onEventCreated,
    this.event,
  });

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
  late String _eventId; // ID del evento (existente o nuevo generado)

  // Stores
  List<Map<String, dynamic>> _pendingStores = [];

  void _addPendingStore() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StoreEditDialog(eventId: _eventId),
    );

    if (result != null) {
      setState(() {
        _pendingStores.add(result);
      });
    }
  }

  void _removePendingStore(int index) {
    setState(() {
      _pendingStores.removeAt(index);
    });
  }

  @override
  void initState() {
    super.initState();
    // Si editamos, usamos el ID existente. Si es nuevo, generamos UUID
    _eventId = widget.event?.id ?? const Uuid().v4();
    
    // Si editamos, cargamos datos
    if (widget.event != null) {
       _title = widget.event!.title;
       _description = widget.event!.description;
       _locationName = widget.event!.locationName;
       _latitude = widget.event!.latitude;
       _longitude = widget.event!.longitude;
       _clue = widget.event!.clue;
       _pin = widget.event!.pin;
       _maxParticipants = widget.event!.maxParticipants;
       _selectedDate = widget.event!.date;
       // Nota: la imagen y las pistas se cargan aparte o no se editan aqui directamente si no se cambian
       _checkFormValidity();
    }
  }

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
    // 1. Validar Permisos explícitamente antes de obtener ubicación
    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Servicios de ubicación deshabilitados.');
        // Opcional: Mostrar alerta para activar
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permiso de ubicación denegado.');
        }
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
         // Mostrar toast o feedback visual si es necesario
         position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5), // Timeout corto para no bloquear
         );
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
    }
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
                                    // Utilizamos la URL con subdominios. Esto ayuda al navegador a cargar
                                    // las imágenes más rápido y a veces resuelve problemas de CORS.
                                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                                    
                                    // Agregar los subdominios es crucial
                                    subdomains: const ['a', 'b', 'c'],
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
        _checkFormValidity();
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
              'id': const Uuid().v4(), // Generamos ID único para la pista
              'title': 'Pista ${_clueForms.length + 1}',
              'description': '',
              // Aseguramos que 'type' sea 'minigame' por defecto para las pistas
              'type': 'minigame',
              // CORRECCIÓN: Usamos slidingPuzzle en lugar de riddle
              'puzzle_type': PuzzleType.slidingPuzzle.dbValue, 
              'riddle_question': '',
              'riddle_answer': '',
              'xp_reward': 50,
              'coin_reward': 10,
              'hint': '',
              'latitude': null,
              'longitude': null,
            });
          }
        } else {
          // ... (resto de la función)
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
        id: _eventId, // Usamos el ID consistente
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
          debugPrint('--- DATOS A ENVIAR ---');
          for (var clue in _clueForms) {
            debugPrint('Pista: ${clue['title']} | Tipo: ${clue['puzzle_type']} | Lat: ${clue['latitude']} | Long: ${clue['longitude']}');
          }
          
          // USAMOS EL PROVIDER DIRECTAMENTE (Más seguro para lat/long)
          await provider.createCluesBatch(createdEventId, _clueForms);
        }
        
        // --- GUARDADO DE TIENDAS ---
        if (createdEventId != null && _pendingStores.isNotEmpty) {
           final storeProvider = Provider.of<StoreProvider>(context, listen: false);
           debugPrint('Guardando ${_pendingStores.length} tiendas pendientes...');
           
           int succesfulStores = 0;
           for (var storeData in _pendingStores) {
             try {
                final store = storeData['store'] as MallStore;
                // CORRETION: We now use XFile for image handling in stores
                final imageFile = storeData['imageFile'] as XFile?;
                
                final storeToCreate = MallStore(
                  id: store.id,
                  eventId: createdEventId!, 
                  name: store.name,
                  description: store.description,
                  imageUrl: store.imageUrl,
                  qrCodeData: store.qrCodeData,
                  products: store.products,
                );
                await storeProvider.createStore(storeToCreate, imageFile);
                succesfulStores++;
             } catch (e) {
               debugPrint("Error creating store for event: $e");
               if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('⚠️ Error al crear tienda "${storeData['store'].name}": $e'), backgroundColor: Colors.orange),
                  );
               }
             }
           }
           
           if (mounted && succesfulStores < _pendingStores.length) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('⚠️ Se crearon $succesfulStores de ${_pendingStores.length} tiendas.'), backgroundColor: Colors.orange),
              );
           }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Competencia creada con éxito')),
          );
          
          // 3. Limpiamos el formulario
          _resetForm();

          // 4. EJECUTAMOS LA REDIRECCIÓN
          // Esto avisará al Dashboard que debe cambiar de pantalla
          widget.onEventCreated?.call(); 
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
      _eventId = const Uuid().v4(); // Reset with new ID for next creation
      _pendingStores = [];
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

                         // --- DATE & TIME PICKER ---
                        InkWell(
                          onTap: () async {
                            // 1. Pick Date
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppTheme.primaryPurple,
                                      onPrimary: Colors.white,
                                      surface: AppTheme.cardBg,
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            
                            if (pickedDate != null) {
                              // 2. Pick Time (if date was picked)
                              if (!context.mounted) return;
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(_selectedDate),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      timePickerTheme: TimePickerThemeData(
                                        backgroundColor: AppTheme.cardBg,
                                        hourMinuteTextColor: Colors.white,
                                        dayPeriodTextColor: Colors.white,
                                        dialHandColor: AppTheme.primaryPurple,
                                        dialBackgroundColor: AppTheme.darkBg,
                                        entryModeIconColor: AppTheme.accentGold,
                                      ),
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppTheme.primaryPurple,
                                        onPrimary: Colors.white,
                                        surface: AppTheme.cardBg,
                                        onSurface: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );

                              if (pickedTime != null) {
                                setState(() {
                                  _selectedDate = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: InputDecorator(
                            decoration: inputDecoration.copyWith(labelText: 'Fecha y Hora del Evento', prefixIcon: const Icon(Icons.access_time, color: Colors.white54)),
                            child: Text(
                              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}   ${_selectedDate.hour.toString().padLeft(2,'0')}:${_selectedDate.minute.toString().padLeft(2,'0')}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
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
                        // Bloque: Lugar (mapa) y Capacidad
                        // Usamos LayoutBuilder para decidir si mostrar en fila o columna
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Si el ancho es pequeño (móvil), usar columna
                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryPurple,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      onPressed: _selectLocationOnMap,
                                      icon: const Icon(Icons.map),
                                      label: const Text('Ubicación en Mapa'), // Shortened text
                                    ),
                                  ),
                                  if (_locationName != null &&
                                      _latitude != null &&
                                      _longitude != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        '📍 $_locationName',
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                  TextFormField(
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
                                ],
                              );
                            } 
                            // En escritorio, usamos la Row original
                            else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                          ),
                                          onPressed: _selectLocationOnMap,
                                          icon: const Icon(Icons.map),
                                          label: const Text('Seleccionar ubicación'),
                                        ),
                                        if (_locationName != null &&
                                            _latitude != null &&
                                            _longitude != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              'Ubicación: $_locationName',
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
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Fila: PIN y Pista Inicial
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: _pin,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(6),
                                          ],
                                          decoration: inputDecoration.copyWith(
                                            labelText: 'PIN de Acceso',
                                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                                            hintText: '123456',
                                          ),
                                          style: const TextStyle(color: Colors.white),
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Requerido';
                                            if (v.length != 6) return 'El PIN debe ser de 6 dígitos';
                                            return null;
                                          },
                                          onChanged: (v) => _pin = v,
                                          onSaved: (v) => _pin = v!,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 56,
                                        width: 56,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentGold.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.qr_code, color: AppTheme.accentGold),
                                          tooltip: "Generar QR",
                                          onPressed: () {
                                            // Auto-generar PIN si está vacío
                                            if (_pin.isEmpty || _pin.length != 6) {
                                              final random = Random();
                                              final newPin = (100000 + random.nextInt(900000)).toString();
                                              setState(() {
                                                _pin = newPin;
                                              });
                                              // Necesitamos refrescar el campo de texto visualmente
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('PIN generado automáticamente: $_pin')),
                                              );
                                            }
                                            
                                            // Mostrar QR usando el ID pre-generado
                                            if (_pin.length == 6) {
                                              final qrData = "EVENT:$_eventId:$_pin"; // Usamos _eventId que ya existe
                                              showDialog(
                                                context: context,
                                                builder: (_) => QRDisplayDialog(
                                                  data: qrData,
                                                  title: "QR de Acceso",
                                                  label: "PIN: $_pin",
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    initialValue: _clue,
                                    decoration: inputDecoration.copyWith(
                                        labelText:
                                            'Pista Inicial',
                                        prefixIcon: const Icon(
                                            Icons.lightbulb_outline,
                                            color: Colors.white54)),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Requerido' : null,
                                    onChanged: (v) => _clue = v,
                                    onSaved: (v) => _clue = v!,
                                    maxLines: 2, // Allow more space for clue text
                                  ),
                                ],
                              );
                            } else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: _pin,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(6),
                                            ],
                                            decoration: inputDecoration.copyWith(
                                              labelText: 'PIN de Acceso',
                                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                                              hintText: '123456',
                                            ),
                                            style: const TextStyle(color: Colors.white),
                                            validator: (v) {
                                              if (v == null || v.isEmpty) return 'Requerido';
                                              if (v.length != 6) return 'El PIN debe ser de 6 dígitos';
                                              return null;
                                            },
                                            onChanged: (v) => _pin = v,
                                            onSaved: (v) => _pin = v!,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          height: 56,
                                          width: 56,
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentGold.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.qr_code, color: AppTheme.accentGold),
                                            tooltip: "Generar QR",
                                            onPressed: () {
                                              // Auto-generar PIN si está vacío
                                              if (_pin.isEmpty || _pin.length != 6) {
                                                final random = Random();
                                                final newPin = (100000 + random.nextInt(900000)).toString();
                                                setState(() {
                                                  _pin = newPin;
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('PIN generado automáticamente: $_pin')),
                                                );
                                              }

                                              if (_pin.length == 6) {
                                                final qrData = "EVENT:$_eventId:$_pin"; // Usamos _eventId
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => QRDisplayDialog(
                                                    data: qrData,
                                                    title: "QR de Acceso",
                                                    label: "PIN: $_pin",
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ],
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
                              );
                            }
                          },
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
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 400) {
                                    // Mobile View: Column
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Generador de Pistas",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: _numberOfClues.toString(),
                                                textAlign: TextAlign.center,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(2),
                                                ],
                                                decoration: inputDecoration.copyWith(
                                                    contentPadding:
                                                        const EdgeInsets.all(10),
                                                    isDense: true,
                                                    hintText: 'Max 12'),
                                                style: const TextStyle(color: Colors.white),
                                                onChanged: (v) {
                                                  // ... logic copied
                                                  int? parsedValue = int.tryParse(v);
                                                  if (parsedValue != null) {
                                                    if (parsedValue > 12) {
                                                      _numberOfClues = 12;
                                                    } else if (parsedValue < 0) {
                                                      _numberOfClues = 0;
                                                    } else {
                                                      _numberOfClues = parsedValue;
                                                    }
                                                  } else if (v.isEmpty) {
                                                    _numberOfClues = 0;
                                                  }
                                                  setState(() {
                                                    _numberOfClues;
                                                  });
                                                },
                                                validator: (v) {
                                                   // ... validator logic copied
                                                    if (v == null || v.isEmpty) return 'Requerido';
                                                    int? num = int.tryParse(v);
                                                    if (num == null || num <= 0) return 'Mín. 1';
                                                    if (num > 12) return 'Máximo 12 pistas';
                                                    return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton(
                                              onPressed: () {
                                                 if (_numberOfClues > 12) _numberOfClues = 12;
                                                 if (_numberOfClues <= 0) return;
                                                 _generateClueForms();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.accentGold,
                                                foregroundColor: Colors.black,
                                              ),
                                              child: const Text("Generar"),
                                            ),
                                          ],
                                        )
                                      ],
                                    );
                                  } else {
                                    // Desktop/Wide View: Row
                                    return Row(
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
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(2),
                                            ],
                                            decoration: inputDecoration.copyWith(
                                                contentPadding:
                                                    const EdgeInsets.all(10),
                                                isDense: true,
                                                hintText: 'Max 12'),
                                            style:
                                                const TextStyle(color: Colors.white),
                                            onChanged: (v) {
                                                // ... logic copied
                                                int? parsedValue = int.tryParse(v);
                                                  if (parsedValue != null) {
                                                    if (parsedValue > 12) {
                                                      _numberOfClues = 12;
                                                    } else if (parsedValue < 0) {
                                                      _numberOfClues = 0;
                                                    } else {
                                                      _numberOfClues = parsedValue;
                                                    }
                                                  } else if (v.isEmpty) {
                                                    _numberOfClues = 0;
                                                  }
                                                  setState(() {
                                                    _numberOfClues;
                                                  });
                                            },
                                            validator: (v) {
                                                // ... validator logic copied
                                                if (v == null || v.isEmpty) return 'Requerido';
                                                int? num = int.tryParse(v);
                                                if (num == null || num <= 0) return 'Mín. 1';
                                                if (num > 12) return 'Máximo 12 pistas';
                                                return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          onPressed: () {
                                             if (_numberOfClues > 12) _numberOfClues = 12;
                                             if (_numberOfClues <= 0) return;
                                             _generateClueForms();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.accentGold,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: const Text("Generar"),
                                        ),
                                      ],
                                    );
                                  }
                                },
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
                                        // --- 1. SELECTOR DE TIPO DE JUEGO (NUEVO) ---
                                        // ... dentro de tu build ...

                                      // --- 1. SELECTOR DE TIPO DE JUEGO (DINÁMICO) ---
                                      DropdownButtonFormField<String>(
                                        // CORRECCIÓN: Usamos slidingPuzzle como fallback seguro
                                        value: _clueForms[_currentClueIndex]['puzzle_type'] ?? PuzzleType.slidingPuzzle.dbValue,
                                        isExpanded: true, // Fix overflow
                                        decoration: inputDecoration.copyWith(
                                          labelText: 'Tipo de Desafío',
                                          prefixIcon: const Icon(Icons.games, color: Colors.white54),
                                        ),
                                        dropdownColor: const Color(0xFF2A2D3E),
                                        style: const TextStyle(color: Colors.white),
                                        items: PuzzleType.values.map((type) {
                                          return DropdownMenuItem<String>(
                                            value: type.dbValue,
                                            child: Text(
                                              type.label,
                                              overflow: TextOverflow.ellipsis, // Fix overflow text
                                            ),
                                          );
                                        }).toList(),

                                        onChanged: (selectedValue) {
                                          if (selectedValue == null) return;

                                          setState(() {
                                            _clueForms[_currentClueIndex]['puzzle_type'] = selectedValue;
                                            // --- ESTA LÍNEA ES CLAVE ---
                                            _clueForms[_currentClueIndex]['type'] = 'minigame'; // Aseguramos que siempre sea 'minigame'

                                            final selectedType = PuzzleType.values.firstWhere(
                                              (e) => e.dbValue == selectedValue, 
                                              // CORRECCIÓN: Usamos slidingPuzzle como fallback seguro
                                              orElse: () => PuzzleType.slidingPuzzle
                                            );

                                            // Aplicamos la lógica automática centralizada
                                            if (selectedType.isAutoValidation) {
                                              // Para TicTacToe, Sliding Puzzle
                                              _clueForms[_currentClueIndex]['riddle_answer'] = 'WIN'; 
                                            } else if (selectedType == PuzzleType.hangman) {
                                              _clueForms[_currentClueIndex]['riddle_answer'] = ''; 
                                            } else {
                                              // Si es riddle o cualquier otro, lo dejamos vacío para que el admin lo llene
                                              _clueForms[_currentClueIndex]['riddle_answer'] = '';
                                            }

                                            // Rellenamos la pregunta por defecto si está vacía
                                            _clueForms[_currentClueIndex]['riddle_question'] = selectedType.defaultQuestion;
                                          });
                                        },
                                      ),


                                        const SizedBox(height: 15),

                                        // --- TÍTULO Y QR ---
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: _clueForms[_currentClueIndex]['title'],
                                                decoration: inputDecoration.copyWith(labelText: 'Título de la Pista'),
                                                style: const TextStyle(color: Colors.white),
                                                onChanged: (v) => _clueForms[_currentClueIndex]['title'] = v,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            
                                            // BOTÓN GENERAR QR (NUEVO)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: _clueForms[_currentClueIndex]['id'] == null ? Colors.grey : AppTheme.accentGold,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.qr_code_2, color: Colors.black),
                                                tooltip: "Generar QR para esta pista",
                                                onPressed: () {
                                                  final clueId = _clueForms[_currentClueIndex]['id'];
                                                  if (clueId != null) {
                                                    final qrData = "CLUE:$_eventId:$clueId";
                                                    _showQRDialog(qrData, "QR de Pista $_eventId");
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text("Error: ID de pista no generado")),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // --- DESCRIPCIÓN ---
                                        TextFormField(
                                          initialValue: _clueForms[_currentClueIndex]['description'],
                                          decoration: inputDecoration.copyWith(labelText: 'Instrucciones / Historia'),
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (v) => _clueForms[_currentClueIndex]['description'] = v,
                                        ),
                                        const SizedBox(height: 10),

                                        // --- PREGUNTA / PISTA (Dinámico según tipo) ---
                                        TextFormField(
                                          // Usamos Key para forzar el redibujado si cambia el tipo de juego
                                          key: ValueKey('q_${_clueForms[_currentClueIndex]['puzzle_type']}'),
                                          initialValue: _clueForms[_currentClueIndex]['riddle_question'],
                                          decoration: inputDecoration.copyWith(
                                            labelText: _clueForms[_currentClueIndex]['puzzle_type'] == 'hangman' 
                                                ? 'Pista de la Palabra (Ej: Framework de Google)' 
                                                // CORRECCIÓN: Eliminada referencia a riddle
                                                : 'Instrucción del Juego',
                                          ),
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (v) => _clueForms[_currentClueIndex]['riddle_question'] = v,
                                        ),
                                        const SizedBox(height: 10),

                                        // --- RESPUESTA CORRECTA (Oculto para juegos automáticos) ---
                                        // CORRECCIÓN: Solo mostramos si es Hangman (Ahorcado), ya que Riddle fue eliminado
                                        if (_clueForms[_currentClueIndex]['puzzle_type'] == 'hangman')
                                          TextFormField(
                                            key: ValueKey('a_${_clueForms[_currentClueIndex]['puzzle_type']}'),
                                            initialValue: _clueForms[_currentClueIndex]['riddle_answer'],
                                            decoration: inputDecoration.copyWith(
                                              labelText: 'Palabra a Adivinar (Ej: FLUTTER)',
                                              helperText: 'Sin espacios ni caracteres especiales preferiblemente.',
                                              helperStyle: TextStyle(color: Colors.white54)
                                            ),
                                            style: const TextStyle(color: Colors.white),
                                            onChanged: (v) => _clueForms[_currentClueIndex]['riddle_answer'] = v,
                                            validator: (v) => v!.isEmpty ? 'Requerido para validar la victoria' : null,
                                          ),

                                        const SizedBox(height: 10),

                                        // --- RECOMPENSAS ---
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: _clueForms[_currentClueIndex]['xp_reward'].toString(),
                                                decoration: inputDecoration.copyWith(labelText: 'XP'),
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(color: Colors.white),
                                                onChanged: (v) => _clueForms[_currentClueIndex]['xp_reward'] = int.tryParse(v) ?? 0,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: _clueForms[_currentClueIndex]['coin_reward'].toString(),
                                                decoration: inputDecoration.copyWith(labelText: 'Monedas'),
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(color: Colors.white),
                                                onChanged: (v) => _clueForms[_currentClueIndex]['coin_reward'] = int.tryParse(v) ?? 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // --- GEOLOCALIZACIÓN ---
                                        const Text("📍 Geolocalización (Opcional)", style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          initialValue: _clueForms[_currentClueIndex]['hint'],
                                          decoration: inputDecoration.copyWith(
                                            labelText: 'Pista de Ubicación QR (ej: Detrás del árbol)',
                                            prefixIcon: const Icon(Icons.location_on, color: Colors.white54),
                                          ),
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (v) => _clueForms[_currentClueIndex]['hint'] = v,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                key: ValueKey('lat_${_clueForms[_currentClueIndex]['latitude']}'),
                                                initialValue: _clueForms[_currentClueIndex]['latitude']?.toString() ?? '',
                                                decoration: inputDecoration.copyWith(labelText: 'Latitud'),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                style: const TextStyle(color: Colors.white),
                                                onChanged: (v) => _clueForms[_currentClueIndex]['latitude'] = double.tryParse(v),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextFormField(
                                                key: ValueKey('long_${_clueForms[_currentClueIndex]['longitude']}'),
                                                initialValue: _clueForms[_currentClueIndex]['longitude']?.toString() ?? '',
                                                decoration: inputDecoration.copyWith(labelText: 'Longitud'),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                style: const TextStyle(color: Colors.white),
                                                onChanged: (v) => _clueForms[_currentClueIndex]['longitude'] = double.tryParse(v),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          alignment: WrapAlignment.spaceEvenly,
                                          spacing: 10,
                                          runSpacing: 5,
                                          children: [
                                            TextButton.icon(
                                              icon: const Icon(Icons.store, size: 16),
                                              label: const Text("Usar Evento", style: TextStyle(fontSize: 12)),
                                              onPressed: () {
                                                setState(() {
                                                  _clueForms[_currentClueIndex]['latitude'] = _latitude;
                                                  _clueForms[_currentClueIndex]['longitude'] = _longitude;
                                                });
                                              },
                                            ),
                                            TextButton.icon(
                                              icon: const Icon(Icons.my_location, size: 16),
                                              label: const Text("Mi Ubicación", style: TextStyle(fontSize: 12)),
                                              onPressed: () async {
                                                try {
                                                  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                                  if (!serviceEnabled) throw Exception("GPS desactivado");
                                                  
                                                  LocationPermission permission = await Geolocator.checkPermission();
                                                  if (permission == LocationPermission.denied) {
                                                    permission = await Geolocator.requestPermission();
                                                    if (permission == LocationPermission.denied) throw Exception("Permiso denegado");
                                                  }
                                                  
                                                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
                                                  setState(() {
                                                    _clueForms[_currentClueIndex]['latitude'] = position.latitude;
                                                    _clueForms[_currentClueIndex]['longitude'] = position.longitude;
                                                  });
                                                } catch(e) {
                                                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                                }
                                              },
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

                        // Seccion Tiendas Aliadas
                        const Text("Tiendas Aliadas",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGold)),
                        const SizedBox(height: 10),
                        const Text(
                          "Agrega tiendas que participarán en el evento (opcional).",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        
                        if (_pendingStores.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child:  Center(
                              child: Column(
                                children: const [
                                  Icon(Icons.store_mall_directory_outlined, size: 40, color: Colors.white24),
                                  SizedBox(height: 10),
                                  Text("No hay tiendas agregadas", style: TextStyle(color: Colors.white54)),
                                ],
                              ),
                            ),
                          ),
                          
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingStores.length,
                          itemBuilder: (context, index) {
                            final storeData = _pendingStores[index];
                            final store = storeData['store'] as MallStore;
                            return Card(
                              color: AppTheme.cardBg,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.store, color: AppTheme.accentGold),
                                title: Text(store.name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text("${store.products.length} productos", style: const TextStyle(color: Colors.white70)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removePendingStore(index),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _addPendingStore,
                            icon: const Icon(Icons.add),
                            label: const Text("Agregar Tienda"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentGold,
                              side: const BorderSide(color: AppTheme.accentGold),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
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
                                disabledBackgroundColor: Color(0xFF2A2D3E), // Solid dark color matching input bg
                                disabledForegroundColor: Colors.white30,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0, // Flat button to remove "reflection"
                                shadowColor: Colors.transparent),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text("PUBLICAR", // Shortened to prevent wrapping
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                          ),

                        ),
                        // Espacio extra para evitar que el botón quede pegado al borde o cubierto
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQRDialog(String data, String label) {
    showDialog(
      context: context,
      builder: (context) => QRDisplayDialog(
        data: data,
        title: "QR DE: $label",
        label: label,
      ),
    );
  }
}