import 'media.dart';

class TranscodeOptions {
  const TranscodeOptions({
    this.videoCodec,
    this.width,
    this.height,
    this.framesPerSecond,
    this.videoKbps,
    this.audioKbps,
    this.sampleRate,
    this.channels,
    this.stripMetadata = false,
  });
  final String? videoCodec;
  final int? width,
      height,
      framesPerSecond,
      videoKbps,
      audioKbps,
      sampleRate,
      channels;
  final bool stripMetadata;
  bool get changesVideo =>
      videoCodec != null ||
      width != null ||
      height != null ||
      framesPerSecond != null ||
      videoKbps != null;
  bool get changesAudio =>
      audioKbps != null || sampleRate != null || channels != null;
  void validate() {
    bool outside(int? v, int min, int max) => v != null && (v < min || v > max);
    if (outside(width, 2, 16384) ||
        outside(height, 2, 16384) ||
        (width == null) != (height == null) ||
        (width != null && (width!.isOdd || height!.isOdd)) ||
        outside(framesPerSecond, 1, 240) ||
        outside(videoKbps, 64, 200000) ||
        outside(audioKbps, 8, 512) ||
        outside(sampleRate, 8000, 192000) ||
        outside(channels, 1, 2)) {
      throw const MediaError(
        MediaErrorCode.invalidParameters,
        '转码参数无效，请检查尺寸、码率、帧率和声道。',
      );
    }
  }
}
