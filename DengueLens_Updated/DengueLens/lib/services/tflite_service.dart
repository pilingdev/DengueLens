import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import '../models/prediction_result.dart';

// ─────────────────────────────────────────────────────────────────────────
// Top-level helpers — must be top-level so they cross isolate boundaries.
// ─────────────────────────────────────────────────────────────────────────

/// Payload sent to the background preprocessing isolate.
///
/// All fields are primitive/immutable so they serialise across isolates
/// safely.
class _PreprocessPayload {
  final Uint8List imageBytes;
  final int targetSize;

  /// True when the model's input layout is NCHW [1, 3, H, W].
  /// False when NHWC [1, H, W, 3].
  final bool isNchw;

  /// True when the input tensor is actually INT8/UINT8 quantized.
  /// False when the input tensor is float32 — which is common even for
  /// "int8" YOLO exports, since Ultralytics' TFLite int8 export quantizes
  /// internal weights/activations but by default keeps the input/output
  /// boundary tensors as float32 (Quantize/Dequantize ops sit just inside
  /// the graph). Always trust the tensor's actual runtime type, never the
  /// filename or the assumption that "int8 export" means "int8 I/O".
  final bool isQuantized;

  /// Quantization scale of the input tensor (from tensor.params.scale).
  /// Only meaningful when [isQuantized] is true.
  final double scale;

  /// Quantization zero-point of the input tensor (from
  /// tensor.params.zeroPoint). Only meaningful when [isQuantized] is true.
  final int zeroPoint;

  const _PreprocessPayload({
    required this.imageBytes,
    required this.targetSize,
    required this.isNchw,
    required this.isQuantized,
    required this.scale,
    required this.zeroPoint,
  });
}

/// Result returned from the preprocessing isolate.
///
/// Exactly one of [int8Buffer] / [float32Buffer] is populated, matching
/// whatever the model's real input tensor type turned out to be.
class _PreprocessResult {
  /// Flat INT8 tensor buffer — populated only when the input tensor is
  /// quantized. Layout matches the model's native input shape.
  final Int8List? int8Buffer;

  /// Flat FLOAT32 tensor buffer — populated only when the input tensor is
  /// float32. Values are normalized to [0, 1]. Layout matches the model's
  /// native input shape.
  final Float32List? float32Buffer;

  final int dx;
  final int dy;
  final double ratio;
  final int imgW;
  final int imgH;

  const _PreprocessResult({
    this.int8Buffer,
    this.float32Buffer,
    required this.dx,
    required this.dy,
    required this.ratio,
    required this.imgW,
    required this.imgH,
  });
}

