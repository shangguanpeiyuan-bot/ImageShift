import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../jobs/cancellation_token.dart';
import '../model/media.dart';
import '../model/transcode_options.dart';
import '../output/temp_file_manager.dart';
import '../probe/ffprobe_parser.dart';
import '../probe/local_playlist_guard.dart';
import 'media_backend.dart';
import 'process_runner.dart';

class FfmpegBackend implements MediaBackend {
  FfmpegBackend({
    required this.ffmpegPath,
    required this.ffprobePath,
    required Set<String> verifiedEncoders,
    this.runner = const MediaProcessRunner(),
  }) : verifiedEncoders = Set.unmodifiable(verifiedEncoders);
  final String ffmpegPath, ffprobePath;
  final Set<String> verifiedEncoders;
  final MediaCommandRunner runner;
  @override
  String get id => 'ffmpeg-process';

  /// Query the packaged executable; never infer codecs from its filename.
  static Future<FfmpegBackend> discover({
    required String ffmpegPath,
    required String ffprobePath,
    required CancellationToken cancellation,
    MediaCommandRunner runner = const MediaProcessRunner(),
  }) async {
    final output = await runner.run(
      ffmpegPath,
      ['-hide_banner', '-encoders'],
      cancellation,
      timeout: const Duration(seconds: 20),
    );
    if (output.exitCode != 0) {
      throw const MediaError(
        MediaErrorCode.resourceUnavailable,
        '无法读取本地编码器能力。',
      );
    }
    final encoders = RegExp(r'^\s*[VAS][A-Z.]{5}\s+(\S+)\s', multiLine: true)
        .allMatches(output.stdout)
        .map((m) => m.group(1)!)
        .where((name) => name != '=')
        .toSet();
    // Android 8.1.7 advertises VP9, but its generated profile-0 streams failed
    // full decoding on API 35 x86_64. Do not expose it until revalidated.
    if (Platform.isAndroid) encoders.remove('libvpx-vp9');
    if (encoders.isEmpty) {
      throw const MediaError(
        MediaErrorCode.resourceUnavailable,
        '本地编码器能力列表为空。',
      );
    }
    return FfmpegBackend(
      ffmpegPath: ffmpegPath,
      ffprobePath: ffprobePath,
      verifiedEncoders: encoders,
      runner: runner,
    );
  }

  @override
  Future<MediaProbe> probe(String path, CancellationToken cancellation) async {
    final file = File(path);
    if (!p.isAbsolute(path) ||
        await file.stat().then((s) => s.type) != FileSystemEntityType.file) {
      throw const MediaError(MediaErrorCode.permissionDenied, '无法读取选中的本地文件。');
    }
    await validateLocalMediaReferences(path);
    cancellation.throwIfCancelled();
    final output = await runner.run(
      ffprobePath,
      [
        '-v',
        'error',
        '-protocol_whitelist',
        'file,pipe',
        '-show_format',
        '-show_streams',
        '-of',
        'json',
        path,
      ],
      cancellation,
      timeout: const Duration(minutes: 2),
    );
    if (output.exitCode != 0 || output.stderr.trim().isNotEmpty) {
      throw MediaError(
        MediaErrorCode.corruptedMedia,
        '无法识别媒体，文件可能损坏或格式不受支持。',
        backend: id,
        exitCode: output.exitCode,
      );
    }
    try {
      return parseFfprobe(
        jsonDecode(output.stdout) as Map<String, dynamic>,
        fileBytes: await file.length(),
      );
    } on FormatException {
      throw MediaError(
        MediaErrorCode.corruptedMedia,
        '媒体探测返回了不完整数据，未继续转换。',
        backend: id,
      );
    }
  }

