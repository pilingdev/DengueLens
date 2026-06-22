import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Requests permission if needed, and fetches the current device position.
  /// Returns null if permission is denied or location services are disabled.
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
          forceLocationManager: true, // BYPASS GOOGLE PLAY SERVICES
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
    } catch (e) {
      return null;
    }
  }

  /// Converts a Position object into a "lat,lng" string suitable for storage.
  String toLocationString(Position p) {
    return '${p.latitude},${p.longitude}';
  }

  /// Parses a "lat,lng" string back into a LatLng object.
  LatLng? parseLocationString(String? locationString) {
    if (locationString == null || !locationString.contains(',')) return null;
    try {
      final parts = locationString.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }
}
