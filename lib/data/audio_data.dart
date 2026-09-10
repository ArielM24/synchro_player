import 'dart:typed_data';

class AudioData {
  Float32List? pcm;
  int sampleRate;
  int channels;

  AudioData({this.pcm, this.sampleRate = 0, this.channels = 1});
}