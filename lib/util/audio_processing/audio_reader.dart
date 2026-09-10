import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/material.dart';
import 'package:synchro_player/data/audio_data.dart';
import 'package:synchro_player/data/audio_features.dart';
import 'package:synchro_player/util/audio_processing/feature_extractor.dart';

class AudioReader {
  Future<AudioData> readAudioData(String mp3Path) async {
    debugPrint("reading $mp3Path");
    final mp3Bytes = await File(mp3Path).readAsBytes();
    debugPrint("readed ${mp3Bytes.length} bytes");

    final pcmBytes = await AudioDecoder.trimAudioBytes(
      mp3Bytes,
      formatHint: 'mp3',
      start: Duration.zero,
      end: Duration(seconds: 30),
    );
    debugPrint("decoded ${pcmBytes.length} bytes and trimed to 30s");
    final info = await AudioDecoder.getAudioInfo(mp3Path);
    debugPrint("info: ${info.sampleRate}");
    // Int16 → Float32 (normalized [-1.0, 1.0])
    final i16 = Int16List.view(
      ByteData.view(
        pcmBytes.buffer,
        pcmBytes.offsetInBytes,
        pcmBytes.lengthInBytes ~/ 2,
      ).buffer,
    );
    debugPrint("normalized ${i16.length} bytes");

    final f32 = Float32List.fromList(i16.map((b) => b / 32768.0).toList());
    debugPrint("f32 ${f32.length} bytes");
    return AudioData(pcm: f32, sampleRate: info.sampleRate);
  }

  Future<AudioFeatures> readSongFeatures(String mp3Path) async {
    AudioData data = await readAudioData(mp3Path);
    FeatureExtractor fe = FeatureExtractor();
    AudioFeatures features = fe.extractFeatures(data);
    return features;
  }
}
