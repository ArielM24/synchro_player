import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/material.dart';
import 'package:synchro_player/data/audio_data.dart';
import 'package:synchro_player/data/audio_features.dart';
import 'package:synchro_player/util/audio_processing/feature_extractor.dart';

class AudioReader {
  Future<AudioData> readAudioData(String mp3Path) async {
    final mp3Bytes = await File(mp3Path).readAsBytes();

    final pcmBytes = await AudioDecoder.trimAudioBytes(
      mp3Bytes,
      formatHint: 'mp3',
      start: Duration(seconds: 45),
      end: Duration(minutes: 1, seconds: 15),
    );

    final info = await AudioDecoder.getAudioInfo(mp3Path);
    debugPrint(
      'sr: ${info.sampleRate}, canales: ${info.channels}, '
      'pcmBytes: ${pcmBytes.lengthInBytes}',
    );

    // ✅ Conversión manual, sin views ni alineación
    final numInt16 =
        pcmBytes.lengthInBytes ~/ 2; // descarta byte sobrante si es impar
    final f32 = Float32List(numInt16);

    for (var i = 0; i < numInt16; i++) {
      final lo = pcmBytes[i * 2];
      final hi = pcmBytes[i * 2 + 1];
      final int16 = (hi << 8) | lo;
      final signed = int16 > 32767 ? int16 - 65536 : int16;
      f32[i] = signed / 32768.0;
    }

    // Si es estéreo, mezclar a mono
    var mono = f32;
    if (info.channels == 2) {
      final n = numInt16 ~/ 2;
      mono = Float32List(n);
      for (var i = 0; i < n; i++) {
        mono[i] = (f32[i * 2] + f32[i * 2 + 1]) / 2.0;
      }
    }

    return AudioData(pcm: mono, sampleRate: info.sampleRate, channels: info.channels);
  }

  Future<AudioFeatures> readSongFeatures(String mp3Path) async {
    AudioData data = await readAudioData(mp3Path);
    FeatureExtractor fe = FeatureExtractor();
    AudioFeatures features = fe.extractFeatures(data);
    return features;
  }
}
