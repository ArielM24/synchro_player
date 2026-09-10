import 'dart:math';

class MusicEmotion {
  final String name;
  final List<double> featureValues;
  static final List<double> weights = [
    0.15, // energy
    0.05, // energyStd
    0.15, // centroid
    0.10, // bandwidth
    0.15, // rolloff
    0.15, // flatness
    0.15, // zcr
    0.10, // flux
  ];
  final double threshold;
  static final List<MusicEmotion> prototypes = [
    MusicEmotion(
    name: 'Alegría',
    featureValues: [7.5, 4.0, 6.5, 5.0, 6.5, 1.0, 4.5, 4.5],
    threshold: 0.70,
  ),
  MusicEmotion(
    name: 'Calma',
    featureValues: [2.0, 1.0, 2.5, 1.5, 3.0, 0.8, 1.0, 1.0],
    threshold: 0.70,
  ),
  MusicEmotion(
    name: 'Tristeza',
    featureValues: [3.0, 1.5, 1.5, 1.5, 2.5, 1.0, 0.8, 0.8],
    threshold: 0.70,
  ),
  MusicEmotion(
    name: 'Ira',
    featureValues: [8.5, 7.0, 6.5, 6.5, 7.5, 2.5, 6.5, 8.0],
    threshold: 0.65,
  ),
  MusicEmotion(
    name: 'Miedo',
    featureValues: [5.5, 5.5, 4.5, 5.5, 5.5, 4.5, 3.5, 6.0],
    threshold: 0.65,
  ),
  MusicEmotion(
    name: 'Nostalgia',
    featureValues: [1.2, 0.6, 1.2, 1.0, 1.5, 0.5, 0.4, 0.4],
    threshold: 0.72,
  ),
  MusicEmotion(
    name: 'Triunfo',
    featureValues: [7.5, 4.5, 5.5, 4.5, 6.5, 0.8, 4.0, 4.5],
    threshold: 0.70,
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
    for(int i = 0; i<features.length; i++){
      sum += pow((features[i]-me.featureValues[i]), 2);
    }
    return sqrt(sum);
  }
}
