import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// Checks if the device has an active internet connection.
  /// It verifies both the network interface and actual reachability via a lightweight HTTP ping.
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
