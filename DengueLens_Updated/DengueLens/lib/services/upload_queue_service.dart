import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'connectivity_service.dart';

class UploadQueueService {
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();

  static const String _boxName = 'upload_queue';
  static const String _deadLetterBoxName = 'dead_letter_queue';
  
  late Box _queueBox;
  late Box _deadLetterBox;
  Timer? _drainTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isDraining = false;

  Future<void> init() async {
    _queueBox = await Hive.openBox(_boxName);
    _deadLetterBox = await Hive.openBox(_deadLetterBoxName);

    // Start background drain timer (every 30 seconds)
    _drainTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _drainQueue();
    });

    // Listen to connectivity changes to trigger immediate drain
    _connectivitySubscription = ConnectivityService().connectivityStream.listen((hasInternet) {
      if (hasInternet) {
        _drainQueue();
      }
    });

    // Initial drain attempt on startup
    _drainQueue();
  }

  void dispose() {
    _drainTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// Generates a deduplication key based on sighting data.
  String _generateKey({
    required String species,
    required double lat,
    required double lng,
    required DateTime timestamp,
  }) {
    // Round lat/lng to ~100m precision (3 decimal places)
    final latRounded = lat.toStringAsFixed(3);
    final lngRounded = lng.toStringAsFixed(3);
    // Round time to minute to catch rapid multi-clicks
    final timeMinute = DateTime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour, timestamp.minute).toIso8601String();
    
    return '$species-$latRounded-$lngRounded-$timeMinute';
  }

  Future<void> enqueue({
    required String species,
    required double lat,
    required double lng,
    required double confidence,
    required DateTime timestamp,
  }) async {
    final key = _generateKey(
      species: species,
      lat: lat,
      lng: lng,
      timestamp: timestamp,
    );

    // Deduplication: Check if this item is already in the queue
    if (_queueBox.containsKey(key)) {
      debugPrint('Sighting already in queue (deduplicated): $key');
      return;
    }

    final item = {
      'species': species,
      'lat': lat,
      'lng': lng,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': 0,
      'nextRetryTime': DateTime.now().toIso8601String(),
    };

    await _queueBox.put(key, item);
    debugPrint('Sighting enqueued successfully: $key');

    // Trigger immediate drain
    _drainQueue();
  }

  Future<void> _drainQueue() async {
    if (_isDraining || _queueBox.isEmpty) return;
    _isDraining = true;

    try {
      final now = DateTime.now();
      
      // Get up to 10 items that are ready to be retried
      final itemsToProcess = <String, Map<dynamic, dynamic>>{};
      for (var key in _queueBox.keys) {
        final item = _queueBox.get(key) as Map<dynamic, dynamic>;
        final nextRetryTime = DateTime.parse(item['nextRetryTime'] as String);
        
        if (now.isAfter(nextRetryTime) || now.isAtSameMomentAs(nextRetryTime)) {
          itemsToProcess[key as String] = item;
          if (itemsToProcess.length >= 10) break;
        }
      }

      if (itemsToProcess.isEmpty) {
        _isDraining = false;
        return;
      }

      // Check internet before attempting Firestore write
      final hasInternet = await ConnectivityService().hasInternetAccess();
      if (!hasInternet) {
        debugPrint('No internet access. Delaying queue drain.');
        _isDraining = false;
        return;
      }

      // Ensure user is signed in anonymously
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final authResult = await FirebaseAuth.instance.signInAnonymously();
        user = authResult.user;
      }

      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      
      for (var entry in itemsToProcess.entries) {
        final item = entry.value;
        final docRef = db.collection('sightings').doc(); // Auto-ID
        
        batch.set(docRef, {
          'species': item['species'],
          'lat': item['lat'],
          'lng': item['lng'],
          'confidence': item['confidence'],
          'timestamp': Timestamp.fromDate(DateTime.parse(item['timestamp'] as String)),
          'userId': user?.uid ?? 'unknown',
        });
      }

      try {
        await batch.commit();
        
        // Success: remove processed items from queue
        for (var key in itemsToProcess.keys) {
          await _queueBox.delete(key);
        }
        debugPrint('Successfully batched uploaded ${itemsToProcess.length} items.');
      } on FirebaseException catch (e) {
        debugPrint('Firestore Batch Error: ${e.code} - ${e.message}');
        await _handleDrainError(itemsToProcess, e);
      } catch (e) {
        debugPrint('Unknown Batch Error: $e');
        await _handleDrainError(itemsToProcess, Exception(e.toString()));
      }
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _handleDrainError(Map<String, Map<dynamic, dynamic>> items, Exception error) async {
    bool isPermanent = false;
    
    if (error is FirebaseException) {
      // 429 Resource Exhausted, 503 Service Unavailable -> transient
      if (error.code == 'permission-denied' || error.code == 'invalid-argument' || error.code == 'unauthenticated') {
        isPermanent = true;
      }
    }

    for (var entry in items.entries) {
      final key = entry.key;
      final item = Map<String, dynamic>.from(entry.value);
      
      if (isPermanent) {
        // Move to dead letter queue
        debugPrint('Permanent error. Moving item $key to dead letter box.');
        await _deadLetterBox.put(key, item);
        await _queueBox.delete(key);
      } else {
        // Exponential backoff
        int retryCount = (item['retryCount'] as int? ?? 0) + 1;
        // 2s, 4s, 8s, 16s... up to 60s
        int backoffSeconds = (1 << retryCount); 
        if (backoffSeconds > 60) backoffSeconds = 60;
        
        item['retryCount'] = retryCount;
        item['nextRetryTime'] = DateTime.now().add(Duration(seconds: backoffSeconds)).toIso8601String();
        
        await _queueBox.put(key, item);
      }
    }
  }
}
