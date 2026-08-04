import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

void main() {
  test('Inspect TFLite models', () async {
    try {
      final modelFile = File('Model/yolo11/best_int8.tflite');
      if (!modelFile.existsSync()) {
        print('INT8 model not found at ${modelFile.path}');
        // try absolute path
        final absPath = File('E:/UI/DengueLens_Updated/DengueLens/Model/yolo11/best_int8.tflite');
        if (absPath.existsSync()) {
            print("Found at absolute path");
            final interpreter = Interpreter.fromFile(absPath);
            print('Inputs:');
            for (var t in interpreter.getInputTensors()) print('${t.name}: ${t.shape}, ${t.type}');
            print('Outputs:');
            for (var t in interpreter.getOutputTensors()) print('${t.name}: ${t.shape}, ${t.type}');
        } else {
            print("Not found anywhere.");
        }
      } else {
        final interpreter = Interpreter.fromFile(modelFile);
        print('INT8 Model:');
        print('Inputs:');
        for (var tensor in interpreter.getInputTensors()) {
          print(' - ${tensor.name}: shape=${tensor.shape}, type=${tensor.type}');
        }
        print('Outputs:');
        for (var tensor in interpreter.getOutputTensors()) {
          print(' - ${tensor.name}: shape=${tensor.shape}, type=${tensor.type}');
        }
      }
    } catch (e, stack) {
      print('Error: $e');
      print(stack);
    }
  });
}
