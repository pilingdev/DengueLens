import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

///Wraps the mosquito-species TFLite model.
///Call [init] once (e.g. in main()) before using [predict].
class TfliteService {
  //Singleton
  static final TfliteService _instance = TfliteService._internal();
  factory TfliteService() => _instance;
  TfliteService._internal();

  //State
  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;

  // MobileNetV2 expects 224 × 224 RGB input
  static const int _inputSize = 224;

  //Initialisation

  ///Load the model and label list from Flutter assets.
  Future<void> init() async {
    if (_initialized) return;

    // Load model bytes from bundled asset
    final modelData = await rootBundle.load('Model/model.tflite');
    final buffer = modelData.buffer;
    _interpreter = Interpreter.fromBuffer(
      buffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes),
    );

    // Load labels (one per line)
    final labelRaw = await rootBundle.loadString('Model/labels.txt');
    _labels = labelRaw
        .split(RegExp(r'[\r\n]+'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    _initialized = true;
  }

  //Inference

  ///Run inference on [imageFile].
  ///
  ///Returns a [PredictionResult] with the top-1 label and confidence (0–1).
  Future<PredictionResult> predict(File imageFile) async {
    assert(_initialized, 'TfliteService not initialized – call init() first.');

    // 1️⃣  Read & pre-process image
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Could not decode image: ${imageFile.path}');
    }

    // Resize to model input size
    final resized = img.copyResize(
      original,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Use a small ensemble of augmented images to improve confidence.
    // This can help stabilize predictions for slightly different orientations.
    final augmentedImages = <img.Image>[
      resized,
      img.flipHorizontal(resized),
      img.copyRotate(resized, angle: 90),
    ];

    // 2️⃣  Allocate output tensor [1, numClasses] ------------------------------
    final numClasses = _labels.length;
    final accumulatedScores = List.filled(numClasses, 0.0);

    // Run inference on each augmentation and accumulate logits.
    for (final aug in augmentedImages) {
      final input = _buildInputTensor(aug);
      final output = List.generate(1, (_) => List.filled(numClasses, 0.0));
      _interpreter.run(input, output);
      for (var i = 0; i < numClasses; i++) {
        accumulatedScores[i] += output[0][i];
      }
    }

    // Average logits across augmentations
    for (var i = 0; i < numClasses; i++) {
      accumulatedScores[i] = accumulatedScores[i] / augmentedImages.length;
    }

    // 4️⃣  Post-process: apply softmax -----------------------------------------
    final softmaxed = _softmax(accumulatedScores);

    // Build sorted map
    final results = <String, double>{
      for (int i = 0; i < _labels.length; i++) _labels[i]: softmaxed[i],
    };
    results.removeWhere((k, _) => k.isEmpty);

    // Sort descending
    final sorted = Map.fromEntries(
      results.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    final topLabel = sorted.keys.first;
    final topConf = sorted.values.first;

    return PredictionResult(
      label: topLabel,
      confidence: topConf,
      allScores: sorted,
    );
  }

  List<List<List<List<double>>>> _buildInputTensor(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<double> _softmax(List<double> scores) {
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final exps = scores.map((s) => math.exp(s - maxScore)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  List<String> get labels => List.unmodifiable(_labels);
  bool get isInitialized => _initialized;
}

// ── Result Model ─────────────────────────────────────────────────────────────

class PredictionResult {
  /// Top-1 species label (e.g. "albopictus", "anopheles", "culex")
  final String label;

  /// Confidence score in [0, 1]
  final double confidence;

  /// All label → score pairs, sorted descending
  final Map<String, double> allScores;

  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.allScores,
  });

  /// Human-friendly species names
  String get displayName {
    switch (label.toLowerCase()) {
      case 'albopictus':
        return 'Aedes albopictus';
      case 'anopheles':
        return 'Anopheles sp.';
      case 'culex':
        return 'Culex sp.';
      default:
        return label;
    }
  }

  /// Whether this species is known to be a dengue vector
  bool get isDengueVector => label.toLowerCase() == 'albopictus';

  /// Dengue risk level
  String get dengueRisk {
    if (isDengueVector) return 'positive';
    return 'negative';
  }
}
