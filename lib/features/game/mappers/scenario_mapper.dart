import '../models/scenario.dart';
import '../models/event.dart';

class ScenarioMapper {
  static Scenario fromEvent(GameEvent event) {
    String location = event.locationName;
    if (location.isEmpty) {
      location = '${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)}';
    }

    return Scenario(
      id: event.id,
      name: event.title,
      description: event.description,
      location: location,
      state: location,
      imageUrl: event.imageUrl,
      maxPlayers: event.maxParticipants,
      starterClue: event.clue,
      secretCode: event.pin,
      latitude: event.latitude,
      longitude: event.longitude,
      date: event.date,
      isCompleted: event.winnerId != null && event.winnerId!.isNotEmpty,
      type: event.type,
      entryFee: event.entryFee,
      currentParticipants: event.currentParticipants,
      status: event.status,
      pot: event.pot,
    );
  }

  static List<Scenario> fromEvents(List<GameEvent> events) {
    return events.map(fromEvent).toList();
  }
}
