import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Service that monitors network connectivity and provides a broadcast stream of online status.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityStreamController = StreamController<bool>.broadcast();

  /// Broadcast stream emitting the current online status (`true` for connected, `false` otherwise).
  Stream<bool> get connectivityStream => _connectivityStreamController.stream;

  /// Initializes connectivity listening and emits online status changes.
  /// Should be called once during app startup.
  void init() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      bool hasInternet = await hasInternetAccess();
      _connectivityStreamController.add(hasInternet);
    });
  }

  /// Checks if the device has an active internet connection.
  /// This method first checks the network interfaces via `Connectivity().checkConnectivity()`.
  /// If a network is present, it performs a lightweight HTTP HEAD request to a reliable endpoint
  /// (OpenStreetMap tile server) to verify actual internet reachability.
  /// Returns `true` only when both interface and remote reachability succeed.
  Future<bool> hasInternetAccess() async {
    final List<ConnectivityResult> connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
      return false; // Not connected to any network interface
    }

    try {
      // Ping OpenStreetMap tiles to confirm real internet access
      final response = await http.head(
        Uri.parse('https://tile.openstreetmap.org'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false; // Network interface is up, but no internet routing
    }
  }
}