/// Letterboxes the image and converts pixels into the model's native input
/// buffer — either a quantized [Int8List] or a normalized [Float32List],
/// depending on [_PreprocessPayload.isQuantized].
///
/// Quantization formula (standard TFLite affine), used only when the input
/// tensor is actually INT8/UINT8:
///   q = clamp(round(normVal / scale) + zeroPoint, −128, 127)
///
/// When the input tensor is float32, pixels are simply normalized to
/// [0, 1] — no quantization math applies.
///
/// Runs entirely in a background isolate; never blocks the UI thread.
_PreprocessResult _preprocessIsolate(_PreprocessPayload payload) {
  // ── Decode & correct EXIF orientation ─────────────────────────────────
  img.Image? original = img.decodeImage(payload.imageBytes);
  if (original == null) throw Exception('Could not decode image');
  original = img.bakeOrientation(original);

  // ── Letterbox resize ───────────────────────────────────────────────────
  final int targetSize = payload.targetSize;
  final double ratio = targetSize / math.max(original.width, original.height);
  final int newUnpadW = (original.width * ratio).round();
  final int newUnpadH = (original.height * ratio).round();

  final resized = img.copyResize(
    original,
    width: newUnpadW,
    height: newUnpadH,
    interpolation: img.Interpolation.linear,
  );

  // Fill canvas with grey (114) and paste resized image centred.
  final padded = img.Image(width: targetSize, height: targetSize);
  img.fill(padded, color: img.ColorRgb8(114, 114, 114));
  final int dx = ((targetSize - newUnpadW) / 2).round();
  final int dy = ((targetSize - newUnpadH) / 2).round();
  img.compositeImage(padded, resized, dstX: dx, dstY: dy);

  final int W = padded.width; // 640
  final int H = padded.height; // 640
  const int C = 3; // RGB

  if (payload.isQuantized) {
    // ── Build the INT8 buffer ────────────────────────────────────────────
    final Int8List buffer = Int8List(1 * C * H * W);
    final double scale = payload.scale;
    final int zeroPoint = payload.zeroPoint;
    // Pre-compute 1/scale to replace division with multiplication in the
    // hot loop.
    final double invScale = (scale > 0.0) ? (1.0 / scale) : 1.0;

    if (payload.isNchw) {
      // ── NCHW: index = c*H*W + y*W + x ─────────────────────────────────
      for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
          final pixel = padded.getPixel(x, y);
          buffer[0 * H * W + y * W + x] =
              (pixel.r / 255.0 * invScale + zeroPoint).round().clamp(-128, 127);
          buffer[1 * H * W + y * W + x] =
              (pixel.g / 255.0 * invScale + zeroPoint).round().clamp(-128, 127);
          buffer[2 * H * W + y * W + x] =
              (pixel.b / 255.0 * invScale + zeroPoint).round().clamp(-128, 127);
        }
      }
    } else {
      // ── NHWC: index = y*W*C + x*C + c ─────────────────────────────────
      for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
          final pixel = padded.getPixel(x, y);
          final int base = (y * W + x) * C;
          buffer[base + 0] = (pixel.r / 255.0 * invScale + zeroPoint)
              .round()
              .clamp(-128, 127);
          buffer[base + 1] = (pixel.g / 255.0 * invScale + zeroPoint)
              .round()
              .clamp(-128, 127);
          buffer[base + 2] = (pixel.b / 255.0 * invScale + zeroPoint)
              .round()
              .clamp(-128, 127);
        }
      }
    }

    return _PreprocessResult(
      int8Buffer: buffer,
      dx: dx,
      dy: dy,
      ratio: ratio,
      imgW: original.width,
      imgH: original.height,
    );
  } else {
    // ── Build the FLOAT32 buffer (normalized to [0, 1], no quant math) ───
    final Float32List buffer = Float32List(1 * C * H * W);

    if (payload.isNchw) {
      // ── NCHW: index = c*H*W + y*W + x ─────────────────────────────────
      for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
          final pixel = padded.getPixel(x, y);
          buffer[0 * H * W + y * W + x] = pixel.r / 255.0;
          buffer[1 * H * W + y * W + x] = pixel.g / 255.0;
          buffer[2 * H * W + y * W + x] = pixel.b / 255.0;
        }
      }
    } else {
      // ── NHWC: index = y*W*C + x*C + c ─────────────────────────────────
      for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
          final pixel = padded.getPixel(x, y);
          final int base = (y * W + x) * C;
          buffer[base + 0] = pixel.r / 255.0;
          buffer[base + 1] = pixel.g / 255.0;
          buffer[base + 2] = pixel.b / 255.0;
        }
      }
    }

    return _PreprocessResult(
      float32Buffer: buffer,
      dx: dx,
      dy: dy,
      ratio: ratio,
      imgW: original.width,
      imgH: original.height,
    );
  }
}

// ─── NMS ─────────────────────────────────────────────────────────────────
class _NmsPayload {
  final List<List<double>> boxes; // [left, top, right, bottom, conf, classIdx]
  final double iouThreshold;
  const _NmsPayload(this.boxes, this.iouThreshold);
}

