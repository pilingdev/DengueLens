import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Screens/dengue_lens_home.dart';
import 'services/tflite_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/history_service.dart';
import 'services/tutorial_service.dart';
import 'services/upload_queue_service.dart';
import 'services/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Sign in anonymously so Firestore security rules can allow writes.
  // If it fails (no network / provider disabled) we continue – the app works
  // offline and the upload queue will re-auth when connectivity is restored.
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('Anonymous sign-in failed (non-fatal): $e');
  }

  // ── Local storage ─────────────────────────────────────────────────────────
  await Hive.initFlutter();
  await HistoryService().init();
  await TutorialService().init();

  // ── TFLite model ──────────────────────────────────────────────────────────
  // Wrapped in try/catch so a corrupted asset doesn't crash the process.
  // The home screen checks [TfliteService.isInitialized] and shows an error
  // banner if the model failed to load.
  bool modelReady = false;
  try {
    await TfliteService().init();
    modelReady = true;
  } catch (e) {
    debugPrint('TFLite init failed: $e');
  }

  // ── Connectivity + offline upload queue ──────────────────────────────────
  ConnectivityService().init();
  await UploadQueueService().init();

  // ── Launch ────────────────────────────────────────────────────────────────
  // ProviderScope is the root of the Riverpod dependency tree. Every
  // ConsumerWidget / ConsumerStatefulWidget in the app reads providers
  // through this scope. There is zero runtime overhead compared to plain
  // StatefulWidget – providers are lazy by default and only compute when
  // first watched.
  runApp(
    ProviderScope(
      child: DengueLensApp(modelReady: modelReady),
    ),
  );
}

class DengueLensApp extends StatelessWidget {
  final bool modelReady;
  const DengueLensApp({super.key, required this.modelReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue Lens – Dengue Vector Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2ECC71),
          brightness: Brightness.light,
        ),
      ),
      home: DengueLensHome(modelReady: modelReady),
    );
  }
}
