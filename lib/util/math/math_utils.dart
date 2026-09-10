import 'dart:math';

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  int mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

double std(List<double> values) {
  if (values.length < 2) return 0;
  double mean = values.reduce((a, b) => a + b) / values.length;
  double varSum = 0;
  for (var v in values) {
    varSum += (v - mean) * (v - mean);
  }
  return sqrt(varSum / (values.length - 1));
}

double clip(double x, double lo, double hi) => x.clamp(lo, hi);

double log1p(double x) => log((1 + x));

