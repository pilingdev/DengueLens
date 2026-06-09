import 'package:image/image.dart' as img;
import 'dart:math' as math;

/// Convert an [img.Image] to the input tensor shape expected by the model.
List<List<List<List<double>>>> imageToInputTensor(img.Image image) {
  final width = image.width;
  final height = image.height;
  return List.generate(
    1,
    (_) => List.generate(
      height,
      (y) => List.generate(width, (x) {
        final pixel = image.getPixel(x, y);
        // YOLOv8 maps [0,255] -> [0,1].
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        return [r, g, b];
      }),
    ),
  );
}

/// Convert an [img.Image] to the input tensor shape expected by the classifier.
/// MobileNetV3 expects pixels in the range [0, 255] as float values.
List<List<List<List<double>>>> imageToClassifierInputTensor(img.Image image) {
  final width = image.width;
  final height = image.height;
  return List.generate(
    1,
    (_) => List.generate(
      height,
      (y) => List.generate(width, (x) {
        final pixel = image.getPixel(x, y);
        // MobileNetV3 expects [0, 255] floats directly.
        double r = pixel.r.toDouble();
        double g = pixel.g.toDouble();
        double b = pixel.b.toDouble();
        return [r, g, b];
      }),
    ),
  );
}

/// Compute the softmax over a list of logits.
List<double> softmax(List<double> logits) {
  if (logits.isEmpty) return [];
  
  // Find max for numerical stability
  double maxLogit = logits.reduce((a, b) => a > b ? a : b);
  
  double sumExp = 0.0;
  List<double> exps = [];
  
  for (var logit in logits) {
    double expVal = math.exp(logit - maxLogit);
    exps.add(expVal);
    sumExp += expVal;
  }
  
  return exps.map((e) => e / sumExp).toList();
}