  static const videoFormats = {'mp4', 'mkv', 'mov', 'webm'};
  static const audioEncoders = {
    'mp3': 'libmp3lame',
    'wav': 'pcm_s16le',
    'flac': 'flac',
    'aac': 'aac',
    'm4a': 'aac',
    'ogg': 'libvorbis',
    'opus': 'libopus',
  };
  static const videoEncoders = {
    'h264': 'libopenh264',
    'hevc': 'libkvazaar',
    'av1': 'libaom-av1',
    'vp9': 'libvpx-vp9',
  };

  @override
  bool supports(MediaProbe input, MediaJob job) =>
      (input.kind == MediaKind.video &&
          videoFormats.contains(job.outputFormat)) ||
      (input.streams.any((s) => s.type == 'audio') &&
          audioEncoders.containsKey(job.outputFormat));

  bool canRemux(MediaProbe input, String target) {
    final streams = input.streams.where((s) => !s.attachedPicture).toList();
    if (streams.isEmpty) return false;
    return streams.every(
      (stream) => switch ((target, stream.type)) {
        ('mp4' || 'mov', 'video') => {
          'h264',
          'hevc',
          'av1',
          'mpeg4',
        }.contains(stream.codec),
        ('mp4' || 'mov', 'audio') => {
          'aac',
          'mp3',
          'alac',
        }.contains(stream.codec),
        ('mp4' || 'mov', 'subtitle') => stream.codec == 'mov_text',
        ('webm', 'video') => {'vp8', 'vp9', 'av1'}.contains(stream.codec),
        ('webm', 'audio') => {'opus', 'vorbis'}.contains(stream.codec),
        ('webm', 'subtitle') => stream.codec == 'webvtt',
        ('mkv', 'video') => {
          'h264',
          'hevc',
          'av1',
          'vp8',
          'vp9',
          'mpeg4',
          'ffv1',
        }.contains(stream.codec),
        ('mkv', 'audio') => {
          'aac',
          'mp3',
          'flac',
          'opus',
          'vorbis',
          'pcm_s16le',
        }.contains(stream.codec),
        ('mkv', 'subtitle') => {
          'subrip',
          'ass',
          'webvtt',
        }.contains(stream.codec),
        _ => false,
      },
    );
  }

