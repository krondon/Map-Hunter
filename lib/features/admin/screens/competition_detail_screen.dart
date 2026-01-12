import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../../game/models/event.dart';
import '../../game/models/clue.dart';
import '../../game/providers/event_provider.dart';
import '../../game/providers/game_request_provider.dart';
import '../../game/models/game_request.dart';
import 'package:geolocator/geolocator.dart'; 
import '../../../core/theme/app_theme.dart';
import '../widgets/qr_display_dialog.dart';
import '../../auth/providers/player_provider.dart'; 
import '../../../shared/models/player.dart'; 
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http; 
import '../../mall/providers/store_provider.dart';
import '../widgets/store_edit_dialog.dart';
import '../../mall/models/mall_store.dart'; 

class CompetitionDetailScreen extends StatefulWidget {
  final GameEvent event;

  const CompetitionDetailScreen({super.key, required this.event});

  @override
  State<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Helper method for consistent input styling
  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: icon != null ? Icon(icon, color: Colors.white54) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Form State
  late String _title;
  late String _description;
  late String _locationName;
  late TextEditingController _locationController;

  void _showQRDialog(String data, String title, String label, {String? hint}) {
    showDialog(
      context: context,
      builder: (_) => QRDisplayDialog(data: data, title: title, label: label, hint: hint),
    );
  }
  late double _latitude;
  late double _longitude;
  late String _clue;
  late String _pin;
  late int _maxParticipants;
  late DateTime _selectedDate;
  
  XFile? _selectedImage;
  bool _isLoading = false;
  List<Map<String, dynamic>> _leaderboardData = []; 

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await Supabase.instance.client
          .from('event_leaderboard')
          .select()
          .eq('event_id', widget.event.id)
          .order('completed_clues', ascending: false)
          .order('last_completion_time', ascending: true);
      
