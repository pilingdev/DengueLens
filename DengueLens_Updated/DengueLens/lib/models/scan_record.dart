import 'dart:io';
import 'prediction_result.dart';

class ScanRecord {
  final String id;
  final String mosquitoType;
  final String result;
  final double confidence;
  final DateTime date;
  final File? imageFile;
  final List<String>? symptoms;
  final int? riskScore;
  final String? location;
  /// Number of mosquitoes detected by the ML pipeline (saved so history can display it).
  final int detectionCount;
  final List<Detection>? detections;
  final double? imageWidth;
  final double? imageHeight;

  ScanRecord({
    required this.id,
    required this.mosquitoType,
    required this.result,
    required this.confidence,
    required this.date,
    this.imageFile,
    this.symptoms,
    this.riskScore,
    this.location,
    this.detectionCount = 1,
    this.detections,
    this.imageWidth,
    this.imageHeight,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mosquitoType': mosquitoType,
      'result': result,
      'confidence': confidence,
      'date': date.toIso8601String(),
      'imageFilePath': imageFile?.path,
      'symptoms': symptoms,
      'riskScore': riskScore,
      'location': location,
      'detectionCount': detectionCount,
      'detections': detections?.map((d) => d.toJson()).toList(),
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  factory ScanRecord.fromJson(Map<dynamic, dynamic> json) {
    final confidenceValue = json['confidence'];
    double confidenceParsed;
    if (confidenceValue is double) {
      confidenceParsed = confidenceValue;
    } else if (confidenceValue is int) {
      confidenceParsed = confidenceValue.toDouble();
    } else if (confidenceValue is String) {
      confidenceParsed = double.tryParse(confidenceValue) ?? 0.0;
    } else {
      confidenceParsed = 0.0;
    }

    List<Detection>? parsedDetections;
    if (json['detections'] != null) {
      parsedDetections = (json['detections'] as List)
          .map((e) => Detection.fromJson(e as Map<dynamic, dynamic>))
          .toList();
    }

    return ScanRecord(
      id: json['id'] ?? '',
      mosquitoType: json['mosquitoType'] ?? '',
      result: json['result'] ?? '',
      confidence: confidenceParsed,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      imageFile: json['imageFilePath'] is String ? File(json['imageFilePath']) : null,
      symptoms: (json['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      riskScore: json['riskScore'] as int?,
      location: json['location'] as String?,
      detectionCount: (json['detectionCount'] as int?) ?? 1,
      detections: parsedDetections,
      imageWidth: (json['imageWidth'] as num?)?.toDouble(),
      imageHeight: (json['imageHeight'] as num?)?.toDouble(),
    );
  }
}

