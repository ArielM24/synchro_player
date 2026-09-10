import 'dart:math';

class MusicEmotion {
  final String name;
  final List<double> featureValues;
  static final List<double> weights = [
    0.18, // energy
  0.05, // energyStd
  0.08, // centroid
  0.04, // bandwidth
  0.06, // rolloff
  0.14, // flatness  ↑ (clave para separar Miedo del resto)
  0.08, // zcr       ↑ (clave: Ira tiene zcr alta, Miedo zcr muy baja)
  0.14, // flux
  0.02, // mode
  0.07, // consonance
  0.14, // bpm
  ];
  final double threshold;
  static final List<MusicEmotion> prototypes = [
     MusicEmotion(
    name: 'Alegría',
    // bpm ALTO, energy media, flatness BAJA-MEDIA, zcr media
    featureValues: [0.35, 0.40, 0.15, 0.15, 0.25, 0.30, 0.15, 0.70, 0.50, 0.40, 0.70],
    threshold: 0.70,
  ),
  MusicEmotion(
    name: 'Calma',
    featureValues: [0.13, 0.16, 0.10, 0.09, 0.18, 0.25, 0.07, 0.50, 0.50, 0.40, 0.20],
    threshold: 0.72,
  ),
  MusicEmotion(
    name: 'Tristeza',
    featureValues: [0.12, 0.10, 0.08, 0.06, 0.12, 0.15, 0.04, 0.30, 0.50, 0.45, 0.15],
    threshold: 0.78,
  ),
  MusicEmotion(
    name: 'Ira',
    // energy MUY alta, flatness MUY alta, zcr ALTA, bpm alto
    featureValues: [0.70, 0.80, 0.30, 0.35, 0.50, 0.85, 0.30, 0.90, 0.50, 0.15, 0.65],
    threshold: 0.72,  // ← umbral más alto
  ),
  MusicEmotion(
    name: 'Miedo',
    // flatness EXTREMA, zcr MUY bajo, energy media-baja, bpm medio-bajo
    featureValues: [0.25, 0.50, 0.08, 0.10, 0.15, 0.90, 0.03, 0.85, 0.50, 0.10, 0.30],
    threshold: 0.75,  // ← umbral más alto
  ),
  MusicEmotion(
    name: 'Nostalgia',
    featureValues: [0.08, 0.08, 0.06, 0.05, 0.10, 0.15, 0.04, 0.35, 0.50, 0.45, 0.10],
    threshold: 0.78,
  ),
  MusicEmotion(
    name: 'Triunfo',
    featureValues: [0.50, 0.40, 0.20, 0.25, 0.35, 0.20, 0.20, 0.65, 0.50, 0.50, 0.70],
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
