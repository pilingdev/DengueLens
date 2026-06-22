import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/sighting_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SightingFeedService {
  static final SightingFeedService _instance = SightingFeedService._internal();
  factory SightingFeedService() => _instance;
  SightingFeedService._internal();

  final _db = FirebaseFirestore.instance;

  /// Returns a real-time stream of dengue vector sightings within [radiusM] meters of [center].
  /// Filters out sightings older than 7 days.
  Stream<List<Sighting>> sightingsNear(LatLng center, {double radiusM = 100}) {
    // 1. Compute bounding box deltas
    // ~111.32 km per degree of latitude
    final double latDelta = radiusM / 111320.0;
    // Longitude length varies with latitude
    final double lngDelta = radiusM / (111320.0 * math.cos(center.latitudeInRad));

    final double minLat = center.latitude - latDelta;
    final double maxLat = center.latitude + latDelta;
    final double minLng = center.longitude - lngDelta;
    final double maxLng = center.longitude + lngDelta;

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final distanceCalc = const Distance();

    // 2. Firestore bounding-box query on lat, and time filter
    return _db
        .collection('sightings')
        .where('lat', isGreaterThanOrEqualTo: minLat)
        .where('lat', isLessThanOrEqualTo: maxLat)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('lat')
        .snapshots()
        .map((snapshot) {
      final List<Sighting> validSightings = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double lng = data['lng'] as double;

        // 3. Client-side longitude filter
        if (lng >= minLng && lng <= maxLng) {
          final latLng = LatLng(data['lat'] as double, lng);
          
          // 4. True Haversine distance filter (to get a circle, not a square box)
          final distance = distanceCalc.as(LengthUnit.Meter, center, latLng);
          if (distance <= radiusM) {
            
            // Map Firestore data to Sighting model
            Species species = Species.aegypti;
            if (data['species'] == 'albopictus') {
              species = Species.albopictus;
            }
            
            // Optional: calculate bearing
            final bearing = _getBearingString(center, latLng);
            
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            final isOwnSighting = data['userId'] == FirebaseAuth.instance.currentUser?.uid;

            validSightings.add(Sighting(
              id: doc.id,
              species: species,
              location: latLng,
              timestamp: timestamp,
              distance: distance,
              bearing: bearing,
              isOwnSighting: isOwnSighting,
            ));
          }
        }
      }
      return validSightings;
    });
  }

  String _getBearingString(LatLng center, LatLng target) {
    // A simplified bearing logic. For precise bearing, latlong2 has bearing features.
    final dy = target.latitude - center.latitude;
    final dx = target.longitude - center.longitude;
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    
    if (angle >= -22.5 && angle < 22.5) return 'E';
    if (angle >= 22.5 && angle < 67.5) return 'NE';
    if (angle >= 67.5 && angle < 112.5) return 'N';
    if (angle >= 112.5 && angle < 157.5) return 'NW';
    if (angle >= 157.5 || angle < -157.5) return 'W';
    if (angle >= -157.5 && angle < -112.5) return 'SW';
    if (angle >= -112.5 && angle < -67.5) return 'S';
    if (angle >= -67.5 && angle < -22.5) return 'SE';
    return 'N';
  }
}
