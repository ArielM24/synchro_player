import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/foundation.dart';

import 'package:open_dspc/open_dspc.dart';

import 'dart:math' as math;

Future<Float32List> mp3ToFloat32(String mp3Path) async {
  debugPrint("reading $mp3Path");
  final mp3Bytes = await File(mp3Path).readAsBytes();
  debugPrint("readed ${mp3Bytes.length} bytes");

  final pcmBytes = await AudioDecoder.trimAudioBytes(
    mp3Bytes,
    formatHint: 'mp3',
    start: Duration.zero,
    end: Duration(seconds: 30),
  );
  debugPrint("decoded ${pcmBytes.length} bytes");
   final info = await AudioDecoder.getAudioInfo(mp3Path);
   debugPrint("info: ${info.sampleRate}");
  // Convierte Int16 → Float32 (normalizado a [-1.0, 1.0])
  final i16 = Int16List.view(
    ByteData.view(
      pcmBytes.buffer,
      pcmBytes.offsetInBytes,
      pcmBytes.lengthInBytes ~/ 2,
    ).buffer,
  );
  debugPrint("converted ${i16.length} bytes");

  final f32 = Float32List.fromList(i16.map((b) => b / 32768.0).toList());
  debugPrint("f32 ${f32.length} bytes");

  return f32;
}

Future<List<(String, double)>> classifySong(String mp3) async {
  final bytes = await mp3ToFloat32(mp3);
  final features = MoodAnalyzer().analyze(bytes);
  return MoodAnalyzer().classifyMood(features);
}

class MoodAnalyzer {
  static const int windowSize = 2048;
  static const int hopSize = 1024;
  static const double sampleRate = 44100.0;

  // Ventana Hann precalculada
  late final Float32List _hann;