  List<String> encodingArguments(
    MediaProbe input,
    String target, {
    bool forceTranscode = false,
    TranscodeOptions options = const TranscodeOptions(),
  }) {
    options.validate();
    if (options.changesAudio && !input.streams.any((s) => s.type == 'audio')) {
      throw const MediaError(
        MediaErrorCode.invalidParameters,
        '当前文件没有可调整的音频流。',
      );
    }
    final explicitlyForced = forceTranscode;
    forceTranscode =
        forceTranscode || options.changesVideo || options.changesAudio;
    if (audioEncoders.containsKey(target)) {
      final covers = input.streams.where((s) => s.attachedPicture).toList();
      if (covers.isNotEmpty &&
          (!{'mp3', 'flac', 'm4a'}.contains(target) ||
              covers.any((s) => !{'mjpeg', 'png'}.contains(s.codec)))) {
        throw const MediaError(
          MediaErrorCode.unsupportedCodec,
          '目标格式尚不能可靠保留此封面，请选择 MP3、FLAC 或 M4A。',
        );
      }
      final encoder = audioEncoders[target]!;
      if (!verifiedEncoders.contains(encoder)) {
        throw const MediaError(
          MediaErrorCode.encoderUnavailable,
          '当前版本没有可用的音频编码器。',
        );
      }
      final audio = input.streams.firstWhere((s) => s.type == 'audio');
      final copy =
          !forceTranscode &&
          {
                'flac': 'flac',
                'aac': 'aac',
                'm4a': 'aac',
                'mp3': 'mp3',
                'opus': 'opus',
              }[target] ==
              audio.codec;
      if (options.audioKbps != null && {'flac', 'wav'}.contains(target)) {
        throw const MediaError(
          MediaErrorCode.invalidParameters,
          '无损音频不使用有损码率参数。',
        );
      }
      return [
        '-map',
        '0:a:0',
        if (covers.isEmpty)
          '-vn'
        else ...[
          '-map',
          '0:v?',
          '-c:v',
          'copy',
          '-disposition:v',
          'attached_pic',
        ],
        '-c:a',
        copy ? 'copy' : encoder,
        if (!copy) ..._audioOptions(options),
      ];
    }
    if (!forceTranscode && canRemux(input, target)) {
      return ['-map', '0', '-c', 'copy'];
    }
    // Never silently lose subtitles or cover/data streams during fallback.
    if (input.streams.any(
      (s) => s.type != 'video' && s.type != 'audio' || s.attachedPicture,
    )) {
      throw const MediaError(
        MediaErrorCode.unsupportedCodec,
        '目标格式不能完整保留当前流，请选择兼容容器。',
      );
    }
    final codec =
        options.videoCodec ??
        (target == 'webm'
            ? (verifiedEncoders.contains('libvpx-vp9') ? 'vp9' : 'av1')
            : 'h264');
    final video = videoEncoders[codec];
    if (video == null ||
        (target == 'webm' && !{'vp9', 'av1'}.contains(codec)) ||
        (target == 'mov' && codec == 'vp9')) {
      throw const MediaError(MediaErrorCode.invalidParameters, '所选编码与容器不兼容。');
    }
    final audio = target == 'webm' ? 'libopus' : 'aac';
    bool compatibleStreams(String type) => canRemux(
      MediaProbe(
        kind: input.kind,
        format: input.format,
        bytes: input.bytes,
        streams: input.streams.where((s) => s.type == type).toList(),
      ),
      target,
    );
    final copyVideo =
        !explicitlyForced &&
        !options.changesVideo &&
        compatibleStreams('video');
    final copyAudio =
        !explicitlyForced &&
        !options.changesAudio &&
        compatibleStreams('audio');
    final hasAudio = input.streams.any((s) => s.type == 'audio');
    final alignment = codec == 'hevc' ? 8 : 2;
    final filters = [
      if (options.width != null)
        'scale=${options.width}:${options.height}:force_original_aspect_ratio=decrease:force_divisible_by=2',
      'pad=ceil(iw/$alignment)*$alignment:ceil(ih/$alignment)*$alignment:(ow-iw)/2:(oh-ih)/2',
    ];
    if ((!copyVideo && !verifiedEncoders.contains(video)) ||
        (hasAudio && !copyAudio && !verifiedEncoders.contains(audio))) {
      throw const MediaError(
        MediaErrorCode.encoderUnavailable,
        '当前版本没有可用的转码编码器。',
      );
    }
    return [
      '-map',
      '0:v?',
      '-map',
      '0:a?',
      '-c:v',
      copyVideo ? 'copy' : video,
      if (!copyVideo) ...[
        '-pix_fmt',
        'yuv420p',
        '-b:v',
        '${options.videoKbps ?? 4000}k',
        '-threads',
        '2',
        if (codec == 'av1') ...['-cpu-used', '6'],
        '-vf',
        filters.join(','),
        if (options.framesPerSecond != null) ...[
          '-r',
          '${options.framesPerSecond}',
        ],
      ],
      '-c:a',
      copyAudio ? 'copy' : audio,
      if (!copyAudio) ..._audioOptions(options),
    ];
  }

  List<String> _audioOptions(TranscodeOptions options) => [
    if (options.audioKbps != null) ...['-b:a', '${options.audioKbps}k'],
    if (options.sampleRate != null) ...['-ar', '${options.sampleRate}'],
    if (options.channels != null) ...['-ac', '${options.channels}'],
  ];

