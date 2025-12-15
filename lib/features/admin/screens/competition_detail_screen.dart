import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../game/models/event.dart';
import '../../game/models/clue.dart';
import '../../game/providers/event_provider.dart';
import '../../game/providers/game_request_provider.dart';
import '../../game/models/game_request.dart';
import '../../../core/theme/app_theme.dart';

class CompetitionDetailScreen extends StatefulWidget {
  final GameEvent event;

  const CompetitionDetailScreen({super.key, required this.event});

  @override
  State<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form State
  late String _title;
  late String _description;
  late String _locationName;
  late double _latitude;
  late double _longitude;
  late String _clue;
  late String _pin;
  late int _maxParticipants;
  late DateTime _selectedDate;
  
  XFile? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); 
    
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB
    });

    // Initialize form data
    _title = widget.event.title;
    _description = widget.event.description;
    _locationName = widget.event.locationName;
    _latitude = widget.event.latitude;
    _longitude = widget.event.longitude;
    _clue = widget.event.clue;
    _pin = widget.event.pin;
    _maxParticipants = widget.event.maxParticipants;
    _selectedDate = widget.event.date;

    // Load requests for this event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameRequestProvider>(context, listen: false).fetchAllRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: Text(widget.event.title),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          tabs: const [
            Tab(text: "Detalles"),
            Tab(text: "Participantes"),
            Tab(text: "Pistas de Juego"),
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
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2 
        ? FloatingActionButton(
            backgroundColor: AppTheme.primaryPurple,
            onPressed: () => _showAddClueDialog(),
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
    );
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
             TextFormField(
              initialValue: _locationName,
              style: const TextStyle(color: Colors.white),
              decoration: inputDecoration.copyWith(labelText: 'Nombre de Ubicación'),
              onSaved: (v) => _locationName = v!,
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
        // Filter requests for THIS event
        final allRequests = provider.requests.where((r) => r.eventId == widget.event.id).toList();
        
        final approved = allRequests.where((r) => r.isApproved).toList();
        final pending = allRequests.where((r) => r.isPending).toList();

        if (allRequests.isEmpty) {
          return const Center(child: Text("No hay participantes ni solicitudes.", style: TextStyle(color: Colors.white54)));
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              const Text("Solicitudes Pendientes", style: TextStyle(color: AppTheme.secondaryPink, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...pending.map((req) => _RequestTile(request: req)),
              const SizedBox(height: 20),
            ],
            
            const Text("Participantes Inscritos", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (approved.isEmpty)
              const Text("Nadie inscrito aún.", style: TextStyle(color: Colors.white30))
            else
              ...approved.map((req) => _RequestTile(request: req, isReadOnly: true)),
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
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.accentGold),
                  onPressed: () => _showEditClueDialog(clue),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditClueDialog(Clue clue) {
    String title = clue.title;
    String description = clue.description;
    String question = clue.riddleQuestion ?? '';
    String answer = clue.riddleAnswer ?? '';
    PuzzleType selectedType = clue.puzzleType;
    int xp = clue.xpReward;

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
                    decoration: InputDecoration(
                      labelText: 'Tipo de Minijuego',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: PuzzleType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                         setStateDialog(() {
                           selectedType = val;
                           // Set default question if switching types
                           if (question.isEmpty) question = val.defaultQuestion;
                         });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: title,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Título', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: question,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Pregunta / Instrucción', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => question = v,
                  ),
                  const SizedBox(height: 10),
                  if (!selectedType.isAutoValidation)
                    TextFormField(
                      initialValue: answer,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Respuesta Correcta', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (v) => answer = v,
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: xp.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Puntos XP', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => xp = int.tryParse(v) ?? 50,
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
                // Create updated clue object
                final updatedClue = Clue(
                  id: clue.id,
                  title: title,
                  description: description, // Keep original or add field if needed
                  hint: clue.hint,
                  type: clue.type,
                  latitude: clue.latitude,
                  longitude: clue.longitude,
                  qrCode: clue.qrCode,
                  minigameUrl: clue.minigameUrl,
                  xpReward: xp,
                  coinReward: clue.coinReward,
                  puzzleType: selectedType,
                  riddleQuestion: question,
                  riddleAnswer: answer,
                  isLocked: clue.isLocked,
                  isCompleted: clue.isCompleted
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


  void _showAddClueDialog() {
    // Default values for new clue
    String title = '';
    String description = '';
    String question = '';
    String answer = '';
    PuzzleType selectedType = PuzzleType.riddle;
    int xp = 50;

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
                    decoration: InputDecoration(
                      labelText: 'Tipo de Minijuego',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: PuzzleType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                         setStateDialog(() {
                           selectedType = val;
                           // Set default question
                           if (question.isEmpty) question = val.defaultQuestion;
                         });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Título', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => title = v,
                  ),
                  const SizedBox(height: 10),
                   TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Descripción / Historia', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => description = v,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: question,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Pregunta / Instrucción', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => question = v,
                  ),
                  const SizedBox(height: 10),
                  if (!selectedType.isAutoValidation)
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Respuesta Correcta', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (v) => answer = v,
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: xp.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Puntos XP', labelStyle: TextStyle(color: Colors.white70)),
                    onChanged: (v) => xp = int.tryParse(v) ?? 50,
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
                if (title.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El título es requerido')));
                   return;
                }
                
                // Create new clue object
                final newClue = Clue(
                  id: '', // Will be generated by DB
                  title: title,
                  description: description,
                  hint: '',
                  type: ClueType.minigame, // Default to minigame
                  xpReward: xp,
                  coinReward: 10,
                  puzzleType: selectedType,
                  riddleQuestion: question,
                  riddleAnswer: answer,
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
}

class _RequestTile extends StatelessWidget {
  final GameRequest request;
  final bool isReadOnly;

  const _RequestTile({required this.request, this.isReadOnly = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(request.playerName ?? 'Desconocido', style: const TextStyle(color: Colors.white)),
        subtitle: Text(request.playerEmail ?? 'No email', style: const TextStyle(color: Colors.white54)),
        trailing: isReadOnly
            ? const Icon(Icons.check_circle, color: Colors.green)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Provider.of<GameRequestProvider>(context, listen: false).rejectRequest(request.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => Provider.of<GameRequestProvider>(context, listen: false).approveRequest(request.id),
                  ),
                ],
              ),
      ),
    );
  }
}
