import 'package:flutter/material.dart';
import 'dengue_lens_info.dart';
import 'widgets/Historypage/history_header.dart';
import 'widgets/Historypage/history_search_bar.dart';
import 'widgets/Historypage/history_filter_bar.dart';
import 'widgets/Historypage/scan_list.dart';

class DengueLensHistory extends StatelessWidget {
  const DengueLensHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8), // Ghost White
      body: SafeArea(
        child: Column(
          children: const [
            HistoryHeader(),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: HistorySearchBar(),
            ),
            SizedBox(height: 16),
            HistoryFilterBar(),
            SizedBox(height: 16),
            Expanded(child: ScanList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF00FF00), // Vibrant Green
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: Colors.black),
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
              MaterialPageRoute(builder: (context) => const DengueLensInfo()),
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history, color: Color(0xFF2ECC71)),
            label: 'History',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
        ],
      ),
    );
  }
}
