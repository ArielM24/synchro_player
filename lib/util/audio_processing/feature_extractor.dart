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

  // Extraction of energy, energyStd, centroid, bandwidth, rolloff, flatness, zcr and flux
  AudioFeatures extractFeatures(AudioData data) {
    if(data.pcm == null){
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

    for (var i = 0; i + windowSize <= data.pcm!.length; i += hopSize) {
      // 1. Copy frame + Hann window
      for (var j = 0; j < windowSize; j++) {
        frame[j] = data.pcm![i + j] * _hann[j];
      }

      // 2. FFT
      final mag = FFTStatic.rfftMag(frame);
      final magLen = mag.length;

      // 3. Features per frame
      energies.add(rms(frame));
      centroids.add(spectralCentroid(mag, data.sampleRate,magLen));
      bandwidths.add(spectralBandwidth(mag, magLen, centroids.last, data.sampleRate));
      rolloffs.add(spectralRolloff(mag, magLen, data.sampleRate));
      flatnesses.add(spectralFlatness(mag, magLen));
      zcrs.add(zcr(frame));

      if (prevMag != null) {
        fluxes.add(spectralFlux(prevMag, mag));
      }
      prevMag = mag;
    }
    plan.close();
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
      minFlux: fluxes.reduce((a,b)=>min(a,b)),
      maxFlux: fluxes.reduce((a,b)=>max(a,b)),
      channels: data.channels
    );
  }
}
