import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:io';

import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';

import '../widgets/shared/location_picker_widget.dart';
import '../../game/models/event.dart';
import '../../game/models/clue.dart'; // For PuzzleType
import '../../game/providers/event_provider.dart';
import '../providers/event_creation_provider.dart'; // NEW PROVIDER
import '../../../core/theme/app_theme.dart';
import '../widgets/qr_display_dialog.dart';
import '../widgets/store_edit_dialog.dart';
import '../../mall/providers/store_provider.dart';
import '../../mall/models/mall_store.dart';
import '../../mall/models/power_item.dart'; // NEW
import '../../../shared/widgets/loading_indicator.dart';

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
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // UX Refinement Variables (UI ONLY)
  late TextEditingController _pinController;
  // We keep pin locked state in UI as it is a UI behavior
  bool _isPinLocked = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController(text: widget.event?.pin ?? '');

    // Defer provider initialization to next frame to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<EventCreationProvider>(context, listen: false);
      provider.init(widget.event);
      // Sync controller if editing
      if (widget.event != null) {
        _pinController.text = widget.event!.pin;
      } else {
        // Warning: if provider has stale state from previous session?
        // provider.init handles reset if event is null.
        _pinController.text = provider.pin;
      }

      // Listen for form reset
      provider.addListener(_onProviderChange);
    });
  }

  void _onProviderChange() {
    final provider = Provider.of<EventCreationProvider>(context, listen: false);
    // Detect reset: if title is empty and we're not loading, reset UI state
    if (provider.title.isEmpty && !provider.isLoading && provider.pin.isEmpty) {
      _pinController.clear();
      _isPinLocked = false;
      // Force form rebuild with new key
      setState(() {
        _formKey = GlobalKey<FormState>();
      });
    }
  }

  @override
  void dispose() {
    // Remove listener
    try {
      final provider =
          Provider.of<EventCreationProvider>(context, listen: false);
      provider.removeListener(_onProviderChange);
    } catch (_) {}
    _pinController.dispose();
    super.dispose();
  }

  void _addPendingStore(EventCreationProvider provider) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StoreEditDialog(eventId: provider.eventId),
    );

    if (result != null) {
      provider.addPendingStore(result);
    }
  }

  Future<void> _submitForm(EventCreationProvider provider) async {
    // Save form fields
    _formKey.currentState?.save();

    // Provider already has data via onChanged, but we call submit logic
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    await provider.submitEvent(
      eventProvider: eventProvider,
      storeProvider: storeProvider,
      onSuccess: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $msg')),
        );
        widget.onEventCreated?.call();
      },
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventCreationProvider>(context);

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

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Form(
              key: _formKey,
              // onChanged: ... We don't need global onChanged as fields update provider directly
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Crear Nueva Competencia",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Configura los detalles del evento, ubicación y pistas.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                        color: const Color(0xFF161B33),
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
                        // --- Selección de Modo ---
                        const Text("Modalidad del Evento",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 15),

                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'on_site',
                                label: Text('📍 Presencial'),
                                icon: Icon(Icons.map),
                              ),
                              ButtonSegment<String>(
                                value: 'online',
                                label: Text('🌐 Online'),
                                icon: Icon(Icons.public),
                              ),
                            ],
                            selected: {provider.eventType},
                            onSelectionChanged: (Set<String> newSelection) {
                              provider.setEventType(newSelection.first);
                            },
                            style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.selected)) {
                                    return AppTheme.primaryPurple;
                                  }
                                  return Colors.transparent;
                                },
                              ),
                              foregroundColor:
                                  MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.white70;
                              }),
                              side: MaterialStateProperty.all(BorderSide(
                                  color: Colors.white.withOpacity(0.2))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Información Básica ---
                        const Text("Información Básica",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGold)),
                        const SizedBox(height: 20),

                        TextFormField(
                          initialValue: provider.title,
                          decoration: inputDecoration.copyWith(
                              labelText: 'Título del Evento',
                              hintText: 'Ej. Búsqueda del Tesoro Caracas'),
                          style: const TextStyle(color: Colors.white),
                          validator: (v) =>
                              v!.isEmpty ? 'Campo requerido' : null,
                          onChanged: (v) => provider.setTitle(v),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          initialValue: provider.description,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Descripción',
                            hintText: 'Detalles sobre la competencia...',
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          validator: (v) =>
                              v!.isEmpty ? 'Campo requerido' : null,
                          onChanged: (v) => provider.setDescription(v),
                        ),
                        const SizedBox(height: 20),

                        // --- Date & Time ---
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: provider.selectedDate,
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

                            if (pickedDate != null && context.mounted) {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                    provider.selectedDate),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      timePickerTheme: TimePickerThemeData(
                                        backgroundColor: AppTheme.cardBg,
                                        dialHandColor: AppTheme.primaryPurple,
                                        dialBackgroundColor: AppTheme.darkBg,
                                      ),
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppTheme.primaryPurple,
                                        surface: AppTheme.cardBg,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );

                              if (pickedTime != null) {
                                provider.setSelectedDate(DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                ));
                              }
                            }
                          },
                          child: InputDecorator(
                            decoration: inputDecoration.copyWith(
                                labelText: 'Fecha y Hora del Evento',
                                prefixIcon: const Icon(Icons.access_time,
                                    color: Colors.white54)),
                            child: Text(
                              "${provider.selectedDate.day}/${provider.selectedDate.month}/${provider.selectedDate.year}   ${provider.selectedDate.hour.toString().padLeft(2, '0')}:${provider.selectedDate.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Image Picker ---
                        InkWell(
                          onTap: () async {
                            final error = await provider.pickImage();
                            if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('⚠️ $error'),
                                  backgroundColor: Colors.orange.shade800,
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    style: BorderStyle.solid)),
                            child: Stack(
                              children: [
                                if (provider.selectedImage != null)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(
                                              provider.selectedImage!.path,
                                              fit: BoxFit.cover,
                                              opacity:
                                                  const AlwaysStoppedAnimation(
                                                      0.5),
                                            )
                                          : Image.file(
                                              File(
                                                  provider.selectedImage!.path),
                                              fit: BoxFit.cover,
                                              opacity:
                                                  const AlwaysStoppedAnimation(
                                                      0.5),
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                debugPrint(
                                                    "Error loading image: $error");
                                                return const Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.red));
                                              },
                                            ),
                                    ),
                                  ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        provider.selectedImage != null
                                            ? Icons.check_circle
                                            : Icons.add_photo_alternate,
                                        size: 40,
                                        color: provider.selectedImage != null
                                            ? AppTheme.accentGold
                                            : Colors.white54,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        provider.selectedImage != null
                                            ? "Imagen Seleccionada"
                                            : "Seleccionar Imagen de Portada",
                                        style: TextStyle(
                                            color:
                                                provider.selectedImage != null
                                                    ? Colors.white
                                                    : Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // --- Configuración del Juego ---
                        const Text("Configuración del Juego",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryPink)),
                        const SizedBox(height: 20),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Elements
                            // HIDING MAP COMPLETELY IF ONLINE as requested
                            final Widget locationWidget =
                                provider.eventType == 'online'
                                    ? const SizedBox.shrink()
                                    : LocationPickerWidget(
                                        initialPosition:
                                            provider.latitude != null &&
                                                    provider.longitude != null
                                                ? latlng.LatLng(
                                                    provider.latitude!,
                                                    provider.longitude!)
                                                : null,
                                        onLocationSelected: (picked, address) {
                                          provider.setLocation(picked.latitude,
                                              picked.longitude, address ?? '');
                                        },
                                      );

                            final Widget playersField = TextFormField(
                              initialValue: provider.maxParticipants == 0
                                  ? ''
                                  : provider.maxParticipants.toString(),
                              decoration: inputDecoration.copyWith(
                                  labelText: 'Max. Jugadores'),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                int? val = int.tryParse(v);
                                if (val == null) return 'Inválido';
                                if (val <= 0) return 'Mín 1';
                                if (val > 99) return 'Max 99';
                                return null;
                              },
                              onChanged: (v) {
                                if (v.isNotEmpty)
                                  provider
                                      .setMaxParticipants(int.tryParse(v) ?? 0);
                              },
                            );

                            final Widget bettingField = TextFormField(
                                  initialValue: provider.betTicketPrice.toString(),
                                  decoration: inputDecoration.copyWith(
                                    labelText: 'Precio Apuesta',
                                    suffixText: '🍀',
                                    helperText: 'Default: 100',
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) {
                                      if (v == null || v.isEmpty) return 'Requerido';
                                      return null;
                                  },
                                  onChanged: (v) {
                                    if (v.isNotEmpty) provider.setBetTicketPrice(int.tryParse(v) ?? 100);
                                  },
                                );

                            final Widget entryFeeField = TextFormField(
                                      initialValue: provider.entryFee?.toString() ?? '',
                                      decoration: inputDecoration.copyWith(
                                        labelText: 'Precio Entrada',
                                        suffixText: '🍀',
                                        helperText: '0 para GRATIS',
                                      ),
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Requerido';
                                        return null;
                                      },
                                      onChanged: (v) {
                                        provider.setEntryFee(v.isEmpty ? null : (int.tryParse(v)));
                                      },
                                    );

                            if (provider.eventType == 'online') {
                                // If Online, show Players field AND Price fields (no location)
                                return Column(
                                  children: [
                                    playersField,
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(child: entryFeeField),
                                        const SizedBox(width: 20),
                                        Expanded(child: bettingField),
                                      ],
                                    ),
                                  ],
                                );
                            }

                            if (constraints.maxWidth < 600) {
                              // Column Widget
                              return Column(
                                children: [
                                  SizedBox(
                                      width: double.infinity,
                                      child: locationWidget),
                                  const SizedBox(height: 20),
                                  playersField,
                                  const SizedBox(height: 20),
                                  entryFeeField,
                                  const SizedBox(height: 20),
                                  bettingField,
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 2, child: locationWidget),
                                      const SizedBox(width: 20),
                                      Expanded(child: playersField), 
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(child: entryFeeField),
                                      const SizedBox(width: 20),
                                      Expanded(child: bettingField),
                                    ],
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Configuración de Ganadores ---
                        const Text("Configuración de Premios",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events,
                                      color: AppTheme.accentGold),
                                  const SizedBox(width: 10),
                                  const Text("Cantidad de Ganadores:",
                                      style: TextStyle(color: Colors.white)),
                                  const Spacer(),
                                  SegmentedButton<int>(
                                    segments: const [
                                      ButtonSegment<int>(
                                          value: 1, label: Text("1")),
                                      ButtonSegment<int>(
                                          value: 2, label: Text("2")),
                                      ButtonSegment<int>(
                                          value: 3, label: Text("3")),
                                    ],
                                    selected: {provider.configuredWinners},
                                    onSelectionChanged:
                                        (Set<int> newSelection) {
                                      provider.setConfiguredWinners(
                                          newSelection.first);
                                    },
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty
                                          .resolveWith<Color>(
                                        (Set<MaterialState> states) {
                                          if (states.contains(
                                              MaterialState.selected)) {
                                            return AppTheme.accentGold;
                                          }
                                          return Colors.transparent;
                                        },
                                      ),
                                      foregroundColor: MaterialStateProperty
                                          .resolveWith<Color>(
                                              (Set<MaterialState> states) {
                                        if (states
                                            .contains(MaterialState.selected)) {
                                          return Colors.black;
                                        }
                                        return Colors.white;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Builder(builder: (context) {
                                int rec = 1;
                                if (provider.maxParticipants <= 5)
                                  rec = 1;
                                else if (provider.maxParticipants <= 10)
                                  rec = 2;
                                else
                                  rec = 3;

                                return Text(
                                  "💡 Recomendación: $rec ganador${rec > 1 ? 'es' : ''} para ${provider.maxParticipants} jugadores.",
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            // PIN + Clue Row/Column
                            final pinWidget = Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _pinController,
                                    readOnly: _isPinLocked,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: inputDecoration.copyWith(
                                      labelText: 'PIN de Acceso',
                                      prefixIcon: const Icon(Icons.lock_outline,
                                          color: Colors.white54),
                                      suffixIcon: _isPinLocked
                                          ? Icon(Icons.lock,
                                              color: AppTheme.accentGold,
                                              size: 16)
                                          : null,
                                      hintText: '123456',
                                    ),
                                    style: TextStyle(
                                        color: _isPinLocked
                                            ? Colors.grey
                                            : Colors.white),
                                    validator: (v) {
                                      if (provider.eventType == 'online')
                                        return null; // No validation in UI if hidden, although logic skips it too
                                      if (v == null || v.isEmpty)
                                        return 'Requerido';
                                      if (v.length != 6) return '6 dígitos';
                                      return null;
                                    },
                                    onChanged: (v) => provider.setPin(v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppTheme.accentGold
                                            .withOpacity(0.3)),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.qr_code,
                                        color: AppTheme.accentGold),
                                    tooltip: "Generar QR",
                                    onPressed: () {
                                      provider.generateRandomPin();
                                      setState(() {
                                        _pinController.text = provider.pin;
                                        _isPinLocked = true;
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'PIN generado: ${provider.pin}')),
                                      );
                                      _showQRDialog(
                                          "EVENT:${provider.eventId}:${provider.pin}",
                                          "PIN: ${provider.pin}");
                                    },
                                  ),
                                ),
                              ],
                            );

                            final clueWidget = TextFormField(
                              initialValue: provider.clue,
                              decoration: inputDecoration.copyWith(
                                  labelText: 'Pista Inicial',
                                  prefixIcon: const Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.white54)),
                              style: const TextStyle(color: Colors.white),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                              onChanged: (v) => provider.setClue(v),
                            );

                            // If Online, hide PIN AND Initial Clue (managed automatically)
                            if (provider.eventType == 'online') {
                              return const SizedBox.shrink();
                            }

                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  pinWidget,
                                  const SizedBox(height: 20),
                                  clueWidget,
                                ],
                              );
                            } else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: pinWidget),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 2, child: clueWidget),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 40),

                        // --- Generador de Pistas / Minijuegos ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  provider.eventType == 'online'
                                      ? "Generador de Minijuegos"
                                      : "Generador de Pistas",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (MediaQuery.of(context).size.width >= 400)
                                    const Spacer(),
                                  if (MediaQuery.of(context).size.width < 400)
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            provider.numberOfClues.toString(),
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(2)
                                        ],
                                        decoration: inputDecoration.copyWith(
                                            contentPadding:
                                                const EdgeInsets.all(10),
                                            isDense: true,
                                            hintText: 'Max 12'),
                                        style: const TextStyle(
                                            color: Colors.white),
                                        onChanged: (v) =>
                                            provider.setNumberOfClues(
                                                int.tryParse(v) ?? 0),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue:
                                            provider.numberOfClues.toString(),
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(2)
                                        ],
                                        decoration: inputDecoration.copyWith(
                                            contentPadding:
                                                const EdgeInsets.all(10),
                                            isDense: true,
                                            hintText: 'Max 12'),
                                        style: const TextStyle(
                                            color: Colors.white),
                                        onChanged: (v) =>
                                            provider.setNumberOfClues(
                                                int.tryParse(v) ?? 0),
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () =>
                                        provider.generateClueForms(),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentGold,
                                        foregroundColor: Colors.black),
                                    child: const Text("Generar"),
                                  ),
                                ],
                              ),
                              if (provider.clueForms.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: provider.currentClueIndex > 0
                                          ? provider.prevClue
                                          : null,
                                      icon: const Icon(Icons.arrow_back_ios,
                                          color: Colors.white),
                                    ),
                                    Text(
                                      "${provider.eventType == 'online' ? 'Minijuego' : 'Pista'} ${provider.currentClueIndex + 1} de ${provider.clueForms.length}",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      onPressed: provider.currentClueIndex <
                                              provider.clueForms.length - 1
                                          ? provider.nextClue
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
                                    key: ValueKey<int>(
                                        provider.currentClueIndex),
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Column(
                                      children: [
                                        // Dropdown Type
                                        DropdownButtonFormField<String>(
                                          value: provider.clueForms[
                                                      provider.currentClueIndex]
                                                  ['puzzle_type'] ??
                                              PuzzleType.slidingPuzzle.dbValue,
                                          isExpanded: true,
                                          decoration: inputDecoration.copyWith(
                                              labelText: 'Tipo de Desafío',
                                              prefixIcon: const Icon(
                                                  Icons.games,
                                                  color: Colors.white54)),
                                          dropdownColor:
                                              const Color(0xFF2A2D3E),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          items: PuzzleType.values
                                              .map((type) => DropdownMenuItem(
                                                  value: type.dbValue,
                                                  child: Text(type.label,
                                                      overflow: TextOverflow
                                                          .ellipsis)))
                                              .toList(),
                                          onChanged: (v) =>
                                              provider.setCluePuzzleType(
                                                  provider.currentClueIndex,
                                                  v!),
                                        ),
                                        const SizedBox(height: 15),

                                        // Title + QR
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue:
                                                    provider.clueForms[provider
                                                            .currentClueIndex]
                                                        ['title'],
                                                decoration:
                                                    inputDecoration.copyWith(
                                                        labelText: 'Título'),
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                onChanged: (v) =>
                                                    provider.updateClue(
                                                        provider
                                                            .currentClueIndex,
                                                        'title',
                                                        v),
                                              ),
                                            ),
                                            if (provider.eventType ==
                                                'on_site') ...[
                                              const SizedBox(width: 10),
                                              Container(
                                                decoration: BoxDecoration(
                                                    color: AppTheme.accentGold,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.qr_code_2,
                                                      color: Colors.black),
                                                  onPressed: () {
                                                    final clueId = provider
                                                                .clueForms[
                                                            provider
                                                                .currentClueIndex]
                                                        ['id'];
                                                    _showQRDialog(
                                                        "CLUE:${provider.eventId}:$clueId",
                                                        "QR Pista");
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Description field for BOTH modes (online minigames also need instructions)
                                        TextFormField(
                                          initialValue: provider.clueForms[
                                                  provider.currentClueIndex]
                                              ['description'],
                                          decoration: inputDecoration.copyWith(
                                            labelText: provider.eventType ==
                                                    'online'
                                                ? 'Instrucciones del Minijuego'
                                                : 'Instrucciones / Historia',
                                          ),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) => provider.updateClue(
                                              provider.currentClueIndex,
                                              'description',
                                              v),
                                        ),
                                        const SizedBox(height: 10),

                                        // Question
                                        TextFormField(
                                          key: ValueKey(
                                              'q_${provider.clueForms[provider.currentClueIndex]['puzzle_type']}'),
                                          initialValue: provider.clueForms[
                                                  provider.currentClueIndex]
                                              ['riddle_question'],
                                          decoration: inputDecoration.copyWith(
                                            labelText: provider.clueForms[provider
                                                            .currentClueIndex]
                                                        ['puzzle_type'] ==
                                                    'hangman'
                                                ? 'Pista de la Palabra'
                                                : 'Instrucción',
                                          ),
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) => provider.updateClue(
                                              provider.currentClueIndex,
                                              'riddle_question',
                                              v),
                                        ),

                                        if (provider.clueForms[
                                                    provider.currentClueIndex]
                                                ['puzzle_type'] ==
                                            'hangman') ...[
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            key: ValueKey(
                                                'a_${provider.clueForms[provider.currentClueIndex]['puzzle_type']}'),
                                            initialValue: provider.clueForms[
                                                    provider.currentClueIndex]
                                                ['riddle_answer'],
                                            decoration:
                                                inputDecoration.copyWith(
                                                    labelText:
                                                        'Palabra a Adivinar',
                                                    helperText: 'Sin espacios'),
                                            style: const TextStyle(
                                                color: Colors.white),
                                            onChanged: (v) =>
                                                provider.updateClue(
                                                    provider.currentClueIndex,
                                                    'riddle_answer',
                                                    v),
                                          ),
                                        ],
                                        const SizedBox(height: 10),

                                        // Rewards (Coins are now calculated dynamically by server)
                                        TextFormField(
                                          initialValue: provider.clueForms[
                                                  provider.currentClueIndex]
                                                  ['xp_reward']
                                              .toString(),
                                          decoration: inputDecoration.copyWith(
                                              labelText: 'XP por Completar'),
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (v) => provider.updateClue(
                                              provider.currentClueIndex,
                                              'xp_reward',
                                              int.tryParse(v) ?? 0),
                                        ),
                                        const SizedBox(height: 10),

                                        // Geolocation for Clue (Only if On Site)
                                        if (provider.eventType ==
                                            'on_site') ...[
                                          const Text("📍 Geolocalización",
                                              style: TextStyle(
                                                  color: AppTheme.accentGold,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            initialValue: provider.clueForms[
                                                    provider.currentClueIndex]
                                                ['hint'],
                                            decoration:
                                                inputDecoration.copyWith(
                                                    labelText:
                                                        'Pista de Ubicación QR',
                                                    prefixIcon: const Icon(
                                                        Icons.location_on,
                                                        color: Colors.white54)),
                                            style: const TextStyle(
                                                color: Colors.white),
                                            onChanged: (v) =>
                                                provider.updateClue(
                                                    provider.currentClueIndex,
                                                    'hint',
                                                    v),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: TextFormField(
                                                key: ValueKey(
                                                    'lat_${provider.clueForms[provider.currentClueIndex]['latitude']}'),
                                                initialValue: provider
                                                        .clueForms[provider
                                                                .currentClueIndex]
                                                            ['latitude']
                                                        ?.toString() ??
                                                    '',
                                                decoration:
                                                    inputDecoration.copyWith(
                                                        labelText: 'Latitud'),
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                onChanged: (v) =>
                                                    provider.updateClue(
                                                        provider
                                                            .currentClueIndex,
                                                        'latitude',
                                                        double.tryParse(v)),
                                              )),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: TextFormField(
                                                key: ValueKey(
                                                    'long_${provider.clueForms[provider.currentClueIndex]['longitude']}'),
                                                initialValue: provider
                                                        .clueForms[provider
                                                                .currentClueIndex]
                                                            ['longitude']
                                                        ?.toString() ??
                                                    '',
                                                decoration:
                                                    inputDecoration.copyWith(
                                                        labelText: 'Longitud'),
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                onChanged: (v) =>
                                                    provider.updateClue(
                                                        provider
                                                            .currentClueIndex,
                                                        'longitude',
                                                        double.tryParse(v)),
                                              )),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            alignment:
                                                WrapAlignment.spaceEvenly,
                                            spacing: 10,
                                            runSpacing: 5,
                                            children: [
                                              TextButton.icon(
                                                  icon: const Icon(Icons.store,
                                                      size: 16),
                                                  label:
                                                      const Text("Usar Evento"),
                                                  onPressed: () => provider
                                                      .setEventLocationForClue(
                                                          provider
                                                              .currentClueIndex)),
                                              TextButton.icon(
                                                  icon: const Icon(
                                                      Icons.my_location,
                                                      size: 16),
                                                  label: const Text(
                                                      "Mi Ubicación"),
                                                  onPressed: () async {
                                                    try {
                                                      final pos = await Geolocator
                                                          .getCurrentPosition();
                                                      provider.setMyLocationForClue(
                                                          provider
                                                              .currentClueIndex,
                                                          pos.latitude,
                                                          pos.longitude);
                                                    } catch (e) {/* ignore */}
                                                  }),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Tiendas --- (Hidden if Online)
                        if (provider.eventType == 'on_site') ...[
                          const Text("Tiendas Aliadas",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentGold)),
                          const SizedBox(height: 20),
                          if (provider.pendingStores.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10)),
                              child: const Center(
                                  child: Column(children: [
                                Icon(Icons.store_mall_directory_outlined,
                                    size: 40, color: Colors.white24),
                                SizedBox(height: 10),
                                Text("No hay tiendas agregadas",
                                    style: TextStyle(color: Colors.white54))
                              ])),
                            ),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.pendingStores.length,
                            itemBuilder: (context, index) {
                              final store = provider.pendingStores[index]
                                  ['store'] as MallStore;
                              return Card(
                                color: AppTheme.cardBg,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: const Icon(Icons.store,
                                      color: AppTheme.accentGold),
                                  title: Text(store.name,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  subtitle: Text(
                                      "${store.products.length} productos",
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          provider.removePendingStore(index)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _addPendingStore(provider),
                              icon: const Icon(Icons.add),
                              label: const Text("Agregar Tienda"),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentGold,
                                  side: const BorderSide(
                                      color: AppTheme.accentGold),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15)),
                            ),
                          ),
                          const SizedBox(height: 30),
                          // --- Configuración de Precios para Espectadores (ALWAYS VISIBLE) ---
                          const Text("Precios para Espectadores",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentGold)),
                          const SizedBox(height: 10),
                          const Text(
                              "Personaliza el costo de los poderes para los espectadores en este evento.",
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 20),

                          LayoutBuilder(builder: (context, constraints) {
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    constraints.maxWidth < 600 ? 1 : 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: constraints.maxWidth < 600
                                    ? 4
                                    : 3, // Taller items on mobile
                              ),
                              itemCount: PowerItem.getShopItems().length,
                              itemBuilder: (context, index) {
                                final power = PowerItem.getShopItems()[index];
                                final currentPrice =
                                    provider.spectatorPrices[power.id] ??
                                        power.cost;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        height: 48,
                                        width: 48,
                                        decoration: BoxDecoration(
                                          color: power.color.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(power.icon,
                                            style:
                                                const TextStyle(fontSize: 24)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(power.name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text("${power.cost} Default",
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          initialValue: currentPrice.toString(),
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration: inputDecoration.copyWith(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 5),
                                            isDense: true,
                                            suffixText: '',
                                          ),
                                          style: const TextStyle(
                                              color: AppTheme.accentGold,
                                              fontWeight: FontWeight.bold),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          onChanged: (v) {
                                            final val = int.tryParse(v);
                                            if (val != null) {
                                              provider.setSpectatorPrice(
                                                  power.id, val);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 30),
                        ],

                        // --- Submit Button ---
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                (provider.isFormValid && !provider.isLoading)
                                    ? () => _submitForm(provider)
                                    : null,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                disabledBackgroundColor:
                                    const Color(0xFF2A2D3E),
                                disabledForegroundColor: Colors.white30,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: provider.isLoading
                                ? const LoadingIndicator(
                                    fontSize: 14, color: Colors.white)
                                : const Text("PUBLICAR",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                          ),
                        ),
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
}
