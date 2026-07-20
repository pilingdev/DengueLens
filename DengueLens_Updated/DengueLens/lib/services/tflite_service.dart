import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import '../models/prediction_result.dart';
import '../utils/image_utils.dart';

///Wraps the mosquito-species TFLite model.
///Call [init] once (e.g. in main()) before using [predict].
class TfliteService {
  //Singleton
  static final TfliteService _instance = TfliteService._internal();
  factory TfliteService() => _instance;
  TfliteService._internal();

  //State
  late Interpreter _detectorInterpreter;
  late Interpreter _classifierInterpreter;
  late List<String> _detectorLabels;
  late List<String> _classifierLabels;
  bool _initialized = false;

  /// True when output shape is [1, anchors, channels] instead of [1, channels, anchors].
  late bool _outputAnchorMajor;
  late int _numAnchors;
  late int _numChannels;

  // YOLOv8 expects 640 × 640 RGB input
  static const int _inputSize = 640;

  /// Maximum number of mosquitoes to detect and classify per image (1–3).
  /// Detection stops as soon as this many confirmed mosquitoes are found.
  static const int _maxDetections = 3;

  //Initialisation

  ///Load the models and label lists from Flutter assets.
  /// Initializes the TFLite interpreters and loads model assets.
  /// Should be called once during app startup before any predictions.
  Future<void> init() async {
    if (_initialized) return;

    // 1. Load YOLOv8 detector model bytes
    final detectorData = await rootBundle.load('Model/yolov8n_detector.tflite');
    _detectorInterpreter = Interpreter.fromBuffer(
      detectorData.buffer.asUint8List(detectorData.offsetInBytes, detectorData.lengthInBytes),
    );

    // 2. Load MobileNetV3-Small classifier model bytes
    final classifierData = await rootBundle.load('Model/mobilenetv3_mosquito_classifier.tflite');
    _classifierInterpreter = Interpreter.fromBuffer(
      classifierData.buffer.asUint8List(classifierData.offsetInBytes, classifierData.lengthInBytes),
    );

    // 3. Load detector labels (usually 1-class: "Mosquito")
    final detectorLabelsRaw = await rootBundle.loadString('Model/labels_detector.txt');
    _detectorLabels = detectorLabelsRaw
        .split(RegExp(r'[\r\n]+'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    // 4. Load classifier labels (5-class: species + non-mosquito)
    final classifierLabelsRaw = await rootBundle.loadString('Model/labels_classifier.txt');
    _classifierLabels = classifierLabelsRaw
        .split(RegExp(r'[\r\n]+'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    // Configure detector output shape
    final outShape = _detectorInterpreter.getOutputTensors().first.shape;
    if (outShape.length >= 3) {
      _outputAnchorMajor = outShape[1] > outShape[2];
      _numAnchors = _outputAnchorMajor ? outShape[1] : outShape[2];
      _numChannels = _outputAnchorMajor ? outShape[2] : outShape[1];
    } else {
      _outputAnchorMajor = false;
      _numAnchors = 8400;
      _numChannels = 4 + _detectorLabels.length;
    }

    _initialized = true;
  }

  double _readOutput(List<dynamic> output, int channel, int anchor) {
    return _outputAnchorMajor
        ? (output[0][anchor][channel] as num).toDouble()
        : (output[0][channel][anchor] as num).toDouble();
  }

  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  double _ensureProbability(double value) {
    return (value < 0.0 || value > 1.0) ? _sigmoid(value) : value;
  }

  /// Some TFLite exports use 0–1 coords; others use 640px input space.
  double _toInputPixels(double value, int targetSize) {
    if (value > 0 && value <= 1.0) return value * targetSize;
    return value;
  }

  //Inference

  ///Run two-stage inference on [imageFile].
  ///
  ///Returns a [PredictionResult] containing the classified detections.
  Future<PredictionResult> predict(File imageFile) async {
    assert(_initialized, 'TfliteService not initialized – call init() first.');

    // 1️⃣ Read & decode original image
    final bytes = await imageFile.readAsBytes();
    img.Image? original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Could not decode image: ${imageFile.path}');
    }
    // Bake EXIF orientation so width/height match the visual presentation
    original = img.bakeOrientation(original);

    // 2️⃣ Stage 1: Detector Input Processing (Letterboxing)
    final int targetSize = _inputSize;
    final double ratio = targetSize / math.max(original.width, original.height);
    final int newUnpadW = (original.width * ratio).round();
    final int newUnpadH = (original.height * ratio).round();

    final resized = img.copyResize(
      original,
      width: newUnpadW,
      height: newUnpadH,
      interpolation: img.Interpolation.linear,
    );

    // Create padded image with gray background (114, 114, 114)
    final padded = img.Image(width: targetSize, height: targetSize);
    img.fill(padded, color: img.ColorRgb8(114, 114, 114));

    // Calculate padding offsets
    final int dx = ((targetSize - newUnpadW) / 2).round();
    final int dy = ((targetSize - newUnpadH) / 2).round();

    // Paste resized image into the center
    img.compositeImage(padded, resized, dstX: dx, dstY: dy);

    final numChannels = _numChannels;
    final numAnchors = _numAnchors;

    final input = imageToInputTensor(padded);

    final List<dynamic> output = _outputAnchorMajor
        ? List.generate(
            1,
            (_) =>
                List.generate(numAnchors, (_) => List.filled(numChannels, 0.0)),
          )
        : List.generate(
            1,
            (_) =>
                List.generate(numChannels, (_) => List.filled(numAnchors, 0.0)),
          );

    // Run YOLO detector
    _detectorInterpreter.run(input, output);

    // Dynamically detect YOLO version and number of detector classes:
    // YOLOv8 uses 4 coords (no objectness). YOLOv5 uses 5 coords (includes objectness).
    final bool hasObjectness = numChannels == 6 || numChannels == 10;
    final int classOffset = hasObjectness ? 5 : 4;
    final int yoloClasses = numChannels - classOffset;

    final double confidenceThreshold = 0.20;
    final List<Detection> rawDetections = [];
    final imgW = original.width.toDouble();
    final imgH = original.height.toDouble();

    debugPrint('═══ TfliteService DETECTOR INFERENCE ═══');
    debugPrint('Output shape: anchors=$numAnchors, channels=$numChannels, '
        'anchorMajor=$_outputAnchorMajor, hasObjectness=$hasObjectness');
    debugPrint('Detector Classes count in model: $yoloClasses');
    debugPrint('Confidence threshold: $confidenceThreshold');

    // Parse detector bounding boxes
    for (var anchor = 0; anchor < numAnchors; anchor++) {
      final double objectness = hasObjectness
          ? _ensureProbability(_readOutput(output, 4, anchor))
          : 1.0;

      double maxClassScore = -1.0;

      for (var cls = 0; cls < yoloClasses; cls++) {
        final double classScore = _ensureProbability(
          _readOutput(output, classOffset + cls, anchor),
        );
        final double combinedScore = objectness * classScore;

        if (combinedScore > maxClassScore) {
          maxClassScore = combinedScore;
        }
      }

      if (maxClassScore > confidenceThreshold) {
        double cx = _toInputPixels(_readOutput(output, 0, anchor), targetSize);
        double cy = _toInputPixels(_readOutput(output, 1, anchor), targetSize);
        double w = _toInputPixels(_readOutput(output, 2, anchor), targetSize);
        double h = _toInputPixels(_readOutput(output, 3, anchor), targetSize);

        double origCx = (cx - dx) / ratio;
        double origCy = (cy - dy) / ratio;
        double origW = w / ratio;
        double origH = h / ratio;

        double left = origCx - (origW / 2);
        double top = origCy - (origH / 2);

        left = left.clamp(0.0, imgW);
        top = top.clamp(0.0, imgH);
        final right = (left + origW).clamp(0.0, imgW);
        final bottom = (top + origH).clamp(0.0, imgH);

        rawDetections.add(
          Detection(
            label: 'Mosquito', // General label for detection stage
            confidence: maxClassScore,
            boundingBox: Rect.fromLTRB(left, top, right, bottom),
          ),
        );
      }
    }

    debugPrint('Raw detector detections (before NMS): ${rawDetections.length}');

    // Apply Non-Maximum Suppression (NMS) on detector boxes
    final List<Detection> nmsDetections = [];
    rawDetections.sort((a, b) => b.confidence.compareTo(a.confidence));

    for (final det in rawDetections) {
      bool keep = true;
      for (final nmsDet in nmsDetections) {
        final intersect = det.boundingBox.intersect(nmsDet.boundingBox);
        if (intersect.width > 0 && intersect.height > 0) {
          final interArea = intersect.width * intersect.height;
          final unionArea =
              (det.boundingBox.width * det.boundingBox.height) +
              (nmsDet.boundingBox.width * nmsDet.boundingBox.height) -
              interArea;
          final iou = interArea / unionArea;
          if (iou > 0.45) {
            keep = false;
            break;
          }
        }
      }
      if (keep) {
        nmsDetections.add(det);
      }
    }

    debugPrint('Detector detections (after NMS): ${nmsDetections.length}');

    // Cap to top-N boxes (already sorted highest-confidence first by NMS).
    // This avoids running the classifier on more boxes than we will ever report.
    final cappedDetections = nmsDetections.take(_maxDetections).toList();
    debugPrint('Capped to max $_maxDetections: ${cappedDetections.length} box(es) will be classified');

    // 3️⃣ Stage 2: Classifier Inference (MobileNetV3)
    final List<Detection> finalSpeciesDetections = [];
    debugPrint('═══ TfliteService CLASSIFIER INFERENCE ═══');

    for (var i = 0; i < cappedDetections.length; i++) {
      final det = cappedDetections[i];

      // Hard stop: we already have the maximum number of confirmed detections.
      if (finalSpeciesDetections.length >= _maxDetections) break;
      final box = det.boundingBox;

      final int x = box.left.round();
      final int y = box.top.round();
      final int w = box.width.round();
      final int h = box.height.round();

      if (w <= 0 || h <= 0) continue;

      // A. Crop the mosquito bounding box from the original high-resolution image
      final crop = img.copyCrop(
        original,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      // B. Resize crop to 224x224 for MobileNetV3-Small
      final resizedCrop = img.copyResize(
        crop,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // C. Convert cropped image to input tensor float values in range [0, 255]
      final classifierInput = imageToClassifierInputTensor(resizedCrop);

      // D. Run classification
      final List<List<double>> classifierOutput = List.generate(
        1,
        (_) => List.filled(_classifierLabels.length, 0.0),
      );
      _classifierInterpreter.run(classifierInput, classifierOutput);

      // E. Parse classification results
      final probs = classifierOutput[0];
      int bestClsIdx = 0;
      double maxProb = -1.0;
      for (int c = 0; c < probs.length; c++) {
        if (probs[c] > maxProb) {
          maxProb = probs[c];
          bestClsIdx = c;
        }
      }

      final String speciesLabel = _classifierLabels[bestClsIdx];

      // F. Filter out false positive "Non-Mosquito" detections
      if (speciesLabel.toLowerCase() == 'non-mosquito') {
        debugPrint('  Rejecting box $i: Classified as Non-Mosquito (confidence: ${(maxProb * 100).toStringAsFixed(1)}%)');
        continue;
      }

      // Use only the classifier confidence score as requested
      final double jointConfidence = maxProb;

      debugPrint('  Accepting box $i: Classified as $speciesLabel '
          '(detectorScore=${(det.confidence * 100).toStringAsFixed(1)}%, '
          'classifierScore=${(maxProb * 100).toStringAsFixed(1)}%)');

      finalSpeciesDetections.add(
        Detection(
          label: speciesLabel,
          confidence: jointConfidence,
          boundingBox: box,
        ),
      );
    }

    debugPrint('Final species detections count: ${finalSpeciesDetections.length}');
    debugPrint('═══════════════════════════════');

    final imageSize = Size(
      original.width.toDouble(),
      original.height.toDouble(),
    );

    return PredictionResult(detections: finalSpeciesDetections, imageSize: imageSize);
  }

  List<String> get labels => List.unmodifiable(_classifierLabels);
  bool get isInitialized => _initialized;
}
