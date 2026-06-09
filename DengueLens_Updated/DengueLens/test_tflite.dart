import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  final interpreter = Interpreter.fromFile(File('Model/newest_model.tflite'));
  print('Input tensors:');
  for (var tensor in interpreter.getInputTensors()) {
    print('${tensor.name}: ${tensor.shape} (type: ${tensor.type})');
  }

  print('Output tensors:');
  for (var tensor in interpreter.getOutputTensors()) {
    print('${tensor.name}: ${tensor.shape} (type: ${tensor.type})');
  }
}