/// Non-Maximum Suppression. Input must be sorted by confidence descending.
/// Returns kept indices.
List<int> _nmsIsolate(_NmsPayload payload) {
  final boxes = payload.boxes;
  final double iou = payload.iouThreshold;
  final List<int> kept = [];

  for (int i = 0; i < boxes.length; i++) {
    bool suppress = false;
    for (final kIdx in kept) {
      final a = boxes[i];
      final b = boxes[kIdx];
      final iLeft = math.max(a[0], b[0]);
      final iTop = math.max(a[1], b[1]);
      final iRight = math.min(a[2], b[2]);
      final iBottom = math.min(a[3], b[3]);

      if (iRight > iLeft && iBottom > iTop) {
        final inter = (iRight - iLeft) * (iBottom - iTop);
        final union =
            (a[2] - a[0]) * (a[3] - a[1]) +
            (b[2] - b[0]) * (b[3] - b[1]) -
            inter;
        if (inter / union > iou) {
          suppress = true;
          break;
        }
      }
    }
    if (!suppress) kept.add(i);
  }
  return kept;
}

// ─────────────────────────────────────────────────────────────────────────
// TfliteService
// ─────────────────────────────────────────────────────────────────────────

/// Singleton service that wraps the YOLOv11 TFLite mosquito-detection
/// model.
///
/// Call [init] once at startup. Then call [predict] for each image.
///
/// ### Threading model
/// - Letterboxing + input conversion (INT8 quant or float32 normalize)
///   → background [Isolate] (CPU-bound)
/// - TFLite `run()` → called on the platform thread (fast native)
/// - NMS post-processing → background [Isolate] for >30 candidates
///
/// ### Important: input tensor dtype is NOT assumed
/// Ultralytics' `export(format="tflite", int8=True)` quantizes internal
/// weights/activations to int8, but commonly leaves the *boundary*
/// input/output tensors as float32 (Quantize/Dequantize ops sit just
/// inside the graph). This service always reads the input tensor's real
/// `TensorType` at init time and builds the matching buffer type
/// (Int8List vs Float32List) — never assumes "int8 export" means
/// "int8 I/O". Feeding the wrong element size into a native tensor buffer
/// corrupts the interpreter's memory arena and produces cryptic native
/// errors like `Input tensor N lacks data` on an unrelated internal
/// tensor, rather than a clear type-mismatch error.
class TfliteService {
  static final TfliteService _instance = TfliteService._internal();
  factory TfliteService() => _instance;
  TfliteService._internal();

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;

  // ── Output tensor layout ──────────────────────────────────────────────
  late bool
  _outputAnchorMajor; // true → [1, anchors, ch]; false → [1, ch, anchors]
  late int _numAnchors;
  late int _numChannels;

  // ── Input tensor metadata (discovered at init time) ───────────────────
  /// True when the model input is NCHW [1, 3, 640, 640].
  /// False when NHWC [1, 640, 640, 3].
  late bool _isNchw;

  /// True when the input tensor's real TensorType is int8/uint8.
  /// False when it's float32. Drives which preprocessing path + reshape
  /// type is used in [predict].
  late bool _inputIsQuantized;

  /// Quantization scale of the input tensor. Only meaningful when
  /// [_inputIsQuantized] is true.
  late double _inputScale;

  /// Quantization zero-point of the input tensor. Only meaningful when
  /// [_inputIsQuantized] is true.
  late int _inputZeroPoint;

  // ── Output tensor quantization ─────────────────────────────────────────
  late double _outputScale;
  late int _outputZeroPoint;
  late bool _outputIsQuantized;

  static const int _inputSize = 640;
  static const int _maxDetections = 3;

