import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/prediction_result.dart';
import '../services/history_service.dart';
import '../services/tflite_service.dart';
import '../models/scan_record.dart';
import 'result_screen.dart';
import 'dengue_lens_info.dart';
import 'symptom_questionnaire_screen.dart';
import 'point_map_screen.dart';

class DengueLensHistory extends StatefulWidget {
  const DengueLensHistory({super.key});

  @override
  State<DengueLensHistory> createState() => _DengueLensHistoryState();
}

class _DengueLensHistoryState extends State<DengueLensHistory> {
  bool _scanning = false;

  /// Returns the bounding box of the highest-priority detection.
  Rect? _primaryBoundingBox(PredictionResult prediction) {
    final detections = prediction.detections;
    if (detections.isEmpty) return null;
    final vectors = detections.where((d) => d.isDengueVector).toList();
    if (vectors.isNotEmpty) {
      vectors.sort((a, b) => b.confidence.compareTo(a.confidence));
      return vectors.first.boundingBox;
    }
    final sorted = List<Detection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return sorted.first.boundingBox;
  }

  Future<void> _captureImageFromCamera() async {
    if (_scanning) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;

      setState(() => _scanning = true);
      try {
        final prediction = await TfliteService().predict(File(photo.path));
        final isPositive = prediction.isDengueVector;
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                imagePath: File(photo.path),
                testDate: DateTime.now(),
                result: isPositive ? 'positive' : 'negative',
                confidence: prediction.confidence,
                sampleType: 'Mosquito Image',
                mosquitoType: prediction.displayName,
                boundingBox: _primaryBoundingBox(prediction),
                detections: prediction.detections,
                imageSize: prediction.imageSize,
                savedDetectionCount: prediction.detections.length,
              ),
            ),
          );
          // Refresh history list after returning
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Prediction failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _scanning = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      body: SafeArea(
        child: Column(
          children: const [
            HistoryHeader(),
            SizedBox(height: 16),
            Expanded(child: ScanList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImageFromCamera,
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'New Scan',
        child: _scanning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.camera_alt, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F5E9),
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PointMapScreen()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SymptomQuestionnaireScreen(
                  mosquitoType: 'Unknown mosquito',
                ),
              ),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DengueLensInfo()),
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF2ECC71)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF2ECC71)),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Point Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            label: 'Risk Assessment',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
        ],
      ),
    );
  }
}


class HistoryHeader extends StatelessWidget {
  const HistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Scan History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class HistoryFilterBar extends StatelessWidget {
  const HistoryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: const [
          _FilterChip(label: 'Mosquito Scans', isSelected: true),
          SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF00FF00) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ScanList extends StatefulWidget {
  const ScanList({super.key});

  @override
  State<ScanList> createState() => _ScanListState();
}

class _ScanListState extends State<ScanList> {
  @override
  Widget build(BuildContext context) {
    final records = HistoryService().records;
    if (records.isEmpty) {
      return const Center(
        child: Text(
          'No scan history yet.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return ScanCard(
          record: record,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  result: record.result.toLowerCase().contains('dengue vector') &&
                          !record.result.toLowerCase().contains('not')
                      ? 'positive'
                      : 'negative',
                  confidence: record.confidence,
                  sampleType: 'Captured Image',
                  mosquitoType: record.mosquitoType,
                  testDate: record.date,
                  imagePath: record.imageFile,
                  isFromHistory: true,
                  savedDetectionCount: record.detectionCount,
                  detections: record.detections,
                  imageSize: (record.imageWidth != null && record.imageHeight != null) 
                      ? Size(record.imageWidth!, record.imageHeight!) 
                      : null,
                ),
              ),
            );
            // Refresh in case changes were made
            setState(() {});
          },
        );
      },
    );
  }
}

class DateHeader extends StatelessWidget {
  final String title;

  const DateHeader({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class ScanCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onTap;

  const ScanCard({super.key, required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mosquitoLower = record.mosquitoType.toLowerCase();
    final isAegypti = mosquitoLower.contains('aegypti');
    final isAlbopictus = mosquitoLower.contains('albopictus');
    final isHighRisk = isAegypti; // Aedes aegypti = High Risk
    final isModerateRisk = isAlbopictus; // Aedes albopictus = Low Risk
    final badgeBg = isHighRisk
        ? const Color(0xFFFFE5E5)
        : isModerateRisk
        ? const Color(0xFFFFF8E1) // amber tint for low risk
        : const Color(0xFFE8F5E9);
    final badgeFg = isHighRisk
        ? const Color(0xFFC62828)
        : isModerateRisk
        ? const Color(0xFFF57F17) // amber/orange for low risk
        : const Color(0xFF2E7D32);
    final badgeText = isHighRisk
        ? 'HIGH RISK'
        : isModerateRisk
        ? 'MODERATE RISK'
        : 'NOT A VECTOR';

    final dateLabel = DateFormat('MMMM d, yyyy • h:mm a').format(record.date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFE0E0E0),
                      child: record.imageFile != null
                          ? Image.file(
                              record.imageFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Icon(
                                Icons.broken_image,
                                color: Colors.grey[400],
                              ),
                            )
                          : Icon(
                              Icons.pest_control_outlined,
                              size: 40,
                              color: Colors.brown.withValues(alpha: 0.35),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 88),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.mosquitoType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.result,
                            style: TextStyle(
                              color: isHighRisk
                                  ? Colors.red[700]
                                  : const Color(0xFF2E7D32),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 15,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
