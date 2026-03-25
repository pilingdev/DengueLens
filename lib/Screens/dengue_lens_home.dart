import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dengue_lens_history.dart';
import 'result_screen.dart';
import 'widgets/homepage/home_header.dart';
import 'widgets/homepage/hero_section.dart';
import 'widgets/homepage/scan_button.dart';
import 'widgets/homepage/upload_button.dart';
import 'widgets/homepage/health_tip_card.dart';
import 'widgets/homepage/daily_tip_card.dart';

class DengueLensHome extends StatefulWidget {
  const DengueLensHome({super.key});

  @override
  State<DengueLensHome> createState() => _DengueLensHomeState();
}

class _DengueLensHomeState extends State<DengueLensHome> {
  Future<void> _pickImageFromGallery() async {
    try {
      // Use file_picker for better Windows desktop support
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        dialogTitle: 'Select an image',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileExtension = filePath.split('.').last.toLowerCase();
        final supportedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

        if (supportedFormats.contains(fileExtension)) {
          // Navigate to result screen with the picked image
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  imagePath: File(filePath),
                  testDate: DateTime.now(),
                  result:
                      "negative", // Default value, can be updated with API response
                  confidence: 0.85,
                  sampleType: "Blood Sample",
                  mosquitoType: "Aedes Albopictus",
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unsupported format. Please select JPEG, PNG, GIF or WebP',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _captureImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                imagePath: File(photo.path),
                testDate: DateTime.now(),
                result:
                    "negative", // Default value, can be updated with API response
                confidence: 0.85,
                sampleType: "Blood Sample",
                mosquitoType: "Aedes Albopictus",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Off-white/Light grey
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const HomeHeader(),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Hero Section
                      const HeroSection(),

                      const SizedBox(height: 40),

                      // Primary Action - Scan Button
                      ScanButton(onTap: () {}),

                      const SizedBox(height: 24),
                      // Secondary Action - Upload
                      UploadButton(onPressed: _pickImageFromGallery),

                      const SizedBox(height: 40),

                      // Primary Action - Scan Button
                      ScanButton(onTap: _captureImageFromCamera),

                      const SizedBox(height: 24),

                      // Bite Health Tips Section
                      HealthTipCard(
                        onReadMore: () {
                          // TODO: Implement read more
                        },
                      ),

                      const SizedBox(height: 24),

                      // Daily Tip Card
                      const DailyTipCard(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F5E9),
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DengueLensHistory(),
              ),
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
            label: 'History',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
        ],
      ),
    );
  }
}
