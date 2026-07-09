import 'package:flutter/foundation.dart';
import 'upload_queue_service.dart';

class SightingUploadService {
  static final SightingUploadService _instance = SightingUploadService._internal();
  factory SightingUploadService() => _instance;
  SightingUploadService._internal();

  /// Uploads a confirmed dengue vector scan to the persistent queue for syncing to Firestore.
  Future<void> upload({
    required String species,
    required double lat,
    required double lng,
    required double confidence,
    required DateTime timestamp,
  }) async {
    try {
      await UploadQueueService().enqueue(
        species: species,
        lat: lat,
        lng: lng,
        confidence: confidence,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('Failed to enqueue sighting: $e');
      // We don't throw here to ensure the local app flow continues smoothly
    }
  }
}
