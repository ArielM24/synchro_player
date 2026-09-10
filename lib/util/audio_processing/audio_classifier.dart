import 'package:flutter/material.dart';
import 'package:synchro_player/data/audio_features.dart';
import 'package:synchro_player/data/music_emotion.dart';

class AudioClassifier {
  static Map<String, double> classifyMultiLabel(AudioFeatures f) {
    final List<double> features = f.toList();
    final Map<String, double> results = {};

    for (final proto in MusicEmotion.prototypes) {
      double score = MusicEmotion.similarity(features, proto);
      double distance = MusicEmotion.distance(features, proto);
      debugPrint("distance $distance");
      if (score >= proto.threshold) {
        results[proto.name] = score;
      }
    }

    // Si ninguna supera el umbral, asignar la de mayor score (fallback)
    if (results.isEmpty) {
      MusicEmotion best = MusicEmotion.prototypes[0];
      double bestScore = 0;
      for (final proto in MusicEmotion.prototypes) {
        double s = MusicEmotion.similarity(features, proto);
        if (s > bestScore) {
          bestScore = s;
          best = proto;
        }
      }
      results[best.name] = bestScore;
    }

    return results;
  }
}
