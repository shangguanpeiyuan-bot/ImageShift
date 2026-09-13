import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../application/media_workspace_controller.dart';
import '../../core/media/model/media.dart';
import '../../core/media/model/transcode_options.dart';
import '../../platform/file_access.dart';
import '../widgets/media_options_dialog.dart';
import 'library_pages.dart';

class MediaWorkbenchPage extends StatelessWidget {
  const MediaWorkbenchPage({
    super.key,
    required this.controller,
    this.onHistory,
    this.onPresets,
  });
  final MediaWorkspaceController controller;
  final VoidCallback? onHistory, onPresets;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final theme = Theme.of(context);
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本地媒体工作台', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    c.ffmpeg == null
                        ? '图片在本机处理。当前平台的音视频功能仍在验证中。'
                        : '图片、视频、音频，统一另存新文件。兼容格式优先无损快速转换。',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (c.recoverable.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('发现 ${c.recoverable.length} 项未完成任务'),
                            const Text('队列位置仅暂存 24 小时；恢复后重新检查文件，不自动开始处理。'),
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: c.busy ? null : c.restorePending,
                                  child: const Text('恢复队列'),
                                ),
                                TextButton(
                                  onPressed: c.busy ? null : c.discardRecovery,
                                  child: const Text('丢弃记录'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (onPresets != null)
                        TextButton.icon(
                          onPressed: onPresets,
                          icon: const Icon(Icons.bookmarks_outlined),
                          label: const Text('预设'),
                        ),
                      if (onHistory != null)
                        TextButton.icon(
                          onPressed: onHistory,
                          icon: const Icon(Icons.history),
                          label: const Text('历史'),
                        ),
                      FilledButton.icon(
                        onPressed: c.busy ? null : c.pick,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('导入文件'),
                      ),
                      if (Platform.isWindows && c.ffmpeg != null)
                        OutlinedButton.icon(
                          onPressed: c.busy
                              ? null
                              : () async {
                                  final path = await getDirectoryPath(
                                    confirmButtonText: '选择本地缓存目录',
                                  );
                                  if (path != null) {
                                    await c.importFiles([
                                      ImportedFile(
                                        path,
                                        path.split(Platform.pathSeparator).last,
                                      ),
                                    ]);
                                  }
                                },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('导入本地缓存'),
                        ),
                      OutlinedButton.icon(
                        onPressed: c.busy ? null : c.chooseOutput,
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: const Text('输出位置'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            c.busy || c.output == null || c.entries.isEmpty
                            ? null
                            : c.start,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始 / 重试失败项'),
                      ),
                      if (c.busy)
                        OutlinedButton.icon(
                          onPressed: c.cancel,
                          icon: const Icon(Icons.stop),
                          label: const Text('取消'),
                        ),
                    ],
                  ),
                  if (c.output != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '保存到：${c.output!.label}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (c.ffmpeg != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('强制重新编码'),
                      subtitle: const Text('默认关闭：兼容时保留原始音视频流，避免重复压缩'),
                      value: c.forceTranscode,
                      onChanged: c.busy
                          ? null
                          : (v) {
                              c.forceTranscode = v!;
                              c.refresh();
                            },
                    ),
                  if (c.message != null)
                    Text(
                      c.message!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (c.entries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.perm_media_outlined, size: 52),
                      SizedBox(height: 16),
                      Text('添加你的本地媒体'),
                      SizedBox(height: 8),
                      Text('按文件内容识别格式，原文件始终保留。', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.builder(
                itemCount: c.entries.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _entry(context, c.entries[index]),
                ),
              ),
            ),
          if (c.entries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${c.entries.length} 个文件 · ${c.entries.where((e) => e.finished).length} 个完成',
                    ),
                    if (c.output != null && c.entries.any((e) => e.finished))
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await c.files.openOutput(c.output!);
                          } catch (_) {
                            c.message = '无法打开输出位置，请使用系统文件管理器查看。';
                            c.refresh();
                          }
                        },
                        icon: const Icon(Icons.folder_open),
                        label: const Text('查看输出'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _entry(BuildContext context, MediaEntry entry) {
    final c = controller;
    final theme = Theme.of(context);
    final formats = c.outputs(entry);
    final stage = switch (entry.progress.stage) {
      MediaStage.queued => '等待处理',
      MediaStage.probing => '识别中',
      MediaStage.preparing => '准备中',
      MediaStage.processing => '处理中',
      MediaStage.finalizing => '校验并保存',
      MediaStage.completed => '已完成',
      MediaStage.failed => '失败',
      MediaStage.cancelled => '已取消',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(switch (entry.probe?.kind) {
                  MediaKind.image => Icons.image_outlined,
                  MediaKind.video => Icons.movie_outlined,
                  MediaKind.audio => Icons.audiotrack_outlined,
                  _ => Icons.insert_drive_file_outlined,
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: '从列表移除（保留原文件）',
                  onPressed: c.busy ? null : () => c.remove(entry),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (entry.probe case final probe?)
              Text(
                '${probe.format.toUpperCase()} · ${(probe.bytes / 1048576).toStringAsFixed(2)} MiB'
                '${probe.width == null ? '' : ' · ${probe.width} × ${probe.height}'}'
                '${probe.duration == null ? '' : ' · ${(probe.duration!.inMilliseconds / 1000).toStringAsFixed(1)} 秒'}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            if (entry.replacementAudioName != null)
              Text('替换音轨：${entry.replacementAudioName}（保持视频时长，较短音轨结束后无音频）'),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (formats.isNotEmpty)
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: entry.outputFormat,
                      decoration: const InputDecoration(
                        labelText: '输出格式',
                        isDense: true,
                      ),
                      items: [
                        for (final format in formats)
                          DropdownMenuItem(
                            value: format,
                            child: Text(format.toUpperCase()),
                          ),
                      ],
                      onChanged: c.busy || entry.finished
                          ? null
                          : (value) async {
                              entry.outputFormat = value!;
                              entry.options = TranscodeOptions(
                                stripMetadata: entry.options.stripMetadata,
                              );
                              c.refresh();
                              await c.saveRecovery();
                            },
                    ),
                  ),
                Text(
                  stage,
                  style: TextStyle(
                    color: entry.error == null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
                if (entry.probe?.kind == MediaKind.video &&
                    (entry.audioPath == null ||
                        entry.replacementAudioName != null))
                  TextButton.icon(
                    onPressed: c.busy || entry.finished
                        ? null
                        : () => c.chooseReplacementAudio(entry),
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('替换音轨'),
                  ),
                if (entry.probe != null)
                  TextButton.icon(
                    onPressed: c.busy || entry.finished
                        ? null
                        : () async {
                            await showDialog<bool>(
                              context: context,
                              builder: (_) => MediaOptionsDialog(
                                entry: entry,
                                encoders: c.ffmpeg?.verifiedEncoders ?? {},
                              ),
                            );
                            c.refresh();
                            await c.saveRecovery();
                          },
                    icon: const Icon(Icons.tune),
                    label: const Text('参数'),
                  ),
                if (entry.probe != null &&
                    c.library != null &&
                    entry.audioPath == null)
                  TextButton.icon(
                    onPressed: c.busy
                        ? null
                        : () async {
                            final name = await promptPresetName(
                              context,
                              '保存媒体参数',
                            );
                            if (name != null) await c.savePreset(entry, name);
                          },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('存为预设'),
                  ),
                if (entry.result?.elapsed case final elapsed?)
                  Text(
                    '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
                  ),
              ],
            ),
            if (entry.progress.stage == MediaStage.processing ||
                entry.progress.stage == MediaStage.finalizing)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(value: entry.progress.fraction),
              ),
            if (entry.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  entry.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (entry.published != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  entry.published!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
