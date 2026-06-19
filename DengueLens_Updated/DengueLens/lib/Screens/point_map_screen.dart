import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sighting_model.dart';
import '../services/location_service.dart';
import '../services/connectivity_service.dart';
import '../services/sighting_feed_service.dart';

class PointMapScreen extends StatefulWidget {
  const PointMapScreen({super.key});

  @override
  State<PointMapScreen> createState() => _PointMapScreenState();
}

class _PointMapScreenState extends State<PointMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  bool _isOffline = false;
  bool _isLocating = true;
  LatLng? _userLocation;
  
  StreamSubscription? _sightingsSub;
  List<Sighting> _allSightings = [];
  bool _showNearOnly = false; // Filter toggle

  // Hardcoded fallback location (Kuala Lumpur)
  final LatLng _fallbackLocation = const LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  @override
  void dispose() {
    _sightingsSub?.cancel();
    super.dispose();
  }

  Future<void> _initMapData() async {
    setState(() {
      _isLocating = true;
    });

    // 1. Check internet
    final hasInternet = await ConnectivityService().hasInternetAccess();
    if (!hasInternet) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLocating = false;
        });
      }
      return;
    } else {
      if (mounted) {
        setState(() {
          _isOffline = false;
        });
      }
    }

    // 2. Get GPS Location
    await _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    if (!mounted) return;
    setState(() => _isLocating = true);

    final pos = await LocationService().getCurrentPosition();
    if (pos != null) {
      _userLocation = LatLng(pos.latitude, pos.longitude);
    } else {
      _userLocation = _fallbackLocation;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location unavailable, showing default area')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLocating = false);
    }

    // Center the map
    if (_userLocation != null) {
      _listenToSightings();
      
      // Defer the move until the FlutterMap widget has actually rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(_userLocation!, 17.5);
          } catch (_) {
            // Ignored: If it still hasn't rendered, initialCenter handles the initial load anyway.
          }
        }
      });
    }
  }

  void _listenToSightings() {
    if (_userLocation == null) return;
    
    _sightingsSub?.cancel();
    // Fetch sightings within roughly 5000m to allow the "All" view to show something, 
    // and then filter to 100m when toggled. (For a global map, we might fetch differently).
    // Let's fetch 1000m for this view to avoid massive data downloads.
    _sightingsSub = SightingFeedService()
        .sightingsNear(_userLocation!, radiusM: 1000)
        .listen((sightings) {
      if (mounted) {
        setState(() {
          _allSightings = sightings;
        });
      }
    });
  }

  List<Sighting> get _filteredSightings {
    if (!_showNearOnly) return _allSightings;
    return _allSightings.where((s) => s.distance <= 100).toList();
  }

  void _showFocusState(Sighting sighting) {
    final ageHours = sighting.ageInMinutes / 60.0;
    Color iconBorderColor;
    if (sighting.species == Species.aegypti) {
      iconBorderColor = ageHours <= 12
          ? const Color(0xFF2ECC71)
          : const Color(0xFFB0BEC5);
    } else {
      iconBorderColor = ageHours <= 12
          ? const Color(0xFFF59E0B)
          : const Color(0xFFB0BEC5);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.25,
          maxChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: iconBorderColor, width: 2),
                        ),
                        child: const Icon(
                          Icons.bug_report,
                          color: Colors.black26,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sighting.species == Species.aegypti
                                      ? 'Aedes aegypti'
                                      : 'Aedes albopictus',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (sighting.isOwnSighting)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ECC71).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'My Scan',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2ECC71),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.black54,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${sighting.distance.toStringAsFixed(0)}m • ${sighting.bearing}',
                                  style: GoogleFonts.inter(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.black54,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatPrecisionTimestamp(sighting.timestamp),
                                  style: GoogleFonts.inter(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatPrecisionTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return _buildOfflineBanner();
    }

    if (_isLocating && _userLocation == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF2ECC71)),
              SizedBox(height: 16),
              Text('Acquiring Location...', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    final sightingsToDisplay = _filteredSightings;

    int activeClusters = sightingsToDisplay
        .where((s) => s.ageInMinutes < 24 * 60)
        .length;
    int recentSightings = sightingsToDisplay
        .where((s) => s.ageInMinutes < 60)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Off-white
      body: Stack(
        children: [
          // The Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _fallbackLocation,
              initialZoom: 17.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Light Mode Basemap (CartoDB Light)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              if (_userLocation != null) ...[
                // Range Rings
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      color: const Color(0xFF2ECC71).withOpacity(0.05),
                      borderColor: const Color(0xFF2ECC71).withOpacity(0.3),
                      borderStrokeWidth: 1.5,
                      radius: 100, // 100m ring
                      useRadiusInMeter: true,
                    ),
                    CircleMarker(
                      point: _userLocation!,
                      color: const Color(0xFF2ECC71).withOpacity(0.08),
                      borderColor: const Color(0xFF2ECC71).withOpacity(0.4),
                      borderStrokeWidth: 1.5,
                      radius: 50, // 50m ring
                      useRadiusInMeter: true,
                    ),
                  ],
                ),

                // User Location Dot
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3498DB), // Blue for user
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3498DB).withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Sighting Markers (Heat Zones)
              MarkerLayer(
                markers: sightingsToDisplay.map((sighting) {
                  return Marker(
                    point: sighting.location,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showFocusState(sighting),
                      child: SightingMarker(sighting: sighting),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Custom App Bar (Floating)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, left: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.black87,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),

          // Tactical Summary Header & Filter Toggle
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF2ECC71).withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '$activeClusters Active | $recentSightings Recent',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2ECC71),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Toggle
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ToggleButtons(
                        borderRadius: BorderRadius.circular(20),
                        isSelected: [!_showNearOnly, _showNearOnly],
                        onPressed: (int index) {
                          setState(() {
                            _showNearOnly = index == 1;
                          });
                        },
                        color: Colors.black54,
                        selectedColor: Colors.white,
                        fillColor: const Color(0xFF2ECC71),
                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                        children: const [
                          Text('All'),
                          Text('< 100m'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recenter FAB
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 90.0, right: 16.0),
                child: FloatingActionButton(
                  heroTag: 'recenter_map',
                  onPressed: () async {
                    await _fetchUserLocation();
                  },
                  backgroundColor: Colors.white,
                  child: _isLocating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, color: Color(0xFF3498DB)),
                ),
              ),
            ),
          ),

          // Permanent Bottom Legend
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2ECC71).withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem('A. aegypti', const Color(0xFF2ECC71)),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    _buildLegendItem('A. albopictus', const Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '0-12h',
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 11),
            ),
            const SizedBox(width: 12),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFB0BEC5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '12h+',
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'No Internet Connection',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The pinpoint map requires an active internet connection to load map tiles and real-time crowd-sourced sightings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initMapData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SightingMarker extends StatefulWidget {
  final Sighting sighting;

  const SightingMarker({super.key, required this.sighting});

  @override
  State<SightingMarker> createState() => _SightingMarkerState();
}

