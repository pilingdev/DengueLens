import 'package:flutter/material.dart';
import 'Screens/dengue_lens_home.dart';
import 'services/tflite_service.dart';
// import 'Screens/dengue_lens_history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load the TFLite model once so inference is fast
  await TfliteService().init();
  runApp(const DengueLensApp());
}

class DengueLensApp extends StatelessWidget {
  const DengueLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue Lens 1',
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
