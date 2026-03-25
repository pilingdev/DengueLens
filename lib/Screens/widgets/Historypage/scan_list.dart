import 'package:flutter/material.dart';
import 'date_header.dart';
import 'scan_card.dart';

class ScanList extends StatelessWidget {
  const ScanList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: const [DateHeader(title: 'TODAY')],
    );
  }
}
