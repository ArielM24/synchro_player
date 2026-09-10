import 'dart:math';

import 'package:synchro_player/util/math/math_utils.dart';

class AudioFeatures {
  final int sampleRate;
  final double energy;
  final double energyStd;
  final double centroid;
  final double bandwidth;
  final double rolloff;
  final double flatness;
  final double zcr;
  final double flux;
  final double maxFlux;
  final double minFlux;
  final int channels;

  const AudioFeatures({this.energy = 0, this.energyStd=0, this.centroid=0, this.bandwidth=0, this.rolloff=0, this.flatness=0, this.zcr=0, this.flux=0, this.sampleRate = 0, this.maxFlux=0, this.minFlux=0, this.channels=1});

  bool get isQuiet => energy == 0 && energyStd == 0 && centroid == 0 && bandwidth == 0 && rolloff == 0 && flatness == 0 && zcr == 0 && flux == 0;

  // returns an object with the base features normalized [0 - 1]
  AudioFeatures nomalize() {
    final double nyq = sampleRate / 2.0;
    final double minLog = log1p(minFlux);
    final double logFluxMax = log((1.0 + 50000.0)); // ≈ 10.82
    return AudioFeatures(
      energy: clip(energy, 0, 0.5) / 0.5,
      energyStd: (energyStd / 0.1).clamp(0.0, 1.0),
      centroid: centroid / nyq,
      bandwidth: bandwidth / nyq,
      rolloff: rolloff / nyq,
      flatness: log1p(flatness * 100) / log1p(100),
      zcr: zcr,
      flux: (log1p(flux) / logFluxMax).clamp(0.0, 1.0),
      sampleRate: sampleRate,
      minFlux: minFlux,
      maxFlux: maxFlux,
      channels: channels
    );
  }

  @override
  String toString(){
    return "[sample rate: $sampleRate, channels: $channels, energy: $energy, energyStd: $energyStd, centroid: $centroid, bandwidth: $bandwidth, rolloff: $rolloff, flatness: $flatness, zcr: $zcr, flux: $flux, minFlux: $minFlux, maxFlux: $maxFlux]";
  }

  List<double> toList() {
    return [energy, energyStd, centroid, bandwidth, rolloff, flatness, zcr, flux];
  }
}