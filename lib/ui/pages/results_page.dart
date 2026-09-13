import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/workspace_controller.dart';
import '../../core/image_engine.dart';
import '../theme.dart';
import '../widgets/preview_panel.dart';
import '../widgets/status_badge.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  Timer? ticker;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.queue.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, q = c.queue;
    final colors = Theme.of(context).colorScheme;
    if (q.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 52, color: colors.outline),
            const SizedBox(height: 16),
            Text('准备好后，从工作台开始', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('处理进度与结果将显示在这里。'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => c.navigate(1),
              child: const Text('前往工作台'),
            ),
          ],
        ),
      );
    }
    final current = q.entries
        .where((e) => e.status == TaskStatus.processing)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          q.isRunning ? '正在处理图片' : '本轮处理结果',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(q.isRunning ? '按顺序在本机处理；原始文件保持安全。' : '每个成功结果都已保存为新文件。'),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${q.completed} / ${q.entries.length} 项已结束',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text('${q.elapsed.inSeconds} 秒'),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: q.entries.isEmpty ? 0 : q.completed / q.entries.length,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(5),
                ),
                if (current != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '正在处理：${c.assets.where((a) => a.id == current.task.id).firstOrNull?.file.name ?? '图片'}',
                    ),
                  ),
                if (q.isRunning)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: q.cancellationRequested ? null : q.cancel,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(
                        q.cancellationRequested ? '正在结束当前文件…' : '取消剩余任务',
                      ),
                    ),
                  ),
                if (q.cancellationRequested)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('未开始的任务已取消。当前文件完成安全保存后结束，成功结果会保留。'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final state in [
              TaskStatus.succeeded,
              TaskStatus.failed,
              TaskStatus.cancelled,
            ])
              SizedBox(
                width: 150,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(state),
                        const SizedBox(height: 10),
                        Text(
                          '${q.count(state)}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '成功项：${formatBytes(q.inputBytes)} → ${formatBytes(q.outputBytes)} · ${sizeChange(q.inputBytes, q.outputBytes)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: q.count(TaskStatus.succeeded) == 0
                  ? null
                  : c.openOutput,
              icon: const Icon(Icons.folder_open),
              label: const Text('打开输出位置'),
            ),
            OutlinedButton.icon(
              onPressed: q.isRunning || q.count(TaskStatus.failed) == 0
                  ? null
                  : () => c.start(retryFailed: true),
              icon: const Icon(Icons.refresh),
              label: const Text('重试失败项'),
            ),
            TextButton(
              onPressed: () => c.navigate(1),
              child: const Text('返回工作台'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final entry in q.entries) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _resultRow(context, entry),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _resultRow(BuildContext context, QueueEntry entry) {
    final asset = widget.controller.assets
        .where((a) => a.id == entry.task.id)
        .firstOrNull;
    final result = entry.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                asset?.file.name ?? '图片',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(entry.status),
          ],
        ),
        if (result is ConversionSuccess) ...[
          const SizedBox(height: 8),
          Text(
            '${result.inputFormat.label} → ${result.outputFormat.label} · ${result.width} × ${result.height} px',
          ),
          Text(
            '${formatBytes(result.inputBytes)} → ${formatBytes(result.outputBytes)} · ${sizeChange(result.inputBytes, result.outputBytes)}',
          ),
          SelectableText(
            asset?.publishedPath ?? result.outputPath,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (asset != null)
            TextButton.icon(
              onPressed: () => showImageDetails(context, asset, compare: true),
              icon: const Icon(Icons.compare_outlined, size: 19),
              label: const Text('转换前后对比'),
            ),
        ],
        if (result is ConversionFailure)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              result.error.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
