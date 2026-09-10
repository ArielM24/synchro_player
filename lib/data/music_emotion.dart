import 'dart:math';

class MusicEmotion {
  final String name;
  final List<double> featureValues;
  static final List<double> weights = [
    0.15, // energy     → arousal (activación)
    0.05, // energyStd  → dinámica/contraste (secundaria)
    0.15, // centroid   → brillo / valencia
    0.05, // bandwidth  → redundante con centroid (menos peso)
    0.10, // rolloff    → redundante con centroid (menos peso)
    0.20, // flatness   → ruido vs tono (máxima discriminación: miedo vs calma)
    0.10, // zcr        → contenido percusivo
    0.20, // flux       → cambio/dinámica (clave para tensión/ira)
  ];
  final double threshold;
  static final List<MusicEmotion> prototypes = [
    MusicEmotion(
      name: 'Alegría',
      featureValues: [0.40, 0.30, 0.35, 0.30, 0.45, 0.15, 0.30, 0.55],
      threshold: 0.72,
    ),
    MusicEmotion(
      name: 'Calma',
      featureValues: [0.13, 0.16, 0.10, 0.09, 0.18, 0.25, 0.07, 0.54],
      threshold: 0.72,
    ),
    MusicEmotion(
      name: 'Tristeza',
      featureValues: [0.20, 0.15, 0.12, 0.10, 0.22, 0.20, 0.06, 0.45],
      threshold: 0.72,
    ),
    MusicEmotion(
      name: 'Ira',
      featureValues: [0.55, 0.70, 0.35, 0.35, 0.50, 0.60, 0.30, 0.85],
      threshold: 0.68,
    ),
    MusicEmotion(
      name: 'Miedo',
      featureValues: [0.35, 0.50, 0.25, 0.25, 0.35, 0.55, 0.20, 0.75],
      threshold: 0.68,
    ),
    MusicEmotion(
      name: 'Nostalgia',
      featureValues: [0.08, 0.08, 0.06, 0.05, 0.10, 0.15, 0.04, 0.35],
      threshold: 0.75,
    ),
    MusicEmotion(
      name: 'Triunfo',
      featureValues: [0.50, 0.35, 0.30, 0.30, 0.45, 0.10, 0.25, 0.60],
      threshold: 0.72,
    ),
  ];
  MusicEmotion({
    required this.name,
    required this.featureValues,
    required this.threshold,
  });

  static double similarity(List<double> features, MusicEmotion me) {
    double sum = 0;
    double weightSum = 0;
    for (int i = 0; i < features.length; i++) {
      double diff = (features[i] - me.featureValues[i]).abs();
      sum += weights[i] * (1.0 - diff);
      weightSum += weights[i];
    }
    return sum / weightSum; // 0 - 1
  }

  static double distance(List<double> features, MusicEmotion me) {
    double sum = 0;
    for (int i = 0; i < features.length; i++) {
      sum += pow((features[i] - me.featureValues[i]), 2);
    }
    return sqrt(sum);
  }
}
