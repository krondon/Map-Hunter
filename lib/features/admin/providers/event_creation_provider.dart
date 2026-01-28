import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../game/models/event.dart';
import '../../game/models/clue.dart'; // For PuzzleType enum
import '../../game/providers/event_provider.dart';
import '../../mall/providers/store_provider.dart';
import '../../mall/models/mall_store.dart';
import '../services/event_factory_service.dart';


class EventCreationProvider extends ChangeNotifier {
  // Estado del Formulario
  String _title = '';
  String _description = '';
  String? _locationName;
  double? _latitude;
  double? _longitude;
  String _clue = '';
  String _pin = '';
  int _maxParticipants = 0;
    DateTime _selectedDate = DateTime.now();
  String _eventType = 'on_site'; // 'on_site' or 'online'

  // Imágenes
  XFile? _selectedImage;
  
  // Pistas
  int _numberOfClues = 0;
  List<Map<String, dynamic>> _clueForms = [];
  int _currentClueIndex = 0;

  // Tiendas
  List<Map<String, dynamic>> _pendingStores = [];

  // Control
  bool _isLoading = false;
  String _eventId = const Uuid().v4();
  bool _isFormValid = false;
  
  // Getters
  String get title => _title;
  String get description => _description;
  String? get locationName => _locationName;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get clue => _clue;
  String get pin => _pin;
  int get maxParticipants => _maxParticipants;
  DateTime get selectedDate => _selectedDate;
  XFile? get selectedImage => _selectedImage;
  int get numberOfClues => _numberOfClues;
  List<Map<String, dynamic>> get clueForms => _clueForms;
  int get currentClueIndex => _currentClueIndex;
  List<Map<String, dynamic>> get pendingStores => _pendingStores;
  bool get isLoading => _isLoading;
  String get eventId => _eventId;
  bool get isFormValid => _isFormValid;
  String get eventType => _eventType;

  // --- Initializers ---
  
  void init(GameEvent? event) {
    if (event != null) {
      _eventId = event.id;
      _title = event.title;
      _description = event.description;
      _locationName = event.locationName;
      _latitude = event.latitude;
      _longitude = event.longitude;
      _clue = event.clue;
      _pin = event.pin;
      _maxParticipants = event.maxParticipants;
      _selectedDate = event.date;
      _eventType = event.type;
      // Note: Image and Clues are not fully loaded here in original code either
    } else {
      resetForm();
    }
    checkFormValidity();
  }

  void resetForm() {
    _title = '';
    _description = '';
    _locationName = null;
    _latitude = null;
    _longitude = null;
    _clue = '';
    _pin = '';
    _maxParticipants = 0;
    _selectedDate = DateTime.now();
    _selectedImage = null;
    _numberOfClues = 0;
    _clueForms = [];
    _currentClueIndex = 0;
    _pendingStores = [];
    _isLoading = false;
    _eventId = const Uuid().v4();
    _isFormValid = false;
    _eventType = 'on_site';
    notifyListeners();
  }

  // --- Setters & Logic ---

  void setEventType(String value) {
    _eventType = value;
    checkFormValidity();
    notifyListeners();
  }

  void setTitle(String value) { _title = value; checkFormValidity(); }
  void setDescription(String value) { _description = value; checkFormValidity(); }
  void setLocation(double lat, double lng, String address) {
    _latitude = lat;
    _longitude = lng;
    _locationName = address;
    checkFormValidity();
    notifyListeners(); // Notify because UI might show map/address
  }
  
  void setClue(String value) { _clue = value; checkFormValidity(); }
  void setPin(String value) { 
    _pin = value; 
    checkFormValidity(); 
    // No notify needed if controlled by text controller, but validity updates
  }
  
  void generateRandomPin() {
    _pin = EventFactoryService.generatePin(isOnline: _eventType == 'online');
    checkFormValidity();
    notifyListeners();
  }

  void setMaxParticipants(int value) { 
    _maxParticipants = value; 
    checkFormValidity(); 
  }
  
