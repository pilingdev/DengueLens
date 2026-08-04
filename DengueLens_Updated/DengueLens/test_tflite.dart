import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  try {
    final modelFile = File('e:/UI/DengueLens_Updated/DengueLens/assets/Model/best_int8.tflite');
    if (!modelFile.existsSync()) {
      print('INT8 model not found at ${modelFile.path}');
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

    final floatModelFile = File('e:/UI/DengueLens_Updated/DengueLens/assets/Model/best_float32.tflite');
    if (!floatModelFile.existsSync()) {
      print('Float32 model not found at ${floatModelFile.path}');
    } else {
      final interpreter = Interpreter.fromFile(floatModelFile);
      print('Float32 Model:');
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
}
