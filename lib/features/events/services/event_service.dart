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

        await _uploadWithRetry(
          'events-images',
          filePath,
          bytes,
          FileOptions(contentType: mimeType, upsert: true),
        );

        imageUrl =
            _supabase.storage.from('events-images').getPublicUrl(filePath);
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
            'entry_fee': event.entryFee, // NEW: Persistence fix
            'configured_winners': event.configuredWinners,
            'spectator_config': event.spectatorConfig, // NEW: Persist spectator prices
            'bet_ticket_price': event.betTicketPrice, // NEW: Persist betting price
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
  Future<void> createCluesBatch(
      String eventId, List<Map<String, dynamic>> cluesData) async {
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
          'sequence_index': i + 1, // Guardamos el orden explícito
        });
      }

      await _supabase.from('clues').insert(toInsert);

      debugPrint(
          "✅ ${toInsert.length} Pistas creadas exitosamente para el evento $eventId");
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

        await _uploadWithRetry(
          'events-images',
          filePath,
          bytes,
          FileOptions(contentType: mimeType, upsert: true),
        );

        imageUrl =
            _supabase.storage.from('events-images').getPublicUrl(filePath);
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
            'entry_fee': event.entryFee, // NEW: Persistence fix
            'configured_winners': event.configuredWinners,
            'spectator_config': event.spectatorConfig, // NEW: Persist spectator prices
            'bet_ticket_price': event.betTicketPrice, // NEW: Persist betting price
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
          debugPrint(
              '⚠️ Error eliminando imagen del storage (no bloqueante): $e');
        }
      }

      await _supabase.from('events').delete().eq('id', eventId);
    } catch (e) {
      debugPrint('Error eliminando evento: $e');
      rethrow;
    }
  }

  // Actualizar status del evento
  Future<void> updateEventStatus(String eventId, String status) async {
    try {
      await _supabase
          .from('events')
          .update({'status': status}).eq('id', eventId);
    } catch (e) {
      debugPrint('Error updating event status: $e');
      rethrow;
    }
  }

  // Obtener eventos
  Future<List<GameEvent>> fetchEvents({String? type}) async {
    try {
      // 1. Fetch events with optional filter
      var query = _supabase.from('events').select();

      if (type != null) {
        query = query.eq('type', type);
      }

      // Default sort: Newest first (Descending Date)
      // This ensures "Finished" events and active ones are ordered by creation/start date
      final response = await query.order('date', ascending: false);
      final List<dynamic> eventsData = response as List;

      // 2. Fetch participant counts for these events
      // Optimized: one query to get counts for all active events
      final participantCounts = await _supabase
          .from('game_players')
          .select('event_id')
          .neq('status', 'spectator');
      // Count everyone who is NOT a spectator.
      // This includes active, inGame, finished, etc.

      final Map<String, int> countsMap = {};
      for (var row in participantCounts) {
        final eid = row['event_id'] as String;
        countsMap[eid] = (countsMap[eid] ?? 0) + 1;
      }

      return eventsData.map((data) {
        final String id = data['id'];
        final int count = countsMap[id] ?? 0;
        final map = Map<String, dynamic>.from(data);
        map['current_participants'] = count;
        return _mapJsonToEvent(map);
      }).toList();
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
      status:
          (data['status'] ?? 'pending') as String, // FIX: Map status from DB
      winnerId: data['winner_id'] as String?,
      type: data['type'] ?? 'on_site',
      entryFee: (data['entry_fee'] as num?)?.toInt() ??
          0, // NEW: Read persistence fix
      currentParticipants: (data['current_participants'] as num?)?.toInt() ?? 0,
      configuredWinners: (data['configured_winners'] as num?)?.toInt() ?? 3,
      pot: (data['pot'] as num?)?.toInt() ?? 0, // FIX: Map pot from DB
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
      debugPrint(
          '📤 Updating Clue ID: ${clue.id} - Hint to save: "${clue.hint}"');

      final response = await _supabase
          .from('clues')
          .update({
            'title': clue.title,
            'description': clue.description,
            'puzzle_type': (clue is OnlineClue)
                ? (clue as OnlineClue).puzzleType.toString().split('.').last
                : null,
            'riddle_question': (clue is OnlineClue)
                ? (clue as OnlineClue).riddleQuestion
                : null,
            'riddle_answer':
                (clue is OnlineClue) ? (clue as OnlineClue).riddleAnswer : null,
            'xp_reward': clue.xpReward,
            'latitude':
                (clue is PhysicalClue) ? (clue as PhysicalClue).latitude : null,
            'longitude': (clue is PhysicalClue)
                ? (clue as PhysicalClue).longitude
                : null,
            'hint': clue.hint,
            'sequence_index': clue.sequenceIndex,
          })
          .eq('id', clue.id)
          .select();

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
        'puzzle_type': (clue is OnlineClue)
            ? (clue as OnlineClue).puzzleType.toString().split('.').last
            : null,
        'riddle_question':
            (clue is OnlineClue) ? (clue as OnlineClue).riddleQuestion : null,
        'riddle_answer':
            (clue is OnlineClue) ? (clue as OnlineClue).riddleAnswer : null,
        'xp_reward': clue.xpReward,
        'sequence_index': clue.sequenceIndex > 0
            ? clue.sequenceIndex
            : nextOrder, // Use provided index if valid
        'latitude':
            (clue is PhysicalClue) ? (clue as PhysicalClue).latitude : null,
        'longitude':
            (clue is PhysicalClue) ? (clue as PhysicalClue).longitude : null,
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
        throw Exception(
            'Error en Edge Function del servidor: ${response.data}');
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

  // Helper para subir archivos con reintentos
  Future<void> _uploadWithRetry(
    String bucket,
    String path,
    Uint8List bytes,
    FileOptions options, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        await _supabase.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: options,
            );
        return; // Success
      } catch (e) {
        attempt++;
        debugPrint(
            '⚠️ Error subiendo imagen (intento $attempt/$maxRetries): $e');
        if (attempt >= maxRetries) rethrow; // Falló definitivamente
        await Future.delayed(
            Duration(seconds: attempt * 2)); // Backoff exponencial
      }
    }
  }

  // --- REALTIME STREAMS ---

  /// Escucha cambios en tiempo real de un evento específico
  Stream<GameEvent> getEventStream(String eventId) {
    return _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('id', eventId)
        .map((data) {
          if (data.isEmpty) {
            // Si no hay datos (ej. borrado), lanzar error o manejarlo
            throw Exception('Evento no encontrado');
          }
          final eventData = data.first;
          
          // Mapeamos manualmente para usar nuestro helper
          // Necesitamos el conteo de participantes también, pero en Stream es complejo hacer joins.
          // Por simplicidad en SpectatorMode, asumiremos que currentParticipants viene del stream 
          // (si la BD lo actualiza) o lo ignoramos si solo nos importa el status.
          // Para ser precisos, el spectator mode usa `currentParticipants` solo pre-carrera?
          // La vista de lista de participantes podría necesitarlo.
          // Haremos un "best guess" mapeando lo que llegue.
          
          return _mapJsonToEvent(eventData);
        });
  }

}
