import 'dart:math' as math;

List<double> softmax(List<double> scores) {
  final maxScore = scores.reduce((a, b) => a > b ? a : b);
  final exps = scores.map((s) => math.exp(s - maxScore)).toList();
  final sum = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sum).toList();
}
