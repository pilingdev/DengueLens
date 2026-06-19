import 'package:flutter/material.dart';
import 'Screens/dengue_lens_home.dart';
import 'services/tflite_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/history_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Sign in anonymously for Firebase Firestore rules
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint("Failed to sign in anonymously: $e");
  }

  // Pre-load the TFLite model once so inference is fast
  await TfliteService().init();
  await Hive.initFlutter();
  await HistoryService().init();
  runApp(const DengueLensApp());
}

class DengueLensApp extends StatelessWidget {
  const DengueLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue Lens – Dengue Vector Detection',
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
