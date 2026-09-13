import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/image_engine.dart';
import '../../core/services/image_inspector.dart';

Future<CropRegion?> showCropEditor(
  BuildContext context, {
  required String path,
  ResizeOptions? resize,
  CropRegion? initial,
}) => showDialog<CropRegion>(
  context: context,
  builder: (_) => CropDialog(path: path, resize: resize, initial: initial),
);

class CropDialog extends StatefulWidget {
  const CropDialog({super.key, required this.path, this.resize, this.initial});
  final String path;
  final ResizeOptions? resize;
  final CropRegion? initial;
  @override
  State<CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<CropDialog> {
  late final Future<ImageInspection> image = const ImageInspector().inspect(
    widget.path,
    previewSize: 1024,
    resize: widget.resize,
  );
  late Rect region = widget.initial == null
      ? const Rect.fromLTWH(.1, .1, .8, .8)
      : Rect.fromLTWH(
          widget.initial!.left,
          widget.initial!.top,
          widget.initial!.width,
          widget.initial!.height,
        );
  double ratio = 0;
  bool resizing = false;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '裁剪画面',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭裁剪',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('拖动画框移动，拖动右下角调整大小。裁剪范围应用于所选图片，先调整尺寸，再裁剪。'),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<ImageInspection>(
                future: image,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(child: Text('无法载入裁剪预览，请检查输入图片。'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final info = snap.data!;
                  final imageRatio = info.width / info.height;
                  return Column(
                    children: [
                      DropdownButtonFormField<double>(
                        key: ValueKey(ratio),
                        initialValue: ratio,
                        decoration: const InputDecoration(labelText: '裁剪比例'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('自由裁剪')),
                          DropdownMenuItem(value: 1, child: Text('1 : 1')),
                          DropdownMenuItem(value: 4 / 3, child: Text('4 : 3')),
                          DropdownMenuItem(value: 3 / 4, child: Text('3 : 4')),
                          DropdownMenuItem(
                            value: 16 / 9,
                            child: Text('16 : 9'),
                          ),
                          DropdownMenuItem(
                            value: 9 / 16,
                            child: Text('9 : 16'),
                          ),
                          DropdownMenuItem(value: 3 / 2, child: Text('3 : 2')),
                          DropdownMenuItem(value: 2 / 3, child: Text('2 : 3')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            ratio = value!;
                            if (ratio != 0) {
                              final r = ratio / imageRatio;
                              final w = math.min(.9, .9 * r),
                                  h = math.min(.9, .9 / r);
                              region = Rect.fromLTWH(
                                (1 - w) / 2,
                                (1 - h) / 2,
                                w,
                                h,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: imageRatio,
                            child: LayoutBuilder(
                              builder: (context, box) => GestureDetector(
                                onPanStart: (event) {
                                  resizing =
                                      (event.localPosition -
                                              Offset(
                                                region.right * box.maxWidth,
                                                region.bottom * box.maxHeight,
                                              ))
                                          .distance <
                                      44;
                                },
                                onPanUpdate: (event) {
                                  setState(() {
                                    final dx = event.delta.dx / box.maxWidth,
                                        dy = event.delta.dy / box.maxHeight;
                                    if (resizing) {
                                      var w = (region.width + dx).clamp(
                                        .02,
                                        1 - region.left,
                                      );
                                      var h = (region.height + dy).clamp(
                                        .02,
                                        1 - region.top,
                                      );
                                      if (ratio > 0) {
                                        final r = ratio / imageRatio;
                                        h = w / r;
                                        if (h > 1 - region.top) {
                                          h = 1 - region.top;
                                          w = h * r;
                                        }
                                      }
                                      region = Rect.fromLTWH(
                                        region.left,
                                        region.top,
                                        w,
                                        h,
                                      );
                                    } else {
                                      region = Rect.fromLTWH(
                                        (region.left + dx).clamp(
                                          0,
                                          1 - region.width,
                                        ),
                                        (region.top + dy).clamp(
                                          0,
                                          1 - region.height,
                                        ),
                                        region.width,
                                        region.height,
                                      );
                                    }
                                  });
                                },
                                child: CustomPaint(
                                  foregroundPainter: CropPainter(region),
                                  child: Image.memory(
                                    info.thumbnail,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '裁剪后约 ${(info.width * region.width).floor()} × ${(info.height * region.height).floor()} px',
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    region = const Rect.fromLTWH(0, 0, 1, 1);
                    ratio = 0;
                  }),
                  child: const Text('重置范围'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CropRegion(
                      region.left,
                      region.top,
                      region.width,
                      region.height,
                    ),
                  ),
                  child: const Text('应用裁剪'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class CropPainter extends CustomPainter {
  const CropPainter(this.region);
  final Rect region;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      region.left * size.width,
      region.top * size.height,
      region.width * size.width,
      region.height * size.height,
    );
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .5));
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(rect.left + rect.width * i / 3, rect.top),
        Offset(rect.left + rect.width * i / 3, rect.bottom),
        Paint()..color = Colors.white54,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + rect.height * i / 3),
        Offset(rect.right, rect.top + rect.height * i / 3),
        Paint()..color = Colors.white54,
      );
    }
    canvas.drawCircle(rect.bottomRight, 10, Paint()..color = Colors.white);
    canvas.drawCircle(rect.bottomRight, 5, Paint()..color = Colors.teal);
  }

  @override
  bool shouldRepaint(CropPainter oldDelegate) => oldDelegate.region != region;
}
