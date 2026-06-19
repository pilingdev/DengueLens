import 'package:latlong2/latlong.dart';

enum Species { aegypti, albopictus }

class Sighting {
  final String id;
  final Species species;
  final LatLng location;
  final DateTime timestamp;
  final double distance; // distance from user in meters
  final String bearing; // e.g., 'NW', 'SE'
  final bool isOwnSighting; // whether the current user made this scan

  Sighting({
    required this.id,
    required this.species,
    required this.location,
    required this.timestamp,
    required this.distance,
    required this.bearing,
    this.isOwnSighting = false,
  });

  // Calculate age of the sighting in minutes
  int get ageInMinutes {
    return DateTime.now().difference(timestamp).inMinutes;
  }
}
