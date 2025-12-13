import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';

class EventProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<GameEvent> _events = [];

  List<GameEvent> get events => _events;

  // Crear evento
  Future<String?> createEvent(GameEvent event, XFile? imageFile) async {
    try {
      String imageUrl = event.imageUrl;

      // 1. Subir imagen
      if (imageFile != null) {
        final fileExt = imageFile.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'events/$fileName';
        final bytes = await imageFile.readAsBytes();

        String mimeType = imageFile.mimeType ?? '';
        if (mimeType.isEmpty) {
           if (fileExt == 'jpg' || fileExt == 'jpeg') mimeType = 'image/jpeg';
           else if (fileExt == 'png') mimeType = 'image/png';
           else mimeType = 'application/octet-stream';
        }

        await _supabase.storage.from('events-images').uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );

        imageUrl = _supabase.storage.from('events-images').getPublicUrl(filePath);
      }

      // 2. Insertar en BD
      final response = await _supabase
          .from('events')
          .insert({
            'title': event.title,
            'description': event.description,
            'location_name': event.locationName,
            'latitude': event.latitude,
            'longitude': event.longitude,
            'date': event.date.toIso8601String(),
            'clue': event.clue, // <--- Ahora se envía obligatoriamente
            'image_url': imageUrl,
            'max_participants': event.maxParticipants,
            'pin': event.pin,
            'created_by_admin_id': _supabase.auth.currentUser?.id ?? 'admin_1',
          })
          .select()
          .single();

      // 3. Actualizar lista local
      final newEvent = _mapJsonToEvent(response);
      _events.add(newEvent);
      notifyListeners();
      return newEvent.id;
    } catch (e) {
      print('Error creando evento: $e');
      rethrow;
    }
  }

  // Eliminar evento
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

  // Obtener eventos
  Future<void> fetchEvents() async {
    try {
      final response = await _supabase.from('events').select();
      _events = (response as List).map((data) => _mapJsonToEvent(data)).toList();
      notifyListeners();
    } catch (e) {
      print('Error obteniendo eventos: $e');
    }
  }

  // Helper para mapear
  GameEvent _mapJsonToEvent(Map<String, dynamic> data) {
    return GameEvent(
      id: data['id'],
      title: data['title'],
      description: data['description'] ?? '',
      locationName: data['location_name'] ?? '',
      latitude: (data['latitude'] is double)
            ? data['latitude']
            : (double.tryParse(data['latitude'].toString()) ?? 0.0),
      longitude: (data['longitude'] is double)
            ? data['longitude']
            : (double.tryParse(data['longitude'].toString()) ?? 0.0),
      date: DateTime.parse(data['date']),
      createdByAdminId: data['created_by_admin_id'] ?? '',
      imageUrl: data['image_url'] ?? '',
      // CAMBIO IMPORTANTE: Si la BD trae null, ponemos string vacío, pero nunca null
      clue: data['clue'] ?? '¡Pista desbloqueada!', 
      maxParticipants: data['max_participants'] ?? 0,
      pin: data['pin'] ?? '',
    );
  }
}