class Scenario {
  final String id;
  final String name;
  final String description;
  final String location;
  final String imageUrl;
  final String state;
  final int maxPlayers;
  final String starterClue;
  final String secretCode; // The code they need to find
  final double? latitude;
  final double? longitude;

  const Scenario({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.imageUrl,
    required this.state,
    required this.maxPlayers,
    required this.starterClue,
    required this.secretCode,
    this.latitude,
    this.longitude,
  });
}
