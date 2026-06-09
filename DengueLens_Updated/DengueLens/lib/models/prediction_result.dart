import 'package:flutter/material.dart';

class Detection {
  final String label;
  final double confidence;
  final Rect boundingBox;

  Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'left': boundingBox.left,
      'top': boundingBox.top,
      'right': boundingBox.right,
      'bottom': boundingBox.bottom,
    };
  }

  factory Detection.fromJson(Map<dynamic, dynamic> json) {
    return Detection(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: Rect.fromLTRB(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['right'] as num).toDouble(),
        (json['bottom'] as num).toDouble(),
      ),
    );
  }

  String get displayName {
    switch (label.toLowerCase()) {
      case 'albopictus':
        return 'Aedes albopictus';
      case 'anopheles':
        return 'Anopheles sp.';
      case 'culex':
        return 'Culex sp.';
      case 'aegypti':
        return 'Aedes aegypti';
      case 'non-mosquito':
        return 'Non-Mosquito';
      default:
        return label;
    }
  }

  /// True if this mosquito is any dengue vector (aegypti OR albopictus).
  bool get isDengueVector =>
      label.toLowerCase() == 'aegypti' || label.toLowerCase() == 'albopictus';

  /// 'high' for Aedes aegypti, 'moderate' for Aedes albopictus, 'none' otherwise.
  String get riskLevel {
    switch (label.toLowerCase()) {
      case 'aegypti':
        return 'high';
      case 'albopictus':
        return 'moderate';
      default:
        return 'none';
    }
  }
}

class PredictionResult {
  final List<Detection> detections;
  final Size? imageSize;

  const PredictionResult({required this.detections, this.imageSize});

  bool get isDengueVector => detections.any((d) => d.isDengueVector);

  /// Returns 'high', 'moderate', or 'negative' based on the dominant detection.
  String get dengueRisk {
    if (detections.isEmpty) return 'negative';
    final vectors = detections.where((d) => d.isDengueVector).toList();
    if (vectors.isEmpty) return 'negative';
    vectors.sort((a, b) => b.confidence.compareTo(a.confidence));
    return vectors.first.riskLevel; // 'high' or 'moderate'
  }

  double get confidence {
    if (detections.isEmpty) return 0.0;
    return detections.map((d) => d.confidence).reduce((a, b) => a > b ? a : b);
  }

  String get displayName {
    if (detections.isEmpty) return 'No Mosquito Detected';
    // Prioritize dengue vector for the main label
    final vectors = detections.where((d) => d.isDengueVector).toList();
    if (vectors.isNotEmpty) {
      vectors.sort((a, b) => b.confidence.compareTo(a.confidence));
      return vectors.first.displayName;
    }
    final all = List<Detection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return all.first.displayName;
  }
}
