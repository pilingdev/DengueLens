import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SightingUploadService {
  static final SightingUploadService _instance = SightingUploadService._internal();
  factory SightingUploadService() => _instance;
  SightingUploadService._internal();

  final _db = FirebaseFirestore.instance;

  /// Uploads a confirmed dengue vector scan to Firestore.
  Future<void> upload({
    required String species,
    required double lat,
    required double lng,
    required double confidence,
    required DateTime timestamp,
  }) async {
    try {
      // Ensure user is signed in anonymously
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final authResult = await FirebaseAuth.instance.signInAnonymously();
        user = authResult.user;
      }

      await _db.collection('sightings').add({
        'species': species,
        'lat': lat,
        'lng': lng,
        'confidence': confidence,
        'timestamp': Timestamp.fromDate(timestamp),
        'userId': user?.uid ?? 'unknown',
      });
      debugPrint('Sighting uploaded to Firestore successfully.');
    } catch (e) {
      debugPrint('Failed to upload sighting: $e');
      // We don't throw here to ensure the local app flow continues smoothly
    }
  }
}
