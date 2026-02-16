import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dengue_lens_history.dart';
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
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // TODO: Handle the picked image (e.g., upload to server, display in UI)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image selected: ${image.name}')),
          );
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
                      ScanButton(
                        onTap: () {
                          // TODO: Implement scan action
                        },
                      ),

                      const SizedBox(height: 24),

                      // Secondary Action - Upload
                      UploadButton(onPressed: _pickImageFromGallery),

                      const SizedBox(height: 40),

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