class _SightingMarkerState extends State<SightingMarker> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.sighting.ageInMinutes < 15) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ageHours = widget.sighting.ageInMinutes / 60.0;

    // Green Theme Logic
    Color baseColor;
    if (widget.sighting.species == Species.aegypti) {
      baseColor = const Color(0xFF2ECC71); // Main Green
    } else {
      baseColor = const Color(0xFFF59E0B); // Warm Amber
    }

    double opacity = 1.0;
    Color finalColor = baseColor;

    if (ageHours <= 12) {
      opacity = 1.0;
    } else {
      opacity = 0.5;
      finalColor = const Color(0xFFB0BEC5); // Light Gray
    }

    Widget marker = Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: finalColor.withOpacity(opacity * 0.4),
              border: Border.all(color: finalColor.withOpacity(opacity), width: 2),
              boxShadow: opacity > 0.5
                  ? [
                      BoxShadow(
                        color: finalColor.withOpacity(opacity * 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
          ),
          if (widget.sighting.isOwnSighting)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
        ],
      ),
    );

    if (widget.sighting.ageInMinutes < 15) {
      return RepaintBoundary(
        child: ScaleTransition(scale: _scaleAnimation, child: marker),
      );
    } else {
      return RepaintBoundary(child: marker);
    }
  }
}
