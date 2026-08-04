import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prediction_result.dart';
import '../services/tflite_service.dart';

// ─── Sealed state ────────────────────────────────────────────────────────────

/// Represents every possible state of a mosquito-scan operation.
sealed class ScanState {
  const ScanState();
}

/// No scan is running; app is at rest.
class ScanIdle extends ScanState {
  const ScanIdle();
}

/// Inference is running. [imagePath] is shown in the loading overlay.
class ScanProcessing extends ScanState {
  final String imagePath;
  const ScanProcessing(this.imagePath);
}

/// Inference finished successfully.
class ScanDone extends ScanState {
  final PredictionResult result;
  final File imageFile;
  const ScanDone({required this.result, required this.imageFile});
}

/// Inference failed with an [error] message.
class ScanError extends ScanState {
  final String error;
  const ScanError(this.error);
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Drives the scan pipeline. Screens call [runScan] and react to state changes.
class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(const ScanIdle());

  /// Runs the TFLite inference pipeline on [imageFile].
  ///
  /// Image preprocessing and NMS happen inside a background Isolate
  /// (see [TfliteService.predict]), so this future resolves without
  /// blocking the UI thread.
  Future<void> runScan(File imageFile) async {
    if (state is ScanProcessing) return; // Guard: no concurrent scans

    state = ScanProcessing(imageFile.path);
    try {
      final result = await TfliteService().predict(imageFile);
      state = ScanDone(result: result, imageFile: imageFile);
    } catch (e) {
      state = ScanError(e.toString());
    }
  }

  /// Resets to idle so the home screen can accept the next scan.
  void reset() => state = const ScanIdle();
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Global provider – one instance for the entire app lifecycle.
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
