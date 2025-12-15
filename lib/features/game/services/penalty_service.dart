import 'package:supabase_flutter/supabase_flutter.dart';

class PenaltyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Retorna la fecha fin del ban si está castigado, o NULL si puede jugar.
  Future<DateTime?> attemptStartGame() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null; // No debería pasar si hay auth guard

    try {
      final response = await _supabase.rpc('attempt_start_minigame', params: {
        'p_user_id': userId,
      });

      // Supabase devuelve un Map/JSON
      final data = response as Map<String, dynamic>;
      final status = data['status'];

      if (status == 'allowed') {
        return null; // Pase libre
      } else {
        // "banned" o "penalized_now"
        return DateTime.parse(data['ban_ends_at']); 
      }
    } catch (e) {
      print('Error penalty check: $e');
      // En caso de error de red, por seguridad del evento, podrías dejar pasar o bloquear.
      // Aquí dejamos pasar para no frustrar por mala conexión, pero idealmente se maneja el error.
      return null; 
    }
  }

  /// Llama a esto cuando gane o pierda legalmente
  Future<void> markGameFinishedLegally() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.rpc('finish_minigame_legally', params: {'p_user_id': userId});
    } catch (_) {}
  }
}