  void setNumberOfClues(int value) {
    if (value > 12) value = 12;
    if (value < 0) value = 0;
    _numberOfClues = value;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Platform-aware image picker:
  /// - Windows/Linux/macOS: Uses file_picker (more reliable on desktop)
  /// - Mobile/Web: Uses image_picker
  Future<void> pickImage() async {
    try {
      // Check if running on desktop
      final isDesktop = !kIsWeb && 
          (defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux ||
           defaultTargetPlatform == TargetPlatform.macOS);
      
      if (isDesktop) {
        // Use file_picker on desktop for better compatibility
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.path != null) {
            _selectedImage = XFile(file.path!);
            checkFormValidity();
            notifyListeners();
          }
        }
      } else {
        // Use image_picker on mobile
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          _selectedImage = image;
          checkFormValidity();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      // Fallback: try file_picker as last resort
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
          _selectedImage = XFile(result.files.first.path!);
          checkFormValidity();
          notifyListeners();
        }
      } catch (fallbackError) {
        debugPrint('Fallback image picker also failed: $fallbackError');
      }
    }
  }

  // --- Clues Logic ---

  void generateClueForms() {
    if (_numberOfClues > 0) {
      _currentClueIndex = 0;
      if (_clueForms.length < _numberOfClues) {
        final newItems = _numberOfClues - _clueForms.length;
        for (int i = 0; i < newItems; i++) {
          final defaultPuzzleType = PuzzleType.slidingPuzzle;
          _clueForms.add({
            'id': const Uuid().v4(),
            'title': _eventType == 'online' ? 'Minijuego ${_clueForms.length + 1}' : 'Pista ${_clueForms.length + 1}',
            'description': '',
            'type': 'minigame',
            'puzzle_type': defaultPuzzleType.dbValue,
            'riddle_question': defaultPuzzleType.defaultQuestion, // Set default instruction
            'riddle_answer': defaultPuzzleType.isAutoValidation ? 'WIN' : '',
            'xp_reward': 50,
            'coin_reward': 10,
            'hint': '',
            'latitude': null,
            'longitude': null,
          });
        }
      } else {
         // Trim if reduced
         _clueForms = _clueForms.sublist(0, _numberOfClues);
      }
    } else {
      _clueForms = [];
    }
    notifyListeners();
  }

  void updateClue(int index, String key, dynamic value) {
    if (index >= 0 && index < _clueForms.length) {
      _clueForms[index][key] = value;
      // Note: deep update, might not need full notify if we bind fields to this map directly
      // But safe to notify for UI consistency or validation
      // notifyListeners(); - Skipping to avoid cursor issues if fields bind directly, 
      // but UI loop uses _clueForms[index]. 
    }
  }

  void setCluePuzzleType(int index, String typeValue) {
      if (index < 0 || index >= _clueForms.length) return;
      
      _clueForms[index]['puzzle_type'] = typeValue;
      _clueForms[index]['type'] = 'minigame';

      final selectedType = PuzzleType.values.firstWhere(
        (e) => e.dbValue == typeValue, 
        orElse: () => PuzzleType.slidingPuzzle
      );

      if (selectedType.isAutoValidation) {
        _clueForms[index]['riddle_answer'] = 'WIN'; 
      } else if (selectedType == PuzzleType.hangman) {
        _clueForms[index]['riddle_answer'] = ''; 
      } else {
        _clueForms[index]['riddle_answer'] = '';
      }

      _clueForms[index]['riddle_question'] = selectedType.defaultQuestion;
      notifyListeners();
  }

  void nextClue() {
    if (_currentClueIndex < _clueForms.length - 1) {
      _currentClueIndex++;
      notifyListeners();
    }
  }

  void prevClue() {
    if (_currentClueIndex > 0) {
      _currentClueIndex--;
      notifyListeners();
    }
  }
  
  void setMyLocationForClue(int index, double lat, double lng) {
      if (index >= 0 && index < _clueForms.length) {
          _clueForms[index]['latitude'] = lat;
          _clueForms[index]['longitude'] = lng;
          notifyListeners();
      }
  }
  
  void setEventLocationForClue(int index) {
      if (index >= 0 && index < _clueForms.length) {
          _clueForms[index]['latitude'] = _latitude;
          _clueForms[index]['longitude'] = _longitude;
          notifyListeners();
      }
  }

  // --- Stores Logic ---

  void addPendingStore(Map<String, dynamic> storeData) {
    _pendingStores.add(storeData);
    notifyListeners();
  }

  void removePendingStore(int index) {
    _pendingStores.removeAt(index);
    notifyListeners();
  }

  // --- Validation ---

  // --- Validation ---

  void checkFormValidity() {
    bool isValid = true;
    if (_title.isEmpty) isValid = false;
    if (_description.isEmpty) isValid = false;
    if (_maxParticipants <= 0) isValid = false;
    if (_clue.isEmpty && _eventType != 'online') isValid = false;
    if (_selectedImage == null) isValid = false;
    
    // Validate fields based on mode
    if (_eventType == 'on_site') {
      if (_pin.length != 6) isValid = false;
      if (_latitude == null || _longitude == null) isValid = false;
    } 
    // Online mode: PIN is auto-generated, location is 0.0

    if (isValid != _isFormValid) {
      _isFormValid = isValid;
      notifyListeners();
    }
  }

  // --- SUBMIT ---

  Future<bool> submitEvent({
    required EventProvider eventProvider,
    required StoreProvider storeProvider,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    if (_isLoading) return false;
    
    // Final check
    checkFormValidity();
    if (!_isFormValid) {
       onError("Faltan campos por completar");
       return false;
    }

    _isLoading = true;
    notifyListeners();

    String? createdEventId;
    String finalPin = _pin;

    try {
      // Auto-generate PIN for Online Mode
      if (_eventType == 'online') {
         // Use Factory
         finalPin = EventFactoryService.generatePin(isOnline: true);
         _pin = finalPin; // Update state so UI might show it if needed
      }

      final newEvent = GameEvent(
        id: _eventId,
        title: _title,
        description: _description,
        locationName: _eventType == 'online' ? 'Online' : (_locationName ?? 'Unknown'),
        latitude: _eventType == 'online' ? 0.0 : _latitude!,
        longitude: _eventType == 'online' ? 0.0 : _longitude!,
        date: _selectedDate,
        createdByAdminId: 'admin_1',
        imageUrl: _selectedImage!.name,
        clue: _clue,
        maxParticipants: _maxParticipants,
        pin: finalPin,
        type: _eventType,
      );

      // 1. Create Event
      createdEventId = await eventProvider.createEvent(newEvent, _selectedImage);

      // 2. Create Clues
      if (createdEventId != null && _clueForms.isNotEmpty) {
        // Sanitize Clues for Online Mode
        if (_eventType == 'online') {
            EventFactoryService.sanitizeCluesForOnline(_clueForms);
        }

        await eventProvider.createCluesBatch(createdEventId, _clueForms);
      }
      
      // 3. Create Stores
      if (createdEventId != null) {
        if (_eventType == 'online') {
            // Default Online Store via Factory
            try {
               final defaultStore = EventFactoryService.createDefaultOnlineStore(createdEventId);
               // We pass null for imageFile as we don't have one selected
               await storeProvider.createStore(defaultStore, null);
            } catch (e) {
               debugPrint("Error creating default online store: $e");
            }
        } else {
           // On-site: Create pending stores
           if (_pendingStores.isNotEmpty) {
               for (var storeData in _pendingStores) {
                 try {
                    final store = storeData['store'] as MallStore;
                    final imageFile = storeData['imageFile'] as XFile?;
                    
                    final storeToCreate = MallStore(
                      id: store.id,
                      eventId: createdEventId, 
                      name: store.name,
                      description: store.description,
                      imageUrl: store.imageUrl,
                      qrCodeData: store.qrCodeData,
                      products: store.products,
                    );
                    await storeProvider.createStore(storeToCreate, imageFile);
                 } catch (e) {
                   debugPrint("Error creating store for event: $e");
                 }
               }
           }
        }
      }

      String successMessage = _eventType == 'online' 
          ? 'Competencia Online creada. PIN: $finalPin' 
          : 'Competencia creada con éxito';
      
      onSuccess(successMessage);
      resetForm();
      return true;

    } catch (error) {
      if (createdEventId != null) {
        try {
          await eventProvider.deleteEvent(createdEventId);
        } catch (e) {
           debugPrint("Rollback error: $e");
        }
      }
      onError("Error al crear evento: $error");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