  @override
  Future<MediaResult> execute(
    MediaJob job,
    MediaProbe input,
    CancellationToken cancellation,
    ProgressCallback onProgress,
  ) async {
    var args = job.audioPath != null
        ? <String>[]
        : encodingArguments(
            input,
            job.outputFormat,
            forceTranscode: job.forceTranscode,
            options: job.transcode,
          );
    if (job.audioPath case final audioPath?) {
      final audio = await probe(audioPath, cancellation);
      if (!videoFormats.contains(job.outputFormat) ||
          input.streams.where((s) => s.type == 'video').length != 1 ||
          input.streams.any(
            (s) =>
                (s.type != 'video' && s.type != 'audio') || s.attachedPicture,
          ) ||
          audio.kind != MediaKind.audio ||
          audio.streams.where((s) => s.type == 'audio').length != 1) {
        throw const MediaError(
          MediaErrorCode.unsupportedCodec,
          '替换音轨需要单视频流和单音轨；字幕或附加流尚不能可靠保留。',
        );
      }
      final combined = MediaProbe(
        kind: MediaKind.video,
        format: input.format,
        bytes: input.bytes + audio.bytes,
        streams: [
          ...input.streams.where((s) => s.type == 'video'),
          ...audio.streams.where((s) => s.type == 'audio'),
        ],
      );
      final combinedArgs = encodingArguments(
        combined,
        job.outputFormat,
        forceTranscode: job.forceTranscode,
        options: job.transcode,
      );
      // Input 0 owns the video, input 1 supplies the explicitly selected audio.
      args = ['-map', '0:v:0', '-map', '1:a:0'];
      for (var i = 0; i < combinedArgs.length; i++) {
        if (combinedArgs[i] == '-map') {
          i++;
        } else {
          args.add(combinedArgs[i]);
        }
      }
      if (input.duration case final duration? when duration > Duration.zero) {
        args.addAll(['-t', '${duration.inMicroseconds / 1000000}']);
      }
    }
    final temp = await TempFileManager.create(
      job.outputDirectory,
      job.outputFormat,
    );
    final watch = Stopwatch()..start();
    try {
      cancellation.throwIfCancelled();
      onProgress(const MediaProgress(MediaStage.processing));
      final output = await runner.run(
        ffmpegPath,
        [
          '-hide_banner',
          '-v',
          'error',
          '-n',
          '-protocol_whitelist',
          'file,pipe',
          '-i',
          job.inputPath,
          if (job.audioPath != null) ...[
            '-protocol_whitelist',
            'file,pipe',
            '-i',
            job.audioPath!,
          ],
          ...args,
          '-map_metadata',
          job.transcode.stripMetadata ? '-1' : '0',
          '-progress',
          'pipe:1',
          '-nostats',
          temp.file.path,
        ],
        cancellation,
        onLine: (line) {
          if (line.startsWith('out_time_us=')) {
            final time = int.tryParse(line.substring('out_time_us='.length));
            if (time != null && time >= 0) {
              onProgress(
                MediaProgress(
                  MediaStage.processing,
                  processed: Duration(microseconds: time),
                  total: input.duration,
                ),
              );
            }
          }
        },
      );
      if (output.exitCode != 0) {
        throw MediaError(
          MediaErrorCode.processFailed,
          '媒体转换失败，请检查编码兼容性及磁盘空间。',
          backend: id,
          exitCode: output.exitCode,
        );
      }
      cancellation.throwIfCancelled();
      onProgress(const MediaProgress(MediaStage.finalizing));
      final verified = await probe(temp.file.path, cancellation);
      if (verified.bytes == 0) {
        throw const MediaError(MediaErrorCode.processFailed, '输出文件为空。');
      }
      cancellation.throwIfCancelled();
      final published = await temp.publish(
        job.outputStem ?? p.basenameWithoutExtension(job.inputPath),
        job.outputFormat,
      );
      return MediaResult(
        jobId: job.id,
        stage: MediaStage.completed,
        outputPath: published,
        probe: verified,
        elapsed: watch.elapsed,
      );
    } finally {
      await temp.dispose();
    }
  }
}