      if (mounted) {
        setState(() {
            _leaderboardData = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
    
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB
    });

    // Initialize form data
    _title = widget.event.title;
    _description = widget.event.description;
    _locationName = widget.event.locationName;
    _locationController = TextEditingController(text: _locationName);
    _latitude = widget.event.latitude;
    _longitude = widget.event.longitude;
    _clue = widget.event.clue;
    _pin = widget.event.pin;
    _maxParticipants = widget.event.maxParticipants;
    _selectedDate = widget.event.date;

    // Load requests for this event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameRequestProvider>(context, listen: false).fetchAllRequests();
      // Cargar lista de jugadores para verificar estados de baneo
      Provider.of<PlayerProvider>(context, listen: false).fetchAllPlayers();
      _fetchLeaderboard(); // Cargar ranking
      // Cargar tiendas
      Provider.of<StoreProvider>(context, listen: false).fetchStores(widget.event.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectLocationOnMap() async {
    // Obtener ubicación actual para centrar el mapa
    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Servicios de ubicación deshabilitados.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
         position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
         );
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
    }
    
    // Si ya tenemos una ubicación guardada, usarla como inicial
    final latlng.LatLng initial = (_latitude != 0 && _longitude != 0) // Check if valid (assuming 0 is invalid/default)
        ? latlng.LatLng(_latitude, _longitude)
        : (position != null
            ? latlng.LatLng(position.latitude, position.longitude)
            : const latlng.LatLng(10.4806, -66.9036)); 

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
                                    const latlng.LatLng(0.5, -73.5), 
                                    const latlng.LatLng(12.5, -59.5), 
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
                                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
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
      final apiKey = 'pk.45e576837f12504a63c6d1893820f1cf'; 
      final url = Uri.parse(
          'https://us1.locationiq.com/v1/reverse.php?key=$apiKey&lat=${picked!.latitude}&lon=${picked!.longitude}&format=json');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
             address = data['display_name'] ?? 'Ubicación seleccionada';
          }
        } else {
          address = 'Ubicación seleccionada';
        }
      } catch (_) {
        address = 'Ubicación seleccionada';
      }
      
      if (mounted) {
        setState(() {
          _latitude = picked!.latitude;
          _longitude = picked!.longitude;
          if (address != null) {
            _locationName = address!;
            _locationController.text = _locationName;
          }
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final updatedEvent = GameEvent(
        id: widget.event.id,
        title: _title,
        description: _description,
        locationName: _locationName,
        latitude: _latitude,
        longitude: _longitude,
        date: _selectedDate,
        createdByAdminId: widget.event.createdByAdminId,
        imageUrl: widget.event.imageUrl, // Will be updated by provider if _selectedImage is not null
        clue: _clue,
        maxParticipants: _maxParticipants,
        pin: _pin,
      );

      await Provider.of<EventProvider>(context, listen: false)
          .updateEvent(updatedEvent, _selectedImage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Competencia actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<bool> _showConfirmDialog() async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg, // Usa el tema definido en tu app
      title: const Text("Confirmar Reinicio", style: TextStyle(color: Colors.white)),
      content: const Text(
        "¿Estás seguro? Se expulsará a todos los jugadores, se borrará su progreso y las pistas volverán a bloquearse. Esta acción no se puede deshacer.",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("REINICIAR", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  ) ?? false; // Retorna false si el usuario cierra el diálogo sin presionar nada
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: Text(widget.event.title),
        actions: [
          IconButton(
      icon: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
      tooltip: "Reiniciar Competencia",
      onPressed: () async {
        final confirmed = await _showConfirmDialog();
        if (!confirmed) return;

        setState(() => _isLoading = true);
        try {
          // 1. Llamar al reset nuclear en el servidor
          await Provider.of<EventProvider>(context, listen: false)
              .restartCompetition(widget.event.id);
          
          // 2. Limpiar las solicitudes locales
          Provider.of<GameRequestProvider>(context, listen: false).clearLocalRequests();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Competencia reiniciada exitosamente')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al reiniciar: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {});
              Provider.of<GameRequestProvider>(context, listen: false).fetchAllRequests();
              _fetchLeaderboard(); // Recargar ranking
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          tabs: const [
            Tab(text: "Detalles"),
            Tab(text: "Participantes"),
            Tab(text: "Pistas de Juego"),
            Tab(text: "Tiendas"),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDetailsTab(),
            _buildParticipantsTab(),
            _buildCluesTab(),
            _buildStoresTab(),
          ],
        ),
      ),
      floatingActionButton: _getFAB(),
    );
  }

  Widget? _getFAB() {
    if (_tabController.index == 2) {
      return FloatingActionButton(
        backgroundColor: AppTheme.primaryPurple,
        onPressed: () => _showAddClueDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      );
    } else if (_tabController.index == 3) {
      return FloatingActionButton(
        backgroundColor: AppTheme.accentGold,
        onPressed: () => _showAddStoreDialog(),
        child: const Icon(Icons.store, color: Colors.white),
      );
    }
    return null;
  }

  Widget _buildDetailsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: AppTheme.cardBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: NetworkImage(_selectedImage!.path), // For web/network usually needs specific handling but works for XFile path on mobile often or bytes
                          fit: BoxFit.cover,
                        )
                      : (widget.event.imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(widget.event.imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: _selectedImage == null && widget.event.imageUrl.isEmpty
                    ? const Icon(Icons.add_a_photo, size: 50, color: Colors.white54)
                    : null,
              ),
            ),
            if (_selectedImage != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("Nueva imagen seleccionada (guardar para aplicar)", style: TextStyle(color: Colors.greenAccent)),
              ),
            const SizedBox(height: 20),

            // Fields
            TextFormField(
              initialValue: _title,
              style: const TextStyle(color: Colors.white),
              decoration: inputDecoration.copyWith(labelText: 'Título'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => _title = v!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _description,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: inputDecoration.copyWith(labelText: 'Descripción'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => _description = v!,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _pin,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration.copyWith(labelText: 'PIN (6 dígitos)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) => v!.length != 6 ? 'Debe tener 6 dígitos' : null,
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
                    tooltip: "Ver QR del Evento",
                    onPressed: () {
                      if (_pin.length == 6) {
                        final qrData = "EVENT:${widget.event.id}:$_pin";
                        _showQRDialog(qrData, "QR de Acceso", "PIN: $_pin");
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Guarda el PIN primero')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxParticipants.toString(),
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration.copyWith(labelText: 'Max. Jugadores'),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => _maxParticipants = int.parse(v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _clue,
              style: const TextStyle(color: Colors.white),
              decoration: inputDecoration.copyWith(labelText: 'Pista de Victoria / Final'),
              onSaved: (v) => _clue = v!,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration.copyWith(labelText: 'Nombre de Ubicación'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => _locationName = v!,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.5)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.map, color: AppTheme.primaryPurple),
                    tooltip: "Seleccionar en Mapa",
                    onPressed: _selectLocationOnMap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
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
                decoration: _buildInputDecoration('Fecha y Hora del Evento', icon: Icons.access_time),
                child: Text(
                  "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}   ${_selectedDate.hour.toString().padLeft(2,'0')}:${_selectedDate.minute.toString().padLeft(2,'0')}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
             const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text("Guardar Cambios"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTab() {
    return Consumer<GameRequestProvider>(
      builder: (context, provider, _) {
        // Obtenemos el proveedor de jugadores para verificar estados
        final playerProvider = Provider.of<PlayerProvider>(context);
        
        // Filter requests for THIS event
        final allRequests = provider.requests.where((r) => r.eventId == widget.event.id).toList();
        
        final approved = allRequests.where((r) => r.isApproved).toList();
        final pending = allRequests.where((r) => r.isPending).toList();

        if (allRequests.isEmpty) {
          return const Center(child: Text("No hay participantes ni solicitudes.", style: TextStyle(color: Colors.white54)));
        }

        // --- SORT LOGIC FIX ---
        // 0. Identify banned players
        final bannedIds = playerProvider.allPlayers
           .where((p) => p.status == PlayerStatus.banned)
           .map((p) => p.id)
           .toSet();

        // 1. Build a 'virtual' leaderboard excluding banned players for ranking calculation
        final activeLeaderboard = _leaderboardData.where((entry) {
           final userId = entry['user_id'];
           return !bannedIds.contains(userId);
        }).toList();

        // 2. Convert to List explicitly to avoid map type issues
        final sortedApproved = approved.toList();
        
        // 3. Sort: Non-banned first (ordered by rank), then undefined/banned at bottom
        sortedApproved.sort((a, b) {
           final isBannedA = bannedIds.contains(a.playerId);
           final isBannedB = bannedIds.contains(b.playerId);
           
           // Banned users go to bottom
           if (isBannedA && !isBannedB) return 1;
           if (!isBannedA && isBannedB) return -1;
           if (isBannedA && isBannedB) return 0; // Keep relative order among banned

           // Both active: compare using rank in activeLeaderboard
           final indexA = activeLeaderboard.indexWhere((l) => l['user_id'] == a.playerId);
           final indexB = activeLeaderboard.indexWhere((l) => l['user_id'] == b.playerId);
           
           // If not in leaderboard, put at bottom of active users
           final rankA = indexA == -1 ? 9999 : indexA;
           final rankB = indexB == -1 ? 9999 : indexB;
           
           return rankA.compareTo(rankB);
        });

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              const Text("Solicitudes Pendientes", style: TextStyle(color: AppTheme.secondaryPink, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...pending.map((req) => _RequestTile(request: req)),
              const SizedBox(height: 20),
            ],
            
            const Text("Participantes Inscritos (Ranking)", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (approved.isEmpty)
              const Text("Nadie inscrito aún.", style: TextStyle(color: Colors.white30))
            else
              // 4. Map safely to Widgets
              ...sortedApproved.map((req) {
                 final isBanned = bannedIds.contains(req.playerId);
                 
                 // Get rank from activeLeaderboard ONLY if not banned
                 final index = !isBanned 
                     ? activeLeaderboard.indexWhere((l) => l['user_id'] == req.playerId)
                     : -1;
                     
                 // Progress comes from raw data (still useful to see even if banned)
                 final rawIndex = _leaderboardData.indexWhere((l) => l['user_id'] == req.playerId);
                 final progress = rawIndex != -1 ? _leaderboardData[rawIndex]['completed_clues'] as int : 0;
                 
                 return _RequestTile(
                   request: req, 
                   isReadOnly: true,
                   rank: index != -1 ? index + 1 : null, // Pass null rank if banned or unranked
                   progress: progress,
                 );
              }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCluesTab() {
    return FutureBuilder<List<Clue>>(
      future: Provider.of<EventProvider>(context, listen: false).fetchCluesForEvent(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No hay pistas configuradas para este evento.", style: TextStyle(color: Colors.white54)));
        }

        final clues = snapshot.data!;
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final clue = clues[index];
            return Card(
              color: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryPurple.withOpacity(0.2),
                  child: Text("${index + 1}", style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
                ),
                title: Text(clue.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("${clue.typeName} - ${clue.puzzleType.label}", style: const TextStyle(color: Colors.white70)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code, color: AppTheme.accentGold),
                      tooltip: "Ver QR",
                      onPressed: () {
                         final qrData = "CLUE:${widget.event.id}:${clue.id}";
                         _showQRDialog(qrData, clue.title, "Pista: ${clue.puzzleType.label}", hint: clue.hint);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.accentGold),
                      onPressed: () => _showEditClueDialog(clue),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditClueDialog(Clue clue) {
    // Controllers for persistent state
    final titleController = TextEditingController(text: clue.title);
    final descriptionController = TextEditingController(text: clue.description);
    final questionController = TextEditingController(text: clue.riddleQuestion ?? '');
    final answerController = TextEditingController(text: clue.riddleAnswer ?? '');
    final xpController = TextEditingController(text: clue.xpReward.toString());
    final coinController = TextEditingController(text: clue.coinReward.toString());
    final hintController = TextEditingController(text: clue.hint);
    final latController = TextEditingController(text: clue.latitude?.toString() ?? '');
    final longController = TextEditingController(text: clue.longitude?.toString() ?? '');

    PuzzleType selectedType = clue.puzzleType;
    
    // We still need these as variables to handle logic, but data comes from controllers
    double? latitude = clue.latitude;
    double? longitude = clue.longitude;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("Editar Pista / Minijuego", style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   DropdownButtonFormField<PuzzleType>(
                    value: selectedType,
                    dropdownColor: AppTheme.darkBg,
                    isExpanded: true, // Fix overflow
                    decoration: _buildInputDecoration('Tipo de Minijuego', icon: Icons.games),
                    style: const TextStyle(color: Colors.white),
                    items: PuzzleType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.label,
                          overflow: TextOverflow.ellipsis, // Fix overflow text
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                         setStateDialog(() {
                           selectedType = val;
                           // Set default question if switching types
                           if (questionController.text.isEmpty) {
                             questionController.text = val.defaultQuestion;
                           }
                         });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Título'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Descripción / Historia'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: questionController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Pregunta / Instrucción'),
                  ),
                  const SizedBox(height: 10),
                  if (!selectedType.isAutoValidation)
                    TextFormField(
                      controller: answerController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Respuesta Correcta'),
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: xpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Puntos XP'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: coinController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Monedas'),
                  ),
                  const SizedBox(height: 20),
                  const Text("📍 Geolocalización (Opcional)", style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: hintController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Pista de Ubicación QR (ej: Detrás del árbol)', icon: Icons.location_on),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Latitud'),
                          onChanged: (v) => latitude = double.tryParse(v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: longController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Longitud'),
                          onChanged: (v) => longitude = double.tryParse(v),
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
                           setStateDialog(() {
                             latitude = widget.event.latitude;
                             longitude = widget.event.longitude;
                             latController.text = latitude.toString();
                             longController.text = longitude.toString();
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
                             setStateDialog(() {
                               latitude = position.latitude;
                               longitude = position.longitude;
                               latController.text = latitude.toString();
                               longController.text = longitude.toString();
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
            );
          },
        ),
        actions: [
          // Delete Button
          TextButton(
            onPressed: () {
               showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.cardBg,
                  title: const Text('Eliminar Pista', style: TextStyle(color: Colors.white)),
                  content: const Text('¿Estás seguro de que quieres eliminar esta pista? Esta acción no se puede deshacer.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        try {
                          Navigator.pop(context); // Close confirm dialog
                          await Provider.of<EventProvider>(ctx, listen: false).deleteClue(clue.id);
                          if (mounted) {
                            Navigator.pop(ctx); // Close edit dialog
                             setState(() {}); // Force refresh
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Pista eliminada')));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            onPressed: () async {
              try {
                // Create updated clue object
                final updatedClue = Clue(
                  id: clue.id,
                  title: titleController.text,
                  description: descriptionController.text, // Keep original or add field if needed
                  hint: hintController.text, // Updated value
                  type: clue.type,
                  latitude: latitude, // Updated value
                  longitude: longitude, // Updated value
                  qrCode: clue.qrCode,
                  minigameUrl: clue.minigameUrl,
                  xpReward: int.tryParse(xpController.text) ?? 50,
                  coinReward: int.tryParse(coinController.text) ?? 10,
                  puzzleType: selectedType,
                  riddleQuestion: questionController.text,
                  riddleAnswer: answerController.text,
                  isLocked: clue.isLocked,
                  isCompleted: clue.isCompleted,
                  sequenceIndex: clue.sequenceIndex,
                );

                await Provider.of<EventProvider>(context, listen: false).updateClue(updatedClue);
                
                if (mounted) {
                   Navigator.pop(ctx);
                   setState(() {}); // Refresh UI
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pista actualizada')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

void _showRestartConfirmDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text("¿Reiniciar Competencia?", style: TextStyle(color: Colors.white)),
      content: const Text(
        "Esto expulsará a todos los participantes actuales, eliminará su progreso y bloqueará las pistas nuevamente. Esta acción no se puede deshacer.",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
          final confirm = await _showConfirmDialog(); // Diálogo de confirmación
          if (!confirm) return;

          setState(() => _isLoading = true);
          try {
            // 1. Ejecutar limpieza en base de datos
            await Provider.of<EventProvider>(context, listen: false)
                .restartCompetition(widget.event.id);
            
            // 2. Limpiar visualmente la lista de solicitudes/participantes
            Provider.of<GameRequestProvider>(context, listen: false).clearLocalRequests();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Competencia y progreso eliminados correctamente')),
              );
            }
          } catch (e) {
            // Manejo de error
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
          child: const Text("REINICIAR AHORA", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  void _showAddClueDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final questionController = TextEditingController();
    final answerController = TextEditingController();
    final xpController = TextEditingController(text: '50');
    final coinController = TextEditingController(text: '10');
    final hintController = TextEditingController();
    final latController = TextEditingController();
    final longController = TextEditingController();

    // CORRECCIÓN: 'riddle' ya no existe en PuzzleType.
    PuzzleType selectedType = PuzzleType.slidingPuzzle; 

    double? latitude;
    double? longitude;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("Agregar Nueva Pista", style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   DropdownButtonFormField<PuzzleType>(
                    value: selectedType,
                    dropdownColor: AppTheme.darkBg,
                    isExpanded: true, 
                    decoration: _buildInputDecoration('Tipo de Minijuego', icon: Icons.games),
                    style: const TextStyle(color: Colors.white),
                    items: PuzzleType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                         setStateDialog(() {
                           selectedType = val;
                           if (questionController.text.isEmpty) {
                             questionController.text = val.defaultQuestion;
                           }
                         });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Título'),
                  ),
                  const SizedBox(height: 10),
                   TextFormField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Descripción / Historia'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: questionController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Pregunta / Instrucción'),
                  ),
                  const SizedBox(height: 10),
                  if (!selectedType.isAutoValidation)
                    TextFormField(
                      controller: answerController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Respuesta Correcta'),
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: xpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Puntos XP'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: coinController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Monedas'),
                  ),
                  const SizedBox(height: 20),
                  const Text("📍 Geolocalización (Opcional)", style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: hintController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Pista de Ubicación QR (ej: Detrás del árbol)', icon: Icons.location_on),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Latitud'),
                          onChanged: (v) => latitude = double.tryParse(v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: longController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration('Longitud'),
                          onChanged: (v) => longitude = double.tryParse(v),
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
                           setStateDialog(() {
                             latitude = widget.event.latitude;
                             longitude = widget.event.longitude;
                             latController.text = latitude.toString();
                             longController.text = longitude.toString();
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
                             setStateDialog(() {
                               latitude = position.latitude;
                               longitude = position.longitude;
                               latController.text = latitude.toString();
                               longController.text = longitude.toString();
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
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            onPressed: () async {
              try {
                if (titleController.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El título es requerido')));
                   return;
                }
                
                // Create new clue object
                final newClue = Clue(
                  id: '', // Will be generated by DB
                  title: titleController.text,
                  description: descriptionController.text,
                  hint: hintController.text,
                  type: ClueType.minigame, // Default to minigame
                  xpReward: int.tryParse(xpController.text) ?? 50,
                  coinReward: int.tryParse(coinController.text) ?? 10,
                  latitude: latitude,
                  longitude: longitude,
                  puzzleType: selectedType,
                  riddleQuestion: questionController.text,
                  riddleAnswer: answerController.text,
                );

                await Provider.of<EventProvider>(context, listen: false).addClue(widget.event.id, newClue);
                
                if (mounted) {
                   Navigator.pop(ctx);
                   setState(() {}); // Refresh UI
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pista agregada')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text("Agregar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Widget _buildStoresTab() {
    return Consumer<StoreProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final stores = provider.stores;

        if (stores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store_mall_directory, size: 80, color: Colors.white24),
                const SizedBox(height: 16),
                const Text("No hay tiendas registradas", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddStoreDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Agregar Tienda"),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            return Card(
              color: AppTheme.cardBg,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: Container(
                    width: 60, 
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      image: (store.imageUrl.isNotEmpty && store.imageUrl.startsWith('http')) 
                        ? DecorationImage(image: NetworkImage(store.imageUrl), fit: BoxFit.cover)
                        : null,
                    ),
                    child: (store.imageUrl.isEmpty || !store.imageUrl.startsWith('http'))
                      ? const Icon(Icons.store, color: Colors.white54)
                      : null,
                  ),
                title: Text(store.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "${store.description}\nProductos: ${store.products.length}",
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.qr_code, color: Colors.white),
                        tooltip: "Ver QR",
                        onPressed: () => _showQRDialog(
                              store.qrCodeData,
                              "QR de Tienda",
                              store.name,
                              hint: "Escanear para entrar",
                            )),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.accentGold),
                      onPressed: () => _showAddStoreDialog(store: store),
                    ),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteStore(store),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddStoreDialog({MallStore? store}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StoreEditDialog(store: store, eventId: widget.event.id),
    );

    if (result != null && mounted) {
      final newStore = result['store'] as MallStore;
      final imageFile = result['imageFile'];
      
      final provider = Provider.of<StoreProvider>(context, listen: false);
      try {
        if (store == null) {
          await provider.createStore(newStore, imageFile);
          if (mounted) _showSnackBar('Tienda creada exitosamente', Colors.green);
        } else {
          await provider.updateStore(newStore, imageFile);
          if (mounted) _showSnackBar('Tienda actualizada exitosamente', Colors.green);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  void _confirmDeleteStore(MallStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("Confirmar Eliminación", style: TextStyle(color: Colors.white)),
        content: Text("¿Estás seguro de eliminar a ${store.name}?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Provider.of<StoreProvider>(context, listen: false).deleteStore(store.id, widget.event.id);
                if (mounted) _showSnackBar('Tienda eliminada', Colors.green);
              } catch (e) {
                if (mounted) _showSnackBar('Error: $e', Colors.red);
              }
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

}




class _RequestTile extends StatelessWidget {
  final GameRequest request;
  final bool isReadOnly;
  final int? rank;
  final int? progress;

  const _RequestTile({
    required this.request, 
    this.isReadOnly = false,
    this.rank,
    this.progress,
  });

  void _toggleBan(BuildContext context, PlayerProvider provider, String userId, bool isBanned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(isBanned ? "Desbanear Usuario" : "Banear Usuario", style: const TextStyle(color: Colors.white)),
        content: Text(
          isBanned 
            ? "¿Permitir el acceso nuevamente a este usuario?" 
            : "¿Estás seguro? El usuario será expulsado de la app inmediatamente.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isBanned ? Colors.green : Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.toggleBanUser(userId, !isBanned);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isBanned ? "Usuario desbaneado" : "Usuario baneado")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: Text(isBanned ? "DESBANEAR" : "BANEAR", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        // Buscamos el estado REAL del usuario en la lista de profiles
        final userStatus = playerProvider.allPlayers
            .firstWhere((p) => p.id == request.playerId,
                 orElse: () => Player(id: '', email: '', name: '', role: '', status: PlayerStatus.active))
            .status;
            
        final isBanned = userStatus == PlayerStatus.banned;

        return Card(
          color: isBanned ? Colors.red.withOpacity(0.1) : AppTheme.cardBg, // Feedback visual en toda la tarjeta
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: (isReadOnly && rank != null) 
              ? CircleAvatar(
                  backgroundColor: _getRankColor(rank!),
                  foregroundColor: Colors.white,
                  child: Text("#$rank", style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
            title: Text(
              request.playerName ?? 'Desconocido', 
              style: TextStyle(
                color: isBanned ? Colors.redAccent : Colors.white,
                decoration: isBanned ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.bold,
              )
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.playerEmail ?? 'No email', style: const TextStyle(color: Colors.white54)),
                if (isReadOnly && progress != null)
                   Text("Pistas completadas: $progress", style: const TextStyle(color: AppTheme.accentGold, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReadOnly) ...[
                   // Si está inscrito, mostramos check, pero si está baneado mostramos alerta visual
                   Icon(Icons.check_circle, color: isBanned ? Colors.grey : Colors.green),
                   const SizedBox(width: 8),
                   IconButton(
                     icon: Icon(isBanned ? Icons.lock_open : Icons.block),
                     color: isBanned ? Colors.greenAccent : Colors.red,
                     tooltip: isBanned ? "Desbanear Usuario" : "Banear Usuario",
                     onPressed: () => _toggleBan(context, playerProvider, request.playerId, isBanned),
                   ),
                ] else ...[
                   IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Provider.of<GameRequestProvider>(context, listen: false).rejectRequest(request.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => Provider.of<GameRequestProvider>(context, listen: false).approveRequest(request.id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return AppTheme.primaryPurple;
  }


}