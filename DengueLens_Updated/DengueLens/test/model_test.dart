import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

void main() {
  test('inspect tflite model', () async {
    final interpreter = Interpreter.fromFile(File('Model/newest_model.tflite'));
    debugPrint('Input tensors:');
    for (var tensor in interpreter.getInputTensors()) {
      debugPrint('${tensor.name}: ${tensor.shape} (type: ${tensor.type})');
    }
    
    debugPrint('Output tensors:');
    for (var tensor in interpreter.getOutputTensors()) {
      debugPrint('${tensor.name}: ${tensor.shape} (type: ${tensor.type})');
    }
  });
}
