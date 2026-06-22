import 'package:flutter/material.dart';

class EducationalLibraryScreen extends StatelessWidget {
  const EducationalLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Educational Library',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'manual_educational_library',
        onPressed: () {
          // TODO: Implement user manual navigation
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.menu_book, color: Color(0xFF2ECC71)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('Mosquito Species'),
          _buildCard(
            title: 'Aedes aegypti',
            content:
                'The primary vector of dengue. It is a small, dark mosquito with white lyre-shaped markings and banded legs. They typically bite during the day, particularly early morning and late afternoon.',
            icon: Icons.bug_report,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Aedes albopictus',
            content:
                'A secondary vector of dengue, also known as the Asian tiger mosquito. It has a single white stripe down the center of its head and back. It can survive in cooler, temperate regions.',
            icon: Icons.bug_report_outlined,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Culex spp.',
            content:
                'Often found around houses. They usually bite at night. While they can transmit diseases like West Nile virus and Japanese encephalitis, they are not vectors for dengue.',
            icon: Icons.bug_report_outlined,
            color: Colors.brown,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Anopheles spp.',
            content:
                'Primarily known as the vector for malaria. They typically bite between dusk and dawn. Like Culex, they are not a risk for dengue transmission.',
            icon: Icons.bug_report_outlined,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Dengue Symptoms'),
          _buildCard(
            title: 'Common Symptoms',
            content:
                '• High fever (40°C/104°F)\n• Severe headache\n• Pain behind the eyes\n• Muscle and joint pains\n• Nausea and vomiting\n• Swollen glands\n• Rash',
            icon: Icons.sick,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Severe Dengue Warning Signs',
            content:
                '• Severe abdominal pain\n• Persistent vomiting\n• Rapid breathing\n• Bleeding gums or nose\n• Fatigue, restlessness\n• Blood in vomit or stool\n\nSeek immediate medical attention if these occur.',
            icon: Icons.warning,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Prevention Guidelines'),
          _buildCard(
            title: 'Prevent Mosquito Bites',
            content:
                '• Use mosquito repellents containing DEET, Picaridin, or IR3535.\n• Wear long-sleeved shirts and long pants.\n• Use mosquito nets if sleeping during the day or in unscreened rooms.',
            icon: Icons.health_and_safety,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildCard(
            title: 'Eliminate Breeding Sites',
            content:
                '• Cover, empty, or clean domestic water storage containers on a weekly basis.\n• Dispose of solid waste properly and remove artificial man-made habitats.\n• Apply appropriate insecticides to water storage outdoor containers.',
            icon: Icons.cleaning_services,
            color: Colors.teal,
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('About'),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Dengue Lens helps identify potential dengue vectors from photos and supports follow-up risk assessment.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
