import 'package:flutter/material.dart';
import 'Screens/dengue_lens_home.dart';

void main() {
  runApp(const DengueLensApp());
}

class DengueLensApp extends StatelessWidget {
  const DengueLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue Lens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto', // Default, but explicit is good.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2ECC71),
          brightness: Brightness.light,
        ),
      ),
      home: const DengueLensHome(),
    );
  }
}