  MoodAnalyzer() {
    _hann = Float32List(windowSize);
    for (var i = 0; i < windowSize; i++) {
      _hann[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (windowSize - 1)));
    }
  }

  // ─── FEATURES ──────────────────────────────────────────────────────────────

  Map<String, double> analyze(Float32List pcm) {
    final plan = RfftPlan(windowSize);
    final frame = Float32List(windowSize); // buffer reutilizable

    // Acumuladores (usamos lista para calcular mediana después)
    final List<double> energies = [];
    final List<double> centroids = [];
    final List<double> bandwidths = [];
    final List<double> rolloffs = [];
    final List<double> flatnesses = [];
    final List<double> zcrs = [];
    final List<double> fluxes = [];

    Float32List? prevMag;

    for (var i = 0; i + windowSize <= pcm.length; i += hopSize) {
      // 1. Copiar frame + aplicar ventana Hann
      for (var j = 0; j < windowSize; j++) {
        frame[j] = pcm[i + j] * _hann[j];
      }

      // 2. FFT
      final mag = FFTStatic.rfftMag(frame);
      final magLen = mag.length;

      // 3. Features por frame
      energies.add(_rms(frame));
      centroids.add(_spectralCentroid(mag, magLen));
      bandwidths.add(_spectralBandwidth(mag, magLen, centroids.last));
      rolloffs.add(_spectralRolloff(mag, magLen));
      flatnesses.add(_spectralFlatness(mag, magLen));
      zcrs.add(_zcr(frame));

      if (prevMag != null) {
        fluxes.add(_spectralFlux(prevMag, mag));
      }
      prevMag = mag;
    }

    plan.close();

    // 4. Resumir con mediana (robusto a outliers)
    return {
      'energy': _median(energies),
      'energyStd': _std(energies),
      'centroid': _median(centroids),
      'bandwidth': _median(bandwidths),
      'rolloff': _median(rolloffs),
      'flatness': _median(flatnesses),
      'zcr': _median(zcrs),
      'flux': _median(fluxes),
    };
  }

  // ─── FEATURES HELPERS ──────────────────────────────────────────────────────

  double _rms(Float32List x) {
    double sum = 0;
    for (var i = 0; i < x.length; i++) sum += x[i] * x[i];
    return math.sqrt(sum / x.length);
  }

  double _spectralCentroid(Float32List mag, int n) {
    double num = 0, den = 0;
    for (var i = 0; i < n; i++) {
      num += i * mag[i];
      den += mag[i];
    }
    return den > 0 ? (num / den) * (sampleRate / 2) / n : 0;
  }

  double _spectralBandwidth(Float32List mag, int n, double centroid) {
    double sum = 0, den = 0;
    for (var i = 0; i < n; i++) {
      double freq = i * (sampleRate / 2) / n;
      sum += (freq - centroid) * (freq - centroid) * mag[i];
      den += mag[i];
    }
    return den > 0 ? math.sqrt(sum / den) : 0;
  }

  double _spectralRolloff(Float32List mag, int n, [double threshold = 0.85]) {
    double total = 0;
    for (var i = 0; i < n; i++) total += mag[i];
    if (total == 0) return 0;

    double cumulative = 0;
    for (var i = 0; i < n; i++) {
      cumulative += mag[i];
      if (cumulative >= threshold * total) {
        return i * (sampleRate / 2) / n;
      }
    }
    return sampleRate / 2;
  }

  double _spectralFlatness(Float32List mag, int n) {
    double geoSum = 0, arithSum = 0;
    int count = 0;
    for (var i = 0; i < n; i++) {
      if (mag[i] > 1e-10) {
        geoSum += math.log(mag[i]);
        arithSum += mag[i];
        count++;
      }
    }
    if (count == 0) return 0;
    double geoMean = math.exp(geoSum / count);
    double arithMean = arithSum / count;
    return arithMean > 0 ? geoMean / arithMean : 0;
  }

  double _zcr(Float32List x) {
    int crossings = 0;
    for (var i = 1; i < x.length; i++) {
      if ((x[i] >= 0 && x[i - 1] < 0) || (x[i] < 0 && x[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / (x.length - 1);
  }

  double _spectralFlux(Float32List prev, Float32List curr) {
    double sum = 0;
    int n = math.min(prev.length, curr.length);
    for (var i = 0; i < n; i++) {
      double diff = curr[i] - prev[i];
      if (diff > 0) sum += diff * diff; // solo cambios ascendentes
    }
    return sum;
  }

  // ─── ESTADÍSTICAS ROBUSTAS ─────────────────────────────────────────────────

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    int mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _std(List<double> values) {
    if (values.length < 2) return 0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double varSum = 0;
    for (var v in values) {
      varSum += (v - mean) * (v - mean);
    }
    return math.sqrt(varSum / (values.length - 1));
  }

  // ─── CLASIFICACIÓN ─────────────────────────────────────────────────────────

  /// Regresa una lista de (categoría, score) ordenada por score descendente.
  /// Cada score va de 0.0 a 1.0 — a mayor score, mejor match.
  List<(String, double)> classifyMood(Map<String, double> f) {
    f.forEach((key, value) => debugPrint("$key $value"));
    double norm(double v, double min, double max) =>
        (v - min).clamp(0.0, max - min) / (max - min);

    final energy = norm(f['energy']!, 0.0, 0.3);
    final energyVar = norm(f['energyStd']!, 0.0, 0.1);
    final centroid = norm(f['centroid']!, 500.0, 8000.0);
    final bandwidth = norm(f['bandwidth']!, 200.0, 4000.0);
    final rolloff = norm(f['rolloff']!, 1000.0, 10000.0);
    final flatness = norm(f['flatness']!, 0.0, 0.5);
    final zcr = norm(f['zcr']!, 0.0, 0.3);
    final flux = norm(f['flux']!, 0.0, 0.01);

    final arousal = 0.35 * energy + 0.20 * energyVar + 0.20 * flux + 0.25 * zcr;
    final brightness = 0.5 * centroid + 0.3 * rolloff + 0.2 * bandwidth;
    final tonality = 1.0 - flatness;
    final dynamics = energyVar + 0.5 * flux;
    final sustain = 1.0 - energyVar;

    // ─── Helper: score por proximidad a un rango ideal ─────────────────────────
    /// Devuelve 1.0 si [v] está dentro de [lo, hi], decae linealmente fuera.
    double inRange(double v, double lo, double hi, double falloff) {
      if (v >= lo && v <= hi) return 1.0;
      if (v < lo) return (1.0 - (lo - v) / falloff).clamp(0.0, 1.0);
      return (1.0 - (v - hi) / falloff).clamp(0.0, 1.0);
    }

    /// Score por combinación de condiciones (promedio ponderado).
    double score(List<double> conditions) {
      if (conditions.isEmpty) return 0.0;
      return conditions.reduce((a, b) => a + b) / conditions.length;
    }

    // ─── Scoring por categoría ─────────────────────────────────────────────────

    final scores = <String, double>{
      'Romántico / Íntimo': score([
        inRange(arousal, 0.0, 0.45, 0.15),
        inRange(tonality, 0.65, 1.0, 0.15),
        inRange(dynamics, 0.0, 0.3, 0.15),
        inRange(centroid, 0.25, 1.0, 0.2),
        inRange(flatness, 0.0, 0.35, 0.15),
      ]),

      'Oscuro / Dramático': score([
        inRange(centroid, 0.0, 0.3, 0.15),
        inRange(tonality, 0.55, 1.0, 0.15),
        inRange(arousal, 0.0, 0.6, 0.2),
        inRange(dynamics, 0.0, 0.6, 0.2),
      ]),

      'Intenso / Agresivo': score([
        inRange(arousal, 0.65, 1.0, 0.15),
        inRange(centroid, 0.0, 0.4, 0.15),
        inRange(zcr, 0.35, 1.0, 0.2),
      ]),

      'Épico / Cinemático': score([
        inRange(energy, 0.6, 1.0, 0.15),
        inRange(sustain, 0.6, 1.0, 0.15),
        inRange(bandwidth, 0.5, 1.0, 0.15),
        inRange(flatness, 0.0, 0.25, 0.1),
      ]),

      'Tenso / Ansioso': score([
        inRange(dynamics, 0.55, 1.0, 0.15),
        inRange(centroid, 0.3, 0.7, 0.15),
        inRange(arousal, 0.0, 0.7, 0.2),
      ]),

      'Soñador / Etéreo': score([
        inRange(arousal, 0.0, 0.3, 0.1),
        inRange(flatness, 0.2, 1.0, 0.15),
        inRange(centroid, 0.3, 0.65, 0.15),
      ]),

      'Melancólico / Nostálgico': score([
        inRange(arousal, 0.0, 0.35, 0.1),
        inRange(centroid, 0.0, 0.35, 0.15),
        inRange(tonality, 0.5, 1.0, 0.15),
      ]),

      'Calmo / Relajado': score([
        inRange(arousal, 0.0, 0.3, 0.1),
        inRange(tonality, 0.5, 1.0, 0.15),
        inRange(dynamics, 0.0, 0.3, 0.15),
      ]),

      'Enérgico / Feliz': score([
        inRange(arousal, 0.55, 1.0, 0.15),
        inRange(brightness, 0.55, 1.0, 0.15),
        inRange(dynamics, 0.0, 0.5, 0.15),
        inRange(flatness, 0.0, 0.3, 0.1),
        inRange(centroid, 0.4, 1.0, 0.15),
      ]),

      'Ligero / Optimista': score([
        inRange(arousal, 0.25, 0.55, 0.1),
        inRange(brightness, 0.55, 1.0, 0.15),
        inRange(tonality, 0.5, 1.0, 0.15),
        inRange(dynamics, 0.0, 0.4, 0.15),
      ]),

      'Caótico / Experimental': score([
        inRange(dynamics, 0.7, 1.0, 0.1),
        inRange(flatness, 0.35, 1.0, 0.1),
        inRange(zcr, 0.55, 1.0, 0.1),
      ]),
    };

    // ─── Filtro + ordenamiento ─────────────────────────────────────────────────
    const double threshold = 0.55; // mínimo para incluir en la lista

    final result = scores.entries.where((e) => e.value >= threshold).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Si nada pasa el umbral, regresa al menos la mejor opción
    if (result.isEmpty) {
      final best = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
      result.add(best);
    }

    return result.map((entry) => (entry.key, entry.value)).toList();
  }

  List<String> getMood(Map<String, double> features) {
    List<String> moods = [];

    return moods;
  }
}