  // ─── init() ─────────────────────────────────────────────────────────────
  /// Loads the TFLite model. Throws if the asset is missing.
  ///
  /// 1. Loads `Model/yolo11/best_int8.tflite`.
  /// 2. Calls `allocateTensors()` once, with the model's native shape (no
  ///    resize) — allocating a second time at run() time is what corrupts
  ///    internal constant tensors, so [predict] must always feed a buffer
  ///    whose shape matches exactly, never triggering an implicit resize.
  /// 3. Reads input tensor shape → detects NCHW vs NHWC layout.
  /// 4. Reads the *actual* input tensor TensorType to decide whether this
  ///    model wants quantized int8 input or plain float32 input, and reads
  ///    scale + zeroPoint from both input and output tensors.
  /// 5. Loads labels and detects output layout (anchor-major vs
  ///    channel-major).
  Future<void> init() async {
    if (_initialized) return;

    // ── 1. Load model ──────────────────────────────────────────────────
    final data = await rootBundle.load('Model/yolo11/best_int8.tflite');
    final modelBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    debugPrint('TfliteService: loaded best_int8.tflite');

    _interpreter = Interpreter.fromBuffer(modelBytes);

    // ── 2. allocateTensors with the model's native shape (NO resize) ────
    // Forcing a shape mismatch via resizeInputTensor (or letting run()
    // implicitly trigger one because the fed buffer doesn't match) can
    // corrupt downstream constant tensors that were already allocated.
    _interpreter.allocateTensors();

    // ── 3. Detect input layout + real dtype + quantization params ───────
    final inTensor = _interpreter.getInputTensors().first;
    final List<int> inShape =
        inTensor.shape; // e.g. [1, 3, 640, 640] or [1, 640, 640, 3]

    // If dim[1] == 3 the model is NCHW (channels-first).
    // If dim[3] == 3 the model is NHWC (channels-last).
    _isNchw = (inShape.length == 4 && inShape[1] == 3);

    // Never assume the input is quantized just because this is an "int8
    // export" — always check the tensor's real type.
    _inputIsQuantized =
        inTensor.type == TensorType.int8 || inTensor.type == TensorType.uint8;

    final inParams = inTensor.params;
    _inputScale = inParams.scale;
    _inputZeroPoint = inParams.zeroPoint;

    debugPrint(
      'TfliteService [INPUT] '
      'shape=$inShape, '
      'type=${inTensor.type}, '
      'layout=${_isNchw ? "NCHW" : "NHWC"}, '
      'quantized=$_inputIsQuantized, '
      'scale=$_inputScale, '
      'zeroPoint=$_inputZeroPoint',
    );

    if (!_inputIsQuantized) {
      debugPrint(
        'TfliteService: NOTE — input tensor is ${inTensor.type}, not '
        'int8/uint8. This is common for Ultralytics int8 TFLite exports '
        '(internal weights are quantized, but the input/output boundary '
        'stays float32). Feeding normalized [0,1] float32 pixels instead '
        'of quantized int8 values.',
      );
    }

    // ── 4. Read output tensor quantization params ───────────────────────
    final outTensor = _interpreter.getOutputTensors().first;
    final outParams = outTensor.params;
    _outputScale = outParams.scale;
    _outputZeroPoint = outParams.zeroPoint;
    _outputIsQuantized =
        outTensor.type == TensorType.int8 || outTensor.type == TensorType.uint8;

    debugPrint(
      'TfliteService [OUTPUT] '
      'shape=${outTensor.shape}, '
      'type=${outTensor.type}, '
      'scale=$_outputScale, '
      'zeroPoint=$_outputZeroPoint',
    );

    // ── 5. Load labels ────────────────────────────────────────────────
    try {
      final raw = await rootBundle.loadString('Model/labels_classifier.txt');
      _labels = raw
          .split(RegExp(r'[\r\n]+'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('TfliteService: labels not found: $e');
      _labels = <String>[];
    }

    // ── 6. Detect output layout ──────────────────────────────────────────
    final outShape = outTensor.shape;
    if (outShape.length >= 3) {
      _outputAnchorMajor = outShape[1] > outShape[2];
      _numAnchors = _outputAnchorMajor ? outShape[1] : outShape[2];
      _numChannels = _outputAnchorMajor ? outShape[2] : outShape[1];
    } else {
      _outputAnchorMajor = false;
      _numAnchors = 8400;
      _numChannels = 4 + _labels.length;
    }

    _initialized = true;

    debugPrint(
      'TfliteService: init complete — '
      'isNchw=$_isNchw, '
      'inputQuantized=$_inputIsQuantized, '
      'inputScale=$_inputScale, inputZP=$_inputZeroPoint, '
      'outputQuantized=$_outputIsQuantized, '
      'outputScale=$_outputScale, outputZP=$_outputZeroPoint, '
      'anchors=$_numAnchors, channels=$_numChannels, '
      'anchorMajor=$_outputAnchorMajor',
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────
  /// Reads one output value and dequantizes it if the output tensor is
  /// INT8/UINT8.
  ///
  /// Dequantization: real = (q − zeroPoint) × scale
  double _readOutput(List<dynamic> output, int channel, int anchor) {
    final num raw = _outputAnchorMajor
        ? (output[0][anchor][channel] as num)
        : (output[0][channel][anchor] as num);

    if (_outputIsQuantized) {
      return (raw.toInt() - _outputZeroPoint) * _outputScale;
    }
    return raw.toDouble();
  }

  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  double _ensureProbability(double v) => (v < 0.0 || v > 1.0) ? _sigmoid(v) : v;

  double _toInputPixels(double value, int targetSize) {
    if (value > 0 && value <= 1.0) return value * targetSize;
    return value;
  }

  // ─── predict() ─────────────────────────────────────────────────────────
  /// Runs YOLOv11 inference on [imageFile].
  ///
  /// Pipeline:
  /// 1. Letterbox + convert to the model's real input dtype (int8 quantize
  ///    or float32 normalize) → background [Isolate]
  /// 2. Reshape flat buffer to the model's native 4-D input shape, using
  ///    the Dart type that matches the tensor's real dtype
  /// 3. `Interpreter.run()` → platform thread (fast native call)
  /// 4. Dequantize outputs (if needed) + decode YOLO boxes → main thread
  /// 5. NMS → background [Isolate] (when >30 candidates)
  Future<PredictionResult> predict(File imageFile) async {
    assert(_initialized, 'Call TfliteService.init() before predict()');

    // ── Step 1: Background preprocessing ─────────────────────────────────
    final bytes = await imageFile.readAsBytes();

    // Capture primitives into locals so the closure is safe to send across
    // isolate boundaries (avoids capturing `this`).
    final bool capturedIsNchw = _isNchw;
    final bool capturedIsQuantized = _inputIsQuantized;
    final double capturedScale = _inputScale;
    final int capturedZeroPoint = _inputZeroPoint;

    final prep = await Isolate.run(
      () => _preprocessIsolate(
        _PreprocessPayload(
          imageBytes: bytes,
          targetSize: _inputSize,
          isNchw: capturedIsNchw,
          isQuantized: capturedIsQuantized,
          scale: capturedScale,
          zeroPoint: capturedZeroPoint,
        ),
      ),
    );

    // ── Step 2: Reshape flat buffer → model's native 4-D input shape ─────
    // Use the Dart type that matches the tensor's real dtype — feeding a
    // 1-byte-per-element buffer into a tensor that expects 4 bytes/element
    // (or vice versa) corrupts the native memory arena and produces
    // cryptic errors on unrelated internal tensors.
    final inputTensor = _interpreter.getInputTensors().first;
    final List<int> inputShape = inputTensor.shape; // e.g. [1, 3, 640, 640]

    final dynamic inputData;
    if (_inputIsQuantized) {
      assert(prep.int8Buffer != null);
      inputData = prep.int8Buffer!.toList().reshape<int>(inputShape);
    } else {
      assert(prep.float32Buffer != null);
      inputData = prep.float32Buffer!.toList().reshape<double>(inputShape);
    }

    // ── Step 3: Inference ─────────────────────────────────────────────────
    final int numChannels = _numChannels;
    final int numAnchors = _numAnchors;

    // Output container: List<num> accepts both float and int values; we
    // dequantize through _readOutput() so the box-decoding below is
    // dtype-agnostic.
    final List<List<List<num>>> output = List.generate(
      1,
      (_) => List.generate(numChannels, (_) => List.filled(numAnchors, 0)),
    );

    try {
      _interpreter.run(inputData, output);
    } catch (e, st) {
      debugPrint('TfliteService: inference failed: $e\n$st');
      throw Exception('TFLite inference failed: $e');
    }

    // ── Step 4: Decode YOLO output boxes ──────────────────────────────────
    final bool hasObjectness = numChannels == 6 || numChannels == 10;
    final int classOffset = hasObjectness ? 5 : 4;
    final int yoloClasses = numChannels - classOffset;
    const double confidenceThreshold = 0.20;

    final double imgW = prep.imgW.toDouble();
    final double imgH = prep.imgH.toDouble();

    final List<List<double>> rawBoxes = [];

    for (int anchor = 0; anchor < numAnchors; anchor++) {
      final double objectness = hasObjectness
          ? _ensureProbability(_readOutput(output, 4, anchor))
          : 1.0;

      double maxScore = -1.0;
      int bestClass = 0;
      for (int cls = 0; cls < yoloClasses; cls++) {
        final double score = _ensureProbability(
          _readOutput(output, classOffset + cls, anchor),
        );
        final double combined = objectness * score;
        if (combined > maxScore) {
          maxScore = combined;
          bestClass = cls;
        }
      }

      if (maxScore > confidenceThreshold) {
        final double cx = _toInputPixels(
          _readOutput(output, 0, anchor),
          _inputSize,
        );
        final double cy = _toInputPixels(
          _readOutput(output, 1, anchor),
          _inputSize,
        );
        final double w = _toInputPixels(
          _readOutput(output, 2, anchor),
          _inputSize,
        );
        final double h = _toInputPixels(
          _readOutput(output, 3, anchor),
          _inputSize,
        );

        final double origCx = (cx - prep.dx) / prep.ratio;
        final double origCy = (cy - prep.dy) / prep.ratio;
        final double origW = w / prep.ratio;
        final double origH = h / prep.ratio;

        rawBoxes.add([
          (origCx - origW / 2).clamp(0.0, imgW), // left
          (origCy - origH / 2).clamp(0.0, imgH), // top
          (origCx + origW / 2).clamp(0.0, imgW), // right
          (origCy + origH / 2).clamp(0.0, imgH), // bottom
          maxScore,
          bestClass.toDouble(),
        ]);
      }
    }

    debugPrint('TfliteService: ${rawBoxes.length} candidates before NMS');

    // ── Step 5: NMS ────────────────────────────────────────────────────────
    rawBoxes.sort((a, b) => b[4].compareTo(a[4])); // sort by confidence desc

    final List<int> keptIndices = rawBoxes.length > 30
        ? await Isolate.run(() => _nmsIsolate(_NmsPayload(rawBoxes, 0.45)))
        : _nmsIsolate(_NmsPayload(rawBoxes, 0.45));

    // ── Step 6: Build final detections ────────────────────────────────────
    final List<Detection> finalDetections = [];
    for (final idx in keptIndices) {
      if (finalDetections.length >= _maxDetections) break;

      final box = rawBoxes[idx];
      final int clsIdx = box[5].toInt();
      final String label = clsIdx < _labels.length
          ? _labels[clsIdx]
          : 'Unknown';
      if (label.toLowerCase() == 'non-mosquito') continue;

      finalDetections.add(
        Detection(
          label: label,
          confidence: box[4],
          boundingBox: Rect.fromLTRB(box[0], box[1], box[2], box[3]),
        ),
      );
    }

    debugPrint('TfliteService: ${finalDetections.length} final detections');

    return PredictionResult(
      detections: finalDetections,
      imageSize: Size(imgW, imgH),
    );
  }

  List<String> get labels => List.unmodifiable(_labels);
  bool get isInitialized => _initialized;
}
