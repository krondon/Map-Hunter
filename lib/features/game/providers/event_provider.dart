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
            'id': event.id, // Permitimos ID generado por cliente (UUID)
            'title': event.title,
            'description': event.description,
            'location_name': event.locationName,
            'latitude': event.latitude,
            'longitude': event.longitude,
            'date': event.date.toUtc().toIso8601String(),
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
  // Crear CLUES en Lote (Client Side)
  Future<void> createCluesBatch(String eventId, List<Map<String, dynamic>> cluesData) async {
    try {
      if (cluesData.isEmpty) return;

      final List<Map<String, dynamic>> toInsert = [];
      
      for (int i = 0; i < cluesData.length; i++) {
        final clue = cluesData[i];
        toInsert.add({
          'event_id': eventId,
          'title': clue['title'],
          'description': clue['description'],
          'hint': clue['hint'] ?? '',
          'type': clue['type'] ?? 'minigame',
          'latitude': clue['latitude'],
          'longitude': clue['longitude'],
          'puzzle_type': clue['puzzle_type'] ?? 'slidingPuzzle', // Fallback
          'riddle_question': clue['riddle_question'],
          'riddle_answer': clue['riddle_answer'],
          'xp_reward': clue['xp_reward'] ?? 50,
          'coin_reward': clue['coin_reward'] ?? 10,
          'sequence_index': i + 1, // Guardamos el orden explícito
        });
      }

      await _supabase.from('clues').insert(toInsert);
      
      print("✅ ${toInsert.length} Pistas creadas exitosamente para el evento $eventId");
    } catch (e) {
      print("❌ Error creando lote de pistas: $e");
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
            'date': event.date.toUtc().toIso8601String(),
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
      // 1. Buscar el evento localmente para obtener la URL de la imagen
      final index = _events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final event = _events[index];
        
        // 2. Intentar borrar imagen de Storage si existe
        if (event.imageUrl.isNotEmpty) {
          try {
            // URL típica: .../storage/v1/object/public/events-images/events/timestamp.jpg
            // Necesitamos extraer: events/timestamp.jpg
            final uri = Uri.parse(event.imageUrl);
            // La estructura del path suele incluir el bucket 'events-images'
            // Buscamos el segmento después del bucket
            final pathSegments = uri.pathSegments;
            final bucketIndex = pathSegments.indexOf('events-images');
            
            if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
              final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
              print('🗑️ Intetando borrar imagen: $filePath');
              await _supabase.storage.from('events-images').remove([filePath]);
            }
          } catch (e) {
            print('⚠️ Error eliminando imagen del storage (no bloqueante): $e');
            // Continuamos con el borrado del registro aunque falle la imagen
          }
        }
      }

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
      id: data['id'] as String,
      title: data['title'] as String,
      description: (data['description'] ?? '') as String,
      locationName: (data['location_name'] ?? '') as String,
      latitude: (data['latitude'] is double)
            ? data['latitude']
            : (double.tryParse(data['latitude'].toString()) ?? 0.0),
      longitude: (data['longitude'] is double)
            ? data['longitude']
            : (double.tryParse(data['longitude'].toString()) ?? 0.0),
      date: DateTime.parse(data['date'] as String),
      createdByAdminId: (data['created_by_admin_id'] ?? '') as String,
      imageUrl: (data['image_url'] ?? '') as String,
      // CAMBIO IMPORTANTE: Si la BD trae null, ponemos string vacío, pero nunca null
      clue: (data['clue'] ?? '¡Pista desbloqueada!') as String, 
      maxParticipants: (data['max_participants'] ?? 0) as int,
      pin: (data['pin'] ?? '') as String,
      winnerId: data['winner_id'] as String?, // Map winner_id field
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
          .order('sequence_index', ascending: true);

      if (response != null && (response as List).isNotEmpty) {
        print('📦 First clue RAW data: ${response[0]}');
        print('❓ Hint in RAW data: "${response[0]['hint']}"');
      }

      return (response as List).map((json) => Clue.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching clues for event: $e');
      return [];
    }
  }

  Future<void> updateClue(Clue clue) async {
    try {
      print('📤 Updating Clue ID: ${clue.id} - Hint to save: "${clue.hint}"');
      
      final response = await _supabase.from('clues').update({
        'title': clue.title,
        'description': clue.description,
        'puzzle_type': clue.puzzleType.toString().split('.').last,
        'riddle_question': clue.riddleQuestion,
        'riddle_answer': clue.riddleAnswer,
        'xp_reward': clue.xpReward,
        'coin_reward': clue.coinReward,
        'latitude': clue.latitude,
        'longitude': clue.longitude,
        'hint': clue.hint,
        'sequence_index': clue.sequenceIndex,
      }).eq('id', clue.id).select();
      
      print('✅ Update Response: $response');
      
      notifyListeners();
    } catch (e) {
      print('❌ Error updating clue: $e');
      rethrow;
    }
  }

  Future<void> addClue(String eventId, Clue clue) async {
    try {
      print('➕ Adding Clue - Hint to save: "${clue.hint}"');

      final maxOrderRes = await _supabase
          .from('clues')
          .select('sequence_index')
          .eq('event_id', eventId)
          .order('sequence_index', ascending: false)
          .limit(1)
          .maybeSingle();
      
      int nextOrder = 1;
      if (maxOrderRes != null && maxOrderRes['sequence_index'] != null) {
        nextOrder = (maxOrderRes['sequence_index'] as int) + 1;
      }

      final response = await _supabase.from('clues').insert({
        'event_id': eventId.trim(),
        'title': clue.title,
        'description': clue.description,
        'hint': clue.hint,
        'type': clue.type.toString().split('.').last,
        'puzzle_type': clue.puzzleType.toString().split('.').last,
        'riddle_question': clue.riddleQuestion,
        'riddle_answer': clue.riddleAnswer,
        'xp_reward': clue.xpReward,
        'coin_reward': clue.coinReward,
        'sequence_index': nextOrder,
        'latitude': clue.latitude,
        'longitude': clue.longitude,
      }).select();
      
      print('✅ Add Response: $response');
      
      notifyListeners();
    } catch (e) {
      print('❌ Error adding clue: $e');
      rethrow;
    }
  }

  Future<void> restartCompetition(String eventId) async {
    try {
      // Llamamos a la Edge Function de administración para un reinicio nuclear
      final response = await _supabase.functions.invoke(
        'admin-actions/reset-event',
        body: {'eventId': eventId},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        throw Exception('Error en Edge Function del servidor: ${response.data}');
      }

      // 2. Refrescar eventos locales
      await fetchEvents(); 
      notifyListeners();
    } catch (e) {
      print('Error al reiniciar competencia: $e');
      rethrow;
    }
  }

  Future<void> deleteClue(String clueId) async {
    try {
      await _supabase.from('clues').delete().eq('id', clueId);
      notifyListeners();
    } catch (e) {
      print('Error deleting clue: $e');
      rethrow;
    }
  }
}