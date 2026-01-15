import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/clue.dart';
import '../../game/providers/event_provider.dart';

class ClueFormDialog extends StatefulWidget {
  final Clue? clue; // Si es null, es modo creación
  final String eventId;
  final double? eventLatitude;
  final double? eventLongitude;

  const ClueFormDialog({
    super.key,
    this.clue,
    required this.eventId,
    this.eventLatitude,
    this.eventLongitude,
  });

  @override
  State<ClueFormDialog> createState() => _ClueFormDialogState();
}

class _ClueFormDialogState extends State<ClueFormDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _questionController;
  late TextEditingController _answerController;
  late TextEditingController _xpController;
  late TextEditingController _coinController;
  late TextEditingController _hintController;
  late TextEditingController _latController;
  late TextEditingController _longController;

  PuzzleType _selectedType = PuzzleType.slidingPuzzle;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final c = widget.clue;
    _titleController = TextEditingController(text: c?.title ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _questionController = TextEditingController(text: c?.riddleQuestion ?? '');
    _answerController = TextEditingController(text: c?.riddleAnswer ?? '');
    _xpController = TextEditingController(text: c?.xpReward.toString() ?? '50');
    _coinController = TextEditingController(text: c?.coinReward.toString() ?? '10');
    _hintController = TextEditingController(text: c?.hint ?? '');
    _latController = TextEditingController(text: c?.latitude?.toString() ?? '');
    _longController = TextEditingController(text: c?.longitude?.toString() ?? '');

    if (c != null) {
      _selectedType = c.puzzleType;
      _latitude = c.latitude;
      _longitude = c.longitude;
    } else {
      // Valor por defecto para pregunta al crear
      _questionController.text = _selectedType.defaultQuestion;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _xpController.dispose();
    _coinController.dispose();
    _hintController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.primaryPurple) : null,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.primaryPurple),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
    );
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Eliminar Pista', style: TextStyle(color: Colors.white)),
        content: const Text(
            '¿Estás seguro de que quieres eliminar esta pista? Esta acción no se puede deshacer.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Provider.of<EventProvider>(context, listen: false)
            .deleteClue(widget.clue!.id);
        if (mounted) {
          Navigator.pop(context, true); // Retorna true para indicar cambio
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pista eliminada')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _handleSave() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El título es requerido')));
      return;
    }

    try {
      final isEdit = widget.clue != null;
      final newClue = Clue(
        id: isEdit ? widget.clue!.id : '', // En create, ID generado por DB
        title: _titleController.text,
        description: _descriptionController.text,
        hint: _hintController.text,
        type: isEdit ? widget.clue!.type : ClueType.minigame,
        latitude: _latitude,
        longitude: _longitude,
        qrCode: isEdit ? widget.clue!.qrCode : null,
        minigameUrl: isEdit ? widget.clue!.minigameUrl : null,
        xpReward: int.tryParse(_xpController.text) ?? 50,
        coinReward: int.tryParse(_coinController.text) ?? 10,
        puzzleType: _selectedType,
        riddleQuestion: _questionController.text,
        riddleAnswer: _answerController.text,
        isLocked: isEdit ? widget.clue!.isLocked : true,
        isCompleted: isEdit ? widget.clue!.isCompleted : false,
        sequenceIndex: isEdit ? widget.clue!.sequenceIndex : 0,
      );

      final provider = Provider.of<EventProvider>(context, listen: false);
      if (isEdit) {
        await provider.updateClue(newClue);
      } else {
        await provider.addClue(widget.eventId, newClue);
      }

      if (mounted) {
        Navigator.pop(context, true); // Retorna true para indicar éxito
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Pista actualizada' : 'Pista agregada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("GPS desactivado");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permiso denegado");
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _latController.text = _latitude.toString();
        _longController.text = _longitude.toString();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _useEventLocation() {
    if (widget.eventLatitude != null && widget.eventLongitude != null) {
      setState(() {
        _latitude = widget.eventLatitude;
        _longitude = widget.eventLongitude;
        _latController.text = _latitude.toString();
        _longController.text = _longitude.toString();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El evento no tiene ubicación definida")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.clue != null;

    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(isEdit ? "Editar Pista / Minijuego" : "Agregar Nueva Pista",
          style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<PuzzleType>(
              value: _selectedType,
              dropdownColor: AppTheme.darkBg,
              isExpanded: true,
              decoration:
                  _buildInputDecoration('Tipo de Minijuego', icon: Icons.games),
              style: const TextStyle(color: Colors.white),
              items: PuzzleType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    type.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                    if (_questionController.text.isEmpty) {
                      _questionController.text = val.defaultQuestion;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Título'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Descripción / Historia'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _questionController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Pregunta / Instrucción'),
            ),
            const SizedBox(height: 10),
            if (!_selectedType.isAutoValidation)
              TextFormField(
                controller: _answerController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Respuesta Correcta'),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _xpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Puntos XP'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _coinController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Monedas'),
            ),
            const SizedBox(height: 20),
            const Text("📍 Geolocalización (Opcional)",
                style: TextStyle(
                    color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _hintController,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration(
                  'Pista de Ubicación QR (ej: Detrás del árbol)',
                  icon: Icons.location_on),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Latitud'),
                    onChanged: (v) => _latitude = double.tryParse(v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _longController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Longitud'),
                    onChanged: (v) => _longitude = double.tryParse(v),
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
                  label:
                      const Text("Usar Evento", style: TextStyle(fontSize: 12)),
                  onPressed: _useEventLocation,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text("Mi Ubicación",
                      style: TextStyle(fontSize: 12)),
                  onPressed: _useCurrentLocation,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            onPressed: _handleDelete,
            child: const Text("Eliminar",
                style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple),
          onPressed: _handleSave,
          child: Text(isEdit ? "Guardar" : "Agregar",
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
