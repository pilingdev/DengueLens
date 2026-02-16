import 'package:flutter/material.dart';
import 'date_header.dart';
import 'scan_card.dart';

class ScanList extends StatelessWidget {
  const ScanList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: const [
        DateHeader(title: 'TODAY'),
        ScanCard(
          speciesName: 'Aedes aegypti',
          description: 'Potential Dengue Carrier',
          date: 'Oct 24, 2023 • 2:30 PM',
          riskLevel: 'HIGH RISK',
          riskColor: Color(0xFFFFCDD2), // Light Red
          riskTextColor: Color(0xFFD32F2F), // Dark Red
        ),
        ScanCard(
          speciesName: 'Culex mosquito',
          description: 'Common household mosquito',
          date: 'Oct 24, 2023 • 9:15 AM',
          riskLevel: 'LOW RISK',
          riskColor: Color(0xFFC8E6C9), // Light Green
          riskTextColor: Color(0xFF388E3C), // Dark Green
        ),
        SizedBox(height: 80), // Space for FAB
      ],
    );
  }
}
