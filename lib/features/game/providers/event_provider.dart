import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';
import '../models/clue.dart';

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

  // Actualizar evento
  Future<void> updateEvent(GameEvent event, XFile? imageFile) async {
    try {
      String imageUrl = event.imageUrl;

      // 1. Subir nueva imagen si existe
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

      // 2. Actualizar en BD
      final response = await _supabase
          .from('events')
          .update({
            'title': event.title,
            'description': event.description,
            'location_name': event.locationName,
            'latitude': event.latitude,
            'longitude': event.longitude,
            'date': event.date.toIso8601String(),
            'clue': event.clue,
            'image_url': imageUrl,
            'max_participants': event.maxParticipants,
            'pin': event.pin,
          })
          .eq('id', event.id)
          .select()
          .single();

      // 3. Actualizar lista local
      final updatedEvent = _mapJsonToEvent(response);
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = updatedEvent;
        notifyListeners();
      }
    } catch (e) {
      print('Error actualizando evento: $e');
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

  // --- GESTIÓN DE PISTAS (ADMIN) ---

  Future<List<Clue>> fetchCluesForEvent(String eventId) async {
    try {
      print('🔍 Fetching clues for event: $eventId');
      final response = await _supabase
          .from('clues')
          .select()
          .eq('event_id', eventId)
          .order('order_index', ascending: true);

      print('✅ Found ${(response as List).length} clues raw data');
      return (response as List).map((json) => Clue.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching clues for event: $e');
      return [];
    }
  }

  Future<void> updateClue(Clue clue) async {
    try {
      await _supabase.from('clues').update({
        'title': clue.title,
        'description': clue.description,
        'puzzle_type': clue.puzzleType.toString().split('.').last,
        'riddle_question': clue.riddleQuestion,
        'riddle_answer': clue.riddleAnswer,
        'xp_reward': clue.xpReward,
      }).eq('id', clue.id);
      
      notifyListeners();
    } catch (e) {
      print('Error updating clue: $e');
      rethrow;
    }
  }

  Future<void> addClue(String eventId, Clue clue) async {
    try {
      // Find current max order
      final maxOrderRes = await _supabase
          .from('clues')
          .select('order_index')
          .eq('event_id', eventId)
          .order('order_index', ascending: false)
          .limit(1)
          .maybeSingle();
      
      int nextOrder = 1;
      if (maxOrderRes != null && maxOrderRes['order_index'] != null) {
        nextOrder = (maxOrderRes['order_index'] as int) + 1;
      }

      await _supabase.from('clues').insert({
        'event_id': eventId,
        'title': clue.title,
        'description': clue.description,
        'hint': clue.hint,
        'type': clue.type.toString().split('.').last,
        'puzzle_type': clue.puzzleType.toString().split('.').last,
        'riddle_question': clue.riddleQuestion,
        'riddle_answer': clue.riddleAnswer,
        'xp_reward': clue.xpReward,
        'coin_reward': clue.coinReward,
        'order_index': nextOrder,
        'isLocked': true, // Default
      });
      
      notifyListeners();
    } catch (e) {
      print('Error adding clue: $e');
      rethrow;
    }
  }
}