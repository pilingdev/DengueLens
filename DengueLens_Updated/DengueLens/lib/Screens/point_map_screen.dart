import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/sighting_model.dart';
import '../services/history_service.dart';

class PointMapScreen extends StatefulWidget {
  const PointMapScreen({super.key});

  @override
  State<PointMapScreen> createState() => _PointMapScreenState();
}

class _PointMapScreenState extends State<PointMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  final LatLng _userLocation = const LatLng(3.1390, 101.6869);

  late List<Sighting> _sightings;

  @override
  void initState() {
    super.initState();
    _sightings = _loadSightings();
  }

  List<Sighting> _loadSightings() {
    final records = HistoryService().records;
    final List<Sighting> sightings = [];
    final random = math.Random();
    
    for (final record in records) {
      final mosquitoLower = record.mosquitoType.toLowerCase();
      Species? species;
      if (mosquitoLower.contains('aegypti')) {
        species = Species.aegypti;
      } else if (mosquitoLower.contains('albopictus')) {
        species = Species.albopictus;
      }
      
      if (species != null) {
        // Use real location if available, otherwise mock an offset from _userLocation
        LatLng loc = _userLocation;
        if (record.location != null && record.location!.contains(',')) {
          try {
            final parts = record.location!.split(',');
            loc = LatLng(double.parse(parts[0]), double.parse(parts[1]));
          } catch (e) {
            // fallback to _userLocation
          }
        } else {
          // generate a small random offset around user location if no location
          final latOffset = (random.nextDouble() - 0.5) * 0.002;
          final lngOffset = (random.nextDouble() - 0.5) * 0.002;
          loc = LatLng(_userLocation.latitude + latOffset, _userLocation.longitude + lngOffset);
        }
        
        // Mock distance and bearing since we don't have real distance calc yet
        final distance = random.nextDouble() * 100 + 10; // 10-110m
        final bearings = ['NW', 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W'];
        final bearing = bearings[random.nextInt(bearings.length)];
        
        sightings.add(Sighting(
          id: record.id,
          species: species,
          location: loc,
          timestamp: record.date,
          distance: distance,
          bearing: bearing,
        ));
      }
    }
    return sightings;
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
    int activeClusters = _sightings
        .where((s) => s.ageInMinutes < 24 * 60)
        .length;
    int recentSightings = _sightings
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
              initialCenter: _userLocation,
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

              // Range Rings
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userLocation,
                    color: const Color(0xFF2ECC71).withOpacity(0.05),
                    borderColor: const Color(0xFF2ECC71).withOpacity(0.3),
                    borderStrokeWidth: 1.5,
                    radius: 100, // 100m ring
                    useRadiusInMeter: true,
                  ),
                  CircleMarker(
                    point: _userLocation,
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
                    point: _userLocation,
                    width: 14,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2ECC71).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Sighting Markers (Heat Zones)
              MarkerLayer(
                markers: _sightings.map((sighting) {
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

          // Tactical Summary Header
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9), // Glassmorphism white
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
                      color: const Color(0xFF2ECC71), // Brand Green
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Permanent Bottom Legend (Green & White Theme)
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
                    _buildLegendItem(
                      'A. aegypti',
                      const Color(0xFF2ECC71),
                    ), // Main Green
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    _buildLegendItem(
                      'A. albopictus',
                      const Color(0xFFF59E0B),
                    ), // Warm Amber
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
              ), // Light Grey
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
}

class SightingMarker extends StatefulWidget {
  final Sighting sighting;

  const SightingMarker({super.key, required this.sighting});

  @override
  State<SightingMarker> createState() => _SightingMarkerState();
}

class _SightingMarkerState extends State<SightingMarker>
    with SingleTickerProviderStateMixin {
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
      child: Container(
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
