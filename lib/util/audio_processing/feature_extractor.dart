import 'dart:math' as math;
import 'dart:math';
import 'dart:typed_data';

import 'package:open_dspc/dsp/fft.dart';
import 'package:synchro_player/data/audio_data.dart';
import 'package:synchro_player/data/audio_features.dart';
import 'package:synchro_player/util/math/math_utils.dart';

class FeatureExtractor {
  static const int windowSize = 2048;
  static const int hopSize = 1024;
  static final List<double> majorTemplate = [
    0.81,
    0.06,
    0.28,
    0.27,
    0.22,
    0.31,
    0.51,
    0.15,
    0.27,
    0.11,
    0.40,
    0.13,
  ];
  static final List<double> minorTemplate = [
    0.81,
    0.29,
    0.06,
    0.39,
    0.20,
    0.27,
    0.44,
    0.15,
    0.21,
    0.47,
    0.28,
    0.14,
  ];
  // hann window
  late final Float32List _hann;

  FeatureExtractor() {
    _hann = Float32List(windowSize);
    for (var i = 0; i < windowSize; i++) {
      _hann[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (windowSize - 1)));
    }
  }

  // Features
  double rms(Float32List x) {
    double sum = 0;
    for (var i = 0; i < x.length; i++) {
      sum += x[i] * x[i];
    }
    return math.sqrt(sum / x.length);
  }

  double spectralCentroid(Float32List mag, int sampleRate, int n) {
    double num = 0, den = 0;
    for (var i = 0; i < n; i++) {
      num += i * mag[i];
      den += mag[i];
    }
    return den > 0 ? (num / den) * (sampleRate / 2) / n : 0;
  }

  double spectralBandwidth(
    Float32List mag,
    int n,
    double centroid,
    int sampleRate,
  ) {
    double sum = 0, den = 0;
    for (var i = 0; i < n; i++) {
      double freq = i * (sampleRate / 2) / n;
      sum += (freq - centroid) * (freq - centroid) * mag[i];
      den += mag[i];
    }
    return den > 0 ? math.sqrt(sum / den) : 0;
  }

  double spectralRolloff(
    Float32List mag,
    int n,
    int sampleRate, [
    double threshold = 0.85,
  ]) {
    double total = 0;
    for (var i = 0; i < n; i++) {
      total += mag[i];
    }
    if (total == 0) {
      return 0;
    }

    double cumulative = 0;
    for (var i = 0; i < n; i++) {
      cumulative += mag[i];
      if (cumulative >= threshold * total) {
        return i * (sampleRate / 2) / n;
      }
    }
    return sampleRate / 2;
  }

  double spectralFlatness(Float32List mag, int n) {
    double geoSum = 0, arithSum = 0;
    int count = 0;
    for (var i = 0; i < n; i++) {
      if (mag[i] > 1e-10) {
        geoSum += math.log(mag[i]);
        arithSum += mag[i];
        count++;
      }
    }
    if (count == 0) {
      return 0;
    }
    double geoMean = math.exp(geoSum / count);
    double arithMean = arithSum / count;
    return arithMean > 0 ? geoMean / arithMean : 0;
  }

  double zcr(Float32List x) {
    int crossings = 0;
    for (var i = 1; i < x.length; i++) {
      if ((x[i] >= 0 && x[i - 1] < 0) || (x[i] < 0 && x[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / (x.length - 1);
  }

  double spectralFlux(Float32List prev, Float32List curr) {
    double sum = 0;
    int n = math.min(prev.length, curr.length);
    for (var i = 0; i < n; i++) {
      double diff = curr[i] - prev[i];
      if (diff > 0) {
        sum += diff * diff;
      }
    }
    return sum;
  }

  List<double> computeChroma(
    List<Float32List> stftFrames,
    int sampleRate, {
    int nFFT = 2048,
    double sigma = 1.2,
  }) {
    final int nBins = stftFrames[0].length;
    final int nFrames = stftFrames.length;
    final chroma = List<double>.filled(12, 0);

    for (int frame = 0; frame < nFrames; frame++) {
      for (int bin = 1; bin < nBins; bin++) {
        double freq = bin * sampleRate / nFFT;
        if (freq < 80 || freq > 1500) continue;

        // MIDI continuo
        double midi = 69 + 12 * (log(freq / 440.0) / log(2.0));

        // Pitch class continuo (0-12)
        double pcCont = midi % 12;
        if (pcCont < 0) pcCont += 12;

        // Distribuir con kernel gaussiano (no triangular)
        for (int pc = 0; pc < 12; pc++) {
          // Distancia circular al pitch class
          double dist = (pcCont - pc).abs();
          if (dist > 6) dist = 12 - dist;

          double weight = exp(-(dist * dist) / (2 * sigma * sigma));
          chroma[pc] += stftFrames[frame][bin] * weight;
        }
      }
    }

    // Normalizar a 0-1
    double maxVal = chroma.reduce((a, b) => a > b ? a : b);
    if (maxVal > 1e-8) {
      for (int i = 0; i < 12; i++) {
        chroma[i] /= maxVal;
      }
    }
    return chroma;
  }

  double computeModeAlt(List<double> chroma) {
  // Triada mayor: raíz, +4, +7
  // Triada menor: raíz, +3, +7
  double majorTotal = 0;
  double minorTotal = 0;

  for (int root = 0; root < 12; root++) {
    // Ponderar por la energía de la raíz (si la raíz tiene poca energía,
    // esa triada no es relevante)
    double rootWeight = chroma[root];

    double majorScore = rootWeight * (chroma[(root + 4) % 12] + chroma[(root + 7) % 12]);
    double minorScore = rootWeight * (chroma[(root + 3) % 12] + chroma[(root + 7) % 12]);

    majorTotal += majorScore;
    minorTotal += minorScore;
  }

  double sum = majorTotal + minorTotal;
  if (sum < 1e-8) return 0.5;

  return majorTotal / sum; // 0 = menor, 1 = mayor, 0.5 = neutro
}   

  double computeMode(List<double> chroma) {
    double majorScore = 0, minorScore = 0;
    for (int i = 0; i < 12; i++) {
      majorScore += chroma[i] * majorTemplate[i];
      minorScore += chroma[i] * minorTemplate[i];
    }
    double total = majorScore + minorScore;
    if (total < 1e-8) return 0.5;
    return majorScore / total; // 0-1
  }

  double computeConsonance(List<double> chroma) {
    double entropy = 0;
    for (int i = 0; i < 12; i++) {
      if (chroma[i] > 1e-8) {
        entropy -= chroma[i] * log((chroma[i]));
      }
    }
    double maxEntropy = log((12.0)); // log(12) ≈ 2.485
    double normalized = 1.0 - (entropy / maxEntropy); // 0-1
    return normalized.clamp(0.0, 1.0);
  }

  int estimateBPM(List<double> onsetStrength, int sampleRate, int hopSize) {
  final double fps = sampleRate / hopSize;

  if (onsetStrength.length < 50) return 120;

  double mean = 0;
  for (var v in onsetStrength) mean += v;
  mean /= onsetStrength.length;

  double std = 0;
  for (var v in onsetStrength) std += (v - mean) * (v - mean);
  std = math.sqrt(std / onsetStrength.length);

  if (std < 1e-8) return 120;

  double bestBpm = 120;
  double bestScore = 0;

  for (double bpm = 60; bpm <= 200; bpm += 1.0) {
    double beatFrames = fps * 60.0 / bpm;
    int lag = beatFrames.round();

    if (lag < 2 || lag >= onsetStrength.length) continue;

    double score = 0;
    int count = 0;
    for (int i = 0; i < onsetStrength.length - lag; i++) {
      score += onsetStrength[i] * onsetStrength[i + lag];
      count++;
    }
    if (count > 0) score /= count;

    if (score > bestScore) {
      bestScore = score;
      bestBpm = bpm;
    }
  }

  // ← PLEGAR: si el BPM ganador es alto, verificar si la mitad también es fuerte
  // Una canción a 70 BPM tiene picos a 140 BPM también.
  // Si score(bpm/2) > 0.8 * score(bpm), usar bpm/2.
  if (bestBpm > 130) {
    double halfBpm = bestBpm / 2;
    if (halfBpm >= 60) {
      double halfFrames = (fps * 60.0 / halfBpm).round()*1.0;
      if (halfFrames < onsetStrength.length) {
        double halfScore = 0;
        int count = 0;
        for (int i = 0; i < onsetStrength.length - halfFrames; i++) {
          halfScore += onsetStrength[i] * onsetStrength[i + halfFrames.toInt()];
          count++;
        }
        if (count > 0) halfScore /= count;

        if (halfScore > 0.75 * bestScore) {
          bestBpm = halfBpm; // ← preferir el tempo más lento
        }
      }
    }
  }

  return bestBpm.round();
}   
  /// Onset strength (solo aumentos de energía)
  List<double> computeOnsetStrength(List<Float32List> stftFrames) {
    final List<double> onset = [];
    for (int i = 1; i < stftFrames.length; i++) {
      double sum = 0;
      for (int bin = 0; bin < stftFrames[i].length; bin++) {
        double diff = stftFrames[i][bin] - stftFrames[i - 1][bin];
        if (diff > 0) sum += diff; // solo aumentos
      }
      onset.add(sum);
    }
    return onset;
  }

  // Extraction of energy, energyStd, centroid, bandwidth, rolloff, flatness, zcr and flux
  AudioFeatures extractFeatures(AudioData data) {
    if (data.pcm == null) {
      return AudioFeatures();
    }
    final plan = RfftPlan(windowSize);
    final frame = Float32List(windowSize);
    final List<double> energies = [];
    final List<double> centroids = [];
    final List<double> bandwidths = [];
    final List<double> rolloffs = [];
    final List<double> flatnesses = [];
    final List<double> zcrs = [];
    final List<double> fluxes = [];

    Float32List? prevMag;
    final List<Float32List> stftFrames = [];

    for (var i = 0; i + windowSize <= data.pcm!.length; i += hopSize) {
      // 1. Copy frame + Hann window
      for (var j = 0; j < windowSize; j++) {
        frame[j] = data.pcm![i + j] * _hann[j];
      }

      // 2. FFT
      final mag = FFTStatic.rfftMag(frame);
      final magLen = mag.length;
      stftFrames.add(mag);

      // 3. Features per frame
      energies.add(rms(frame));
      centroids.add(spectralCentroid(mag, data.sampleRate, magLen));
      bandwidths.add(
        spectralBandwidth(mag, magLen, centroids.last, data.sampleRate),
      );
      rolloffs.add(spectralRolloff(mag, magLen, data.sampleRate));
      flatnesses.add(spectralFlatness(mag, magLen));
      zcrs.add(zcr(frame));

      if (prevMag != null) {
        fluxes.add(spectralFlux(prevMag, mag));
      }
      prevMag = mag;
    }
    plan.close();
    final chroma = computeChroma(stftFrames, data.sampleRate);
    final onsetStrength = computeOnsetStrength(stftFrames);
    return AudioFeatures(
      sampleRate: data.sampleRate,
      energy: median(energies),
      energyStd: std(energies),
      centroid: median(centroids),
      bandwidth: median(bandwidths),
      rolloff: median(rolloffs),
      flatness: median(flatnesses),
      zcr: median(zcrs),
      flux: median(fluxes),
      minFlux: fluxes.reduce((a, b) => min(a, b)),
      maxFlux: fluxes.reduce((a, b) => max(a, b)),
      channels: data.channels,
      consonance: computeConsonance(chroma),
      mode: computeModeAlt(chroma),
      bpm: estimateBPM(onsetStrength, data.sampleRate, hopSize)*1.0,
    );
  }
}
