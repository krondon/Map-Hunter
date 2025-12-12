import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';

class EventProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<GameEvent> _events = [];

  List<GameEvent> get events => _events;

  // Función para crear el evento
  Future<String?> createEvent(GameEvent event, XFile? imageFile) async {
    try {
      String imageUrl = event.imageUrl;

      // 1. Subir imagen si existe
      if (imageFile != null) {
        final fileExt = imageFile.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'events/$fileName';

        // Leer bytes (funciona en Web y Móvil/Desktop de forma más robusta)
        final bytes = await imageFile.readAsBytes();

        // Intentar adivinar el mimeType si viene nulo (común en Desktop)
        String mimeType = imageFile.mimeType ?? '';
        if (mimeType.isEmpty) {
          if (fileExt == 'jpg' || fileExt == 'jpeg')
            mimeType = 'image/jpeg';
          else if (fileExt == 'png')
            mimeType = 'image/png';
          else
            mimeType = 'application/octet-stream';
        }

        // Usar uploadBinary para mayor compatibilidad en todas las plataformas
        await _supabase.storage.from('events-images').uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );

        // Obtener URL pública
        imageUrl =
            _supabase.storage.from('events-images').getPublicUrl(filePath);
      }

      // 2. Insertar en la tabla 'events'
      debugPrint(
          'Creating event with title: ${event.title}, description: ${event.description}');

      final response = await _supabase
          .from('events')
          .insert({
            'title': event.title,
            'description': event.description,
            'location_name': event.locationName,
            'location':
                event.locationName, // Asegura que location siempre tenga valor
            'latitude': event.latitude,
            'longitude': event.longitude,
            'date': event.date.toIso8601String(),
            'clue': event.clue,
            'image_url': imageUrl,
            'max_participants': event.maxParticipants,
            'pin': event.pin,
            'created_by_admin_id': _supabase.auth.currentUser?.id ?? 'admin_1',
          })
          .select()
          .single();

      // 3. Actualizar lista local
      final newEvent = GameEvent(
        id: response['id'],
        title: response['title'],
        description: response['description'] ?? '',
        locationName: response['location_name'] ?? '',
        latitude: (response['latitude'] is double)
            ? response['latitude']
            : (response['latitude'] != null
                ? double.tryParse(response['latitude'].toString()) ?? 0.0
                : 0.0),
        longitude: (response['longitude'] is double)
            ? response['longitude']
            : (response['longitude'] != null
                ? double.tryParse(response['longitude'].toString()) ?? 0.0
                : 0.0),
        date: DateTime.parse(response['date']),
        createdByAdminId: response['created_by_admin_id'] ?? '',
        imageUrl: response['image_url'] ?? '',
        clue: response['clue'],
        maxParticipants: response['max_participants'] ?? 0,
        pin: response['pin'] ?? '',
      );

      _events.add(newEvent);
      notifyListeners();
      return newEvent.id;
    } catch (e) {
      print('Error creando evento: $e');
      rethrow;
    }
  }

  // Función para eliminar evento
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);
      _events.removeWhere((e) => e.id == eventId);
      notifyListeners();
    } catch (e) {
      print('Error eliminando evento: $e');
      rethrow;
    }
  }

  // Función para obtener eventos
  Future<void> fetchEvents() async {
    try {
      final response = await _supabase.from('events').select();

      _events = (response as List)
          .map((data) => GameEvent(
                id: data['id'],
                title: data['title'],
                description: data['description'] ?? '',
                locationName: data['location_name'] ?? '',
                latitude: (data['latitude'] is double)
                    ? data['latitude']
                    : (data['latitude'] != null
                        ? double.tryParse(data['latitude'].toString()) ?? 0.0
                        : 0.0),
                longitude: (data['longitude'] is double)
                    ? data['longitude']
                    : (data['longitude'] != null
                        ? double.tryParse(data['longitude'].toString()) ?? 0.0
                        : 0.0),
                date: DateTime.parse(data['date']),
                createdByAdminId: data['created_by_admin_id'] ?? '',
                imageUrl: data['image_url'] ?? '',
                clue: data['clue'],
                maxParticipants: data['max_participants'] ?? 0,
                pin: data['pin'] ?? '',
              ))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Error obteniendo eventos: $e');
    }
  }
}
