import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/media_workspace_controller.dart';
import '../../core/media/backend/ffmpeg_backend.dart';
import '../../core/media/model/media.dart';
import '../../core/media/model/transcode_options.dart';
import '../../core/models/conversion_task.dart';

class MediaOptionsDialog extends StatefulWidget {
  const MediaOptionsDialog({
    super.key,
    required this.entry,
    required this.encoders,
  });
  final MediaEntry entry;
  final Set<String> encoders;
  @override
  State<MediaOptionsDialog> createState() => _MediaOptionsDialogState();
}

class _MediaOptionsDialogState extends State<MediaOptionsDialog> {
  late final entry = widget.entry;
  late final image = entry.probe!.kind == MediaKind.image;
  late final hasAudio = entry.effectiveProbe!.streams.any(
    (s) => s.type == 'audio',
  );
  late final video =
      entry.probe!.kind == MediaKind.video &&
      FfmpegBackend.videoFormats.contains(entry.outputFormat);
  late final controllers = <String, TextEditingController>{
    'width': TextEditingController(
      text: '${image ? entry.resize?.width ?? '' : entry.options.width ?? ''}',
    ),
    'height': TextEditingController(
      text:
          '${image ? entry.resize?.height ?? '' : entry.options.height ?? ''}',
    ),
    'fps': TextEditingController(
      text: '${entry.options.framesPerSecond ?? ''}',
    ),
    'video': TextEditingController(text: '${entry.options.videoKbps ?? ''}'),
    'audio': TextEditingController(text: '${entry.options.audioKbps ?? ''}'),
    'sample': TextEditingController(text: '${entry.options.sampleRate ?? ''}'),
    'quality': TextEditingController(text: '${entry.jpegQuality}'),
  };
  late String? codec = entry.options.videoCodec;
  late int? channels = entry.options.channels;
  late bool strip = entry.options.stripMetadata;
  String? error;
  int? value(String key) => int.tryParse(controllers[key]!.text);
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String key, String label) => SizedBox(
    width: 210,
    child: TextField(
      controller: controllers[key],
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, hintText: '留空保持原样'),
    ),
  );

  void save() {
    try {
      if (controllers.values.any(
        (c) => c.text.isNotEmpty && int.tryParse(c.text) == null,
      )) {
        throw const MediaError(
          MediaErrorCode.invalidParameters,
          '参数数值过大，请重新填写。',
        );
      }
      final width = value('width'), height = value('height');
      if (image &&
          ((width == null) != (height == null) ||
              (width != null &&
                  (width < 1 ||
                      height! < 1 ||
                      width > 100000 ||
                      height > 100000)))) {
        throw const MediaError(
          MediaErrorCode.invalidParameters,
          '图片宽高必须同时填写有效正整数。',
        );
      }
      if (image &&
          ((value('quality') ?? 0) < 1 || (value('quality') ?? 101) > 100)) {
        throw const MediaError(
          MediaErrorCode.invalidParameters,
          'JPG 质量必须为 1–100。',
        );
      }
      final options = TranscodeOptions(
        videoCodec: video ? codec : null,
        width: video ? width : null,
        height: video ? height : null,
        framesPerSecond: video ? value('fps') : null,
        videoKbps: video ? value('video') : null,
        audioKbps: !image && !{'wav', 'flac'}.contains(entry.outputFormat)
            ? value('audio')
            : null,
        sampleRate: image ? null : value('sample'),
        channels: image ? null : channels,
        stripMetadata: strip,
      );
      options.validate();
      entry.options = options;
      if (image) {
        entry.resize = width == null
            ? null
            : ResizeOptions(width: width, height: height!);
        entry.jpegQuality = value('quality')!;
      }
      Navigator.pop(context, true);
    } on MediaError catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('处理参数'),
    content: SizedBox(
      width: 470,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              image
                  ? '尺寸保持比例且不放大，透明图片转 JPG 使用白底。'
                  : '留空时优先保留原始流。修改尺寸、码率或编码会重新编码；尺寸按比例适应边界，必要时补边。',
            ),
            const SizedBox(height: 18),
            if (video) ...[
              DropdownButtonFormField<String>(
                initialValue: codec ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: '视频编码'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('自动兼容')),
                  for (final item in FfmpegBackend.videoEncoders.entries)
                    if (widget.encoders.contains(item.value) &&
                        (entry.outputFormat != 'webm' ||
                            {'vp9', 'av1'}.contains(item.key)) &&
                        (entry.outputFormat != 'mov' || item.key != 'vp9'))
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(item.key.toUpperCase()),
                      ),
                ],
                onChanged: (v) => setState(() => codec = v == '' ? null : v),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                if (image || video) ...[
                  field('width', '最大宽度 px'),
                  field('height', '最大高度 px'),
                ],
                if (video) ...[
                  field('fps', '帧率 fps'),
                  field('video', '视频码率 kbps'),
                ],
                if (image && entry.outputFormat == 'jpg')
                  field('quality', 'JPG 质量 1–100'),
                if (!image && hasAudio) ...[
                  if (!{'wav', 'flac'}.contains(entry.outputFormat))
                    field('audio', '音频码率 kbps'),
                  field('sample', '采样率 Hz'),
                ],
              ],
            ),
            if (!image && hasAudio) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: channels ?? 0,
                decoration: const InputDecoration(labelText: '声道'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('保持原样')),
                  DropdownMenuItem(value: 1, child: Text('单声道')),
                  DropdownMenuItem(value: 2, child: Text('立体声')),
                ],
                onChanged: (v) => setState(() => channels = v == 0 ? null : v),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: strip,
              title: const Text('清理常见元数据'),
              subtitle: const Text('不保证移除容器或编码数据中的所有标识。'),
              onChanged: (v) => setState(() => strip = v!),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: save, child: const Text('应用')),
    ],
  );
}
