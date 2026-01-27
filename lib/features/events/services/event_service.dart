import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../game/models/event.dart';
import '../../game/models/clue.dart';

class EventService {
  final SupabaseClient _supabase;

  EventService(this._supabase);

  // Crear evento
  Future<GameEvent> createEvent(GameEvent event, XFile? imageFile) async {
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
           if (fileExt == 'jpg' || fileExt == 'jpeg') {
             mimeType = 'image/jpeg';
           } else if (fileExt == 'png') {
             mimeType = 'image/png';
           } else {
             mimeType = 'application/octet-stream';
           }
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
            'clue': event.clue, 
            'image_url': imageUrl,
            'max_participants': event.maxParticipants,
            'pin': event.pin,
            'created_by_admin_id': _supabase.auth.currentUser?.id ?? 'admin_1',
            'type': event.type,
          })
          .select()
          .single();

      return _mapJsonToEvent(response);
    } catch (e) {
      debugPrint('Error creando evento: $e');
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
      
      debugPrint("✅ ${toInsert.length} Pistas creadas exitosamente para el evento $eventId");
    } catch (e) {
      debugPrint("❌ Error creando lote de pistas: $e");
      rethrow;
    }
  }

  // Actualizar evento
  Future<GameEvent> updateEvent(GameEvent event, XFile? imageFile) async {
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
           if (fileExt == 'jpg' || fileExt == 'jpeg') {
             mimeType = 'image/jpeg';
           } else if (fileExt == 'png') {
             mimeType = 'image/png';
           } else {
             mimeType = 'application/octet-stream';
           }
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
            'type': event.type,
          })
          .eq('id', event.id)
          .select()
          .single();

      return _mapJsonToEvent(response);
    } catch (e) {
      debugPrint('Error actualizando evento: $e');
      rethrow;
    }
  }

  // Eliminar evento
  Future<void> deleteEvent(String eventId, String currentImageUrl) async {
    try {
      // 2. Intentar borrar imagen de Storage si existe
      if (currentImageUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(currentImageUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('events-images');
          
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            debugPrint('🗑️ Intetando borrar imagen: $filePath');
            await _supabase.storage.from('events-images').remove([filePath]);
          }
        } catch (e) {
          debugPrint('⚠️ Error eliminando imagen del storage (no bloqueante): $e');
        }
      }

      await _supabase.from('events').delete().eq('id', eventId);
    } catch (e) {
      debugPrint('Error eliminando evento: $e');
      rethrow;
    }
  }

  // Obtener eventos
  Future<List<GameEvent>> fetchEvents() async {
    try {
      final response = await _supabase.from('events').select();
      return (response as List).map((data) => _mapJsonToEvent(data)).toList();
    } catch (e) {
      debugPrint('Error obteniendo eventos: $e');
      rethrow;
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
      clue: (data['clue'] ?? '¡Pista desbloqueada!') as String, 
      maxParticipants: (data['max_participants'] ?? 0) as int,
      pin: (data['pin'] ?? '') as String,
      winnerId: data['winner_id'] as String?, 
      type: data['type'] ?? 'on_site',
    );
  }

  // --- GESTIÓN DE PISTAS (ADMIN) ---

  Future<List<Clue>> fetchCluesForEvent(String eventId) async {
    try {
      debugPrint('🔍 Fetching clues for event: $eventId');
      final response = await _supabase
          .from('clues')
          .select()
          .eq('event_id', eventId)
          .order('sequence_index', ascending: true);

      return (response as List).map((json) => Clue.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching clues for event: $e');
      return [];
    }
  }

  Future<void> updateClue(Clue clue) async {
    try {
      debugPrint('📤 Updating Clue ID: ${clue.id} - Hint to save: "${clue.hint}"');
      
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
      
      debugPrint('✅ Update Response: $response');
    } catch (e) {
      debugPrint('❌ Error updating clue: $e');
      rethrow;
    }
  }

  Future<void> addClue(String eventId, Clue clue) async {
    try {
      debugPrint('➕ Adding Clue - Hint to save: "${clue.hint}"');

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
      
      debugPrint('✅ Add Response: $response');
    } catch (e) {
      debugPrint('❌ Error adding clue: $e');
      rethrow;
    }
  }

  Future<void> restartCompetition(String eventId) async {
    try {
      final response = await _supabase.functions.invoke(
        'admin-actions/reset-event',
        body: {'eventId': eventId},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        throw Exception('Error en Edge Function del servidor: ${response.data}');
      }
    } catch (e) {
      debugPrint('Error al reiniciar competencia: $e');
      rethrow;
    }
  }

  Future<void> deleteClue(String clueId) async {
    try {
      await _supabase.from('clues').delete().eq('id', clueId);
    } catch (e) {
      debugPrint('Error deleting clue: $e');
      rethrow;
    }
  }
}
