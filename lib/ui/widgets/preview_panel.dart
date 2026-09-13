import 'package:flutter/material.dart';

import '../../application/workspace_controller.dart';
import '../../core/services/image_inspector.dart';
import '../theme.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final asset = controller.focused;
    final info = controller.preview ?? asset?.info;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '效果预览',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (controller.previewLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  tooltip: '放大查看与图片信息',
                  onPressed: asset?.info == null
                      ? null
                      : () => showImageDetails(context, asset!),
                  icon: const Icon(Icons.open_in_full, size: 18),
                ),
              ],
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: info == null
                      ? const Center(
                          child: Icon(Icons.image_outlined, size: 42),
                        )
                      : InteractiveViewer(
                          minScale: .5,
                          maxScale: 8,
                          child: Center(
                            child: Image.memory(
                              info.thumbnail,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (controller.previewError != null)
              Text(
                controller.previewError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (info != null) ...[
              Text(
                asset!.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${info.width} × ${info.height} px · 预览几何变换',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '编码画质和文件大小请在处理后对比',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void showImageDetails(
  BuildContext context,
  ImageAsset asset, {
  bool compare = false,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => ImageDetailsDialog(asset: asset, compare: compare),
  );
}

class ImageDetailsDialog extends StatefulWidget {
  const ImageDetailsDialog({
    super.key,
    required this.asset,
    required this.compare,
  });
  final ImageAsset asset;
  final bool compare;
  @override
  State<ImageDetailsDialog> createState() => _ImageDetailsDialogState();
}

class _ImageDetailsDialogState extends State<ImageDetailsDialog> {
  late final before = const ImageInspector().inspect(
    widget.asset.file.path,
    previewSize: 2048,
  );
  late final after = widget.compare && widget.asset.output != null
      ? const ImageInspector().inspect(
          widget.asset.output!.outputPath,
          previewSize: 2048,
        )
      : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 1120,
      height: 800,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    after == null ? '图片预览与信息' : '转换前后对比',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭预览',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.asset.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final panes = [
                  _pane('原图', before),
                  if (after != null) _pane('输出', after!),
                ];
                return box.maxWidth >= 700
                    ? Row(
                        children: panes.map((p) => Expanded(child: p)).toList(),
                      )
                    : Column(
                        children: panes.map((p) => Expanded(child: p)).toList(),
                      );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '滚轮 / 双指缩放，拖动平移。默认预览最长边 2048 px；点击 100% 载入完整像素。',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pane(String title, Future<ImageInspection> future) => Padding(
    padding: const EdgeInsets.all(16),
    child: FutureBuilder<ImageInspection>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('$title 无法读取，文件可能已移动。'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final info = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title · ${info.format.label} · ${info.width} × ${info.height} · ${formatBytes(info.bytes)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _ZoomImage(
                info: info,
                path: title == '原图'
                    ? widget.asset.file.path
                    : widget.asset.output!.outputPath,
              ),
            ),
            if (after == null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 155),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text('Alpha 通道：${info.hasAlpha ? '有' : '无'}'),
                      for (final entry in info.metadata.entries)
                        SelectableText('${entry.key}：${entry.value}'),
                      if (info.metadata.isEmpty)
                        const Text('未解析到 EXIF、ICC 或文本标签。'),
                      const Text('仅列出当前解码器读到的字段；未检出不代表文件没有其他元数据。'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _ZoomImage extends StatefulWidget {
  const _ZoomImage({required this.info, required this.path});
  final ImageInspection info;
  final String path;
  @override
  State<_ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<_ZoomImage> {
  final transformation = TransformationController();
  ImageInspection? fullImage;
  bool loading = false;
  Size? previousViewport;
  String? error;
  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final imageSize = Size(widget.info.width / dpr, widget.info.height / dpr);
      final viewport = Size(
        bounds.maxWidth,
        (bounds.maxHeight - 48).clamp(1, double.infinity),
      );
      void fit() {
        final sx = viewport.width / imageSize.width,
            sy = viewport.height / imageSize.height;
        final scale = sx < sy ? sx : sy;
        transformation.value = Matrix4.identity()
          ..setEntry(0, 0, scale)
          ..setEntry(1, 1, scale)
          ..setEntry(0, 3, (viewport.width - imageSize.width * scale) / 2)
          ..setEntry(1, 3, (viewport.height - imageSize.height * scale) / 2);
      }

      if (previousViewport != viewport) {
        previousViewport = viewport;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) fit();
        });
      }
      return Column(
        children: [
          Expanded(
            child: ClipRect(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: InteractiveViewer(
                  transformationController: transformation,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: .001,
                  maxScale: 12,
                  child: SizedBox(
                    width: imageSize.width,
                    height: imageSize.height,
                    child: Image.memory(
                      (fullImage ?? widget.info).thumbnail,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: fit,
                icon: const Icon(Icons.fit_screen, size: 18),
                label: const Text('适应窗口'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        setState(() {
                          loading = true;
                          error = null;
                        });
                        try {
                          final info =
                              fullImage ??
                              await const ImageInspector().inspect(
                                widget.path,
                                fullResolution: true,
                              );
                          if (mounted) {
                            setState(() {
                              fullImage = info;
                              transformation.value = Matrix4.identity();
                            });
                          }
                        } catch (_) {
                          if (mounted) setState(() => error = '无法载入完整像素');
                        } finally {
                          if (mounted) setState(() => loading = false);
                        }
                      },
                child: Text(loading ? '载入中…' : '100%'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
