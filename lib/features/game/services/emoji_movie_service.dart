import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treasure_hunt_rpg/features/game/models/emoji_movie_problem.dart';

class EmojiMovieService {
  final SupabaseClient _supabase;

  EmojiMovieService(this._supabase);

  /// Fetches a list of random movies from the database.
  Future<List<EmojiMovieProblem>> fetchAllMovies() async {
    try {
      final response = await _supabase
          .from('minigame_emoji_movies')
          .select('emojis, valid_answers');

      final List<dynamic> data = response;
      return data.map((json) {
        return EmojiMovieProblem(
          emojis: json['emojis'] as String,
          validAnswers: List<String>.from(json['valid_answers'] as List),
        );
      }).toList();
    } catch (e) {
      print("Error fetching emoji movies from DB: $e");
      // Return empty list on error (no local fallback)
      return [];
    }
  }
}
