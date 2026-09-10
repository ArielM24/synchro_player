import 'package:synchro_player/data/audio_features.dart';
import 'package:synchro_player/data/music_emotion.dart';

class AudioClassifier {
  static Map<String, (double, double)> classifyMultiLabel(AudioFeatures f) {
    final List<double> features = f.toList();
    final Map<String, (double, double)> results = {};

    for (final proto in MusicEmotion.prototypes) {
      double score = MusicEmotion.similarity(features, proto);
      double distance = MusicEmotion.distance(features, proto);
      results[proto.name] = (score, distance);
    }

    return results;
  }
}
