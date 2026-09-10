import 'dart:typed_data';

class AudioData {
  Float32List? pcm;
  int sampleRate;

  AudioData({this.pcm, this.sampleRate = 0});
}