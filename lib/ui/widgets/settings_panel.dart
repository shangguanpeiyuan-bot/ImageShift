import 'package:flutter/material.dart';

import '../../application/editor_settings.dart';
import '../../application/workspace_controller.dart';
import '../../core/image_engine.dart';
import 'crop_dialog.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final s = controller.settings;
    final colors = Theme.of(context).colorScheme;
    return AbsorbPointer(
      absorbing: controller.busy,
      child: Card(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('处理参数', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '统一应用于所选图片',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _section(
              context,
              Icons.swap_horiz,
              '格式与压缩',
              expanded: true,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('保持输入格式'),
                  subtitle: const Text('仅 JPG / PNG / WebP 可保持格式'),
                  value: s.keepFormat,
                  onChanged: (v) => controller.edit((s) => s.keepFormat = v),
                ),
                if (!s.keepFormat)
                  DropdownButtonFormField<RasterFormat>(
                    key: ValueKey(s.format),
                    initialValue: s.format,
                    decoration: const InputDecoration(labelText: '输出格式'),
                    items: supportedOutputFormats
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              f == RasterFormat.webp ? 'WebP · 无损' : f.label,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => controller.edit((s) => s.format = v!),
                  ),
                if (s.keepFormat || s.format == RasterFormat.jpeg) ...[
                  const SizedBox(height: 18),
                  Text(
                    'JPG 质量  ${s.quality}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: s.quality.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${s.quality}',
                    onChanged: (v) =>
                        controller.edit((s) => s.quality = v.round()),
                  ),
                  const Text('质量越低通常体积越小；压缩结果以实际文件为准。'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('bg-${s.backgroundRgb}'),
                    initialValue: [0xffffff, 0].contains(s.backgroundRgb)
                        ? s.backgroundRgb
                        : -1,
                    decoration: const InputDecoration(labelText: '透明区域填充'),
                    items: const [
                      DropdownMenuItem(value: 0xffffff, child: Text('白色')),
                      DropdownMenuItem(value: 0, child: Text('黑色')),
                      DropdownMenuItem(value: -1, child: Text('自定义 RGB')),
                    ],
                    onChanged: (v) => controller.edit(
                      (s) => s.backgroundRgb = v == -1 ? 0xe8eeea : v!,
                    ),
                  ),
                  if (![0xffffff, 0].contains(s.backgroundRgb))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        initialValue: s.backgroundRgb
                            .toRadixString(16)
                            .padLeft(6, '0'),
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '十六进制颜色',
                          prefixText: '#',
                        ),
                        onChanged: (v) {
                          final rgb = int.tryParse(v, radix: 16);
                          if (v.length == 6 && rgb != null) {
                            controller.edit((s) => s.backgroundRgb = rgb);
                          }
                        },
                      ),
                    ),
                ],
                if (s.keepFormat || s.format == RasterFormat.png) ...[
                  const SizedBox(height: 18),
                  Text('PNG 无损压缩等级  ${s.pngCompression}'),
                  Slider(
                    value: s.pngCompression.toDouble(),
                    min: 0,
                    max: 9,
                    divisions: 9,
                    label: '${s.pngCompression}',
                    onChanged: (v) =>
                        controller.edit((s) => s.pngCompression = v.round()),
                  ),
                  const Text('调整编码耗时与体积，不改变像素质量。'),
                ],
                if (s.keepFormat || s.format == RasterFormat.webp)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('WebP 使用无损编码，保留透明；不提供未支持的有损质量参数。'),
                  ),
              ],
            ),
            _section(
              context,
              Icons.photo_size_select_large_outlined,
              '调整尺寸',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用尺寸调整'),
                  value: s.resizeEnabled,
                  onChanged: (v) => controller.edit((s) => s.resizeEnabled = v),
                ),
                if (s.resizeEnabled) ...[
                  DropdownButtonFormField<ResizeMode>(
                    key: ValueKey(s.resizeMode),
                    initialValue: s.resizeMode,
                    decoration: const InputDecoration(labelText: '缩放方式'),
                    items: const [
                      DropdownMenuItem(
                        value: ResizeMode.bounds,
                        child: Text('指定宽高 / 边界框'),
                      ),
                      DropdownMenuItem(
                        value: ResizeMode.percent,
                        child: Text('百分比'),
                      ),
                      DropdownMenuItem(
                        value: ResizeMode.width,
                        child: Text('固定宽度'),
                      ),
                      DropdownMenuItem(
                        value: ResizeMode.height,
                        child: Text('固定高度'),
                      ),
                      DropdownMenuItem(
                        value: ResizeMode.longest,
                        child: Text('最长边'),
                      ),
                      DropdownMenuItem(
                        value: ResizeMode.shortest,
                        child: Text('最短边'),
                      ),
                    ],
                    onChanged: (v) => controller.edit((s) => s.resizeMode = v!),
                  ),
                  const SizedBox(height: 14),
                  if (s.resizeMode == ResizeMode.bounds) ...[
                    Row(
                      children: [
                        Expanded(
                          child: NumberField(
                            label: '宽度 px',
                            value: s.width,
                            onChanged: (v) =>
                                controller.edit((s) => s.width = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NumberField(
                            label: '高度 px',
                            value: s.height,
                            onChanged: (v) =>
                                controller.edit((s) => s.height = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          [
                                (1920, 1080),
                                (1280, 720),
                                (1080, 1080),
                                (1080, 1920),
                                (2560, 1440),
                                (3840, 2160),
                              ]
                              .map(
                                (size) => ActionChip(
                                  label: Text(
                                    '${size.$1}×${size.$2}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () => controller.edit((s) {
                                    s.width = size.$1;
                                    s.height = size.$2;
                                  }),
                                ),
                              )
                              .toList(),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('保持宽高比'),
                      value: s.keepRatio,
                      onChanged: (v) => controller.edit((s) => s.keepRatio = v),
                    ),
                  ] else if (s.resizeMode == ResizeMode.percent) ...[
                    NumberField(
                      label: '缩放百分比 %',
                      value: s.percent,
                      onChanged: (v) => controller.edit((s) => s.percent = v),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [25, 50, 75, 100]
                          .map(
                            (p) => ActionChip(
                              label: Text('$p%'),
                              onPressed: () =>
                                  controller.edit((s) => s.percent = p),
                            ),
                          )
                          .toList(),
                    ),
                  ] else
                    NumberField(
                      label: '边长 px',
                      value: s.edge,
                      onChanged: (v) => controller.edit((s) => s.edge = v),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('禁止放大'),
                    value: s.preventUpscale,
                    onChanged: (v) =>
                        controller.edit((s) => s.preventUpscale = v),
                  ),
                ],
              ],
            ),
            _section(
              context,
              Icons.crop_rotate,
              '裁剪与方向',
              children: [
                OutlinedButton.icon(
                  onPressed: controller.focused?.info == null
                      ? null
                      : () async {
                          final asset = controller.focused!;
                          final crop = await showCropEditor(
                            context,
                            path: asset.file.path,
                            resize: s.resizeFor(
                              asset.info!.width,
                              asset.info!.height,
                            ),
                            initial: s.crop,
                          );
                          if (crop != null) {
                            controller.edit((s) => s.crop = crop);
                          }
                        },
                  icon: const Icon(Icons.crop),
                  label: Text(s.crop == null ? '打开裁剪画布' : '编辑裁剪范围'),
                ),
                if (s.crop != null)
                  TextButton.icon(
                    onPressed: () => controller.edit((s) => s.crop = null),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('关闭裁剪步骤'),
                  ),
                const SizedBox(height: 14),
                Text('旋转 ${(s.quarterTurns % 4) * 90}°'),
                Wrap(
                  spacing: 6,
                  children: [
                    IconButton.outlined(
                      tooltip: '逆时针 90°',
                      onPressed: () => controller.edit((s) => s.quarterTurns--),
                      icon: const Icon(Icons.rotate_left),
                    ),
                    IconButton.outlined(
                      tooltip: '顺时针 90°',
                      onPressed: () => controller.edit((s) => s.quarterTurns++),
                      icon: const Icon(Icons.rotate_right),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          controller.edit((s) => s.quarterTurns += 2),
                      child: const Text('180°'),
                    ),
                    IconButton(
                      tooltip: '重置旋转',
                      onPressed: () =>
                          controller.edit((s) => s.quarterTurns = 0),
                      icon: const Icon(Icons.restart_alt),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('水平翻转'),
                  value: s.flipHorizontal,
                  onChanged: (v) =>
                      controller.edit((s) => s.flipHorizontal = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('垂直翻转'),
                  value: s.flipVertical,
                  onChanged: (v) => controller.edit((s) => s.flipVertical = v),
                ),
              ],
            ),
            _section(
              context,
              Icons.privacy_tip_outlined,
              '元数据',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('清理已知元数据'),
                  value: s.stripMetadata,
                  onChanged: (v) => controller.edit((s) => s.stripMetadata = v),
                ),
                const Text(
                  '清理解码器读到的 EXIF、ICC 和 PNG 文本，再生成新文件。去除 ICC 可能改变色彩显示。',
                ),
                const SizedBox(height: 8),
                const Text(
                  '关闭时也不保证完整保留：JPG 可携带已解析的 EXIF；PNG 可携带文本与 ICC；当前 WebP 编码不写入元数据。无法保证清除所有未知私有标签。',
                ),
              ],
            ),
            _section(
              context,
              Icons.drive_file_rename_outline,
              '批量重命名',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用重命名'),
                  value: s.renameEnabled,
                  onChanged: (v) => controller.edit((s) => s.renameEnabled = v),
                ),
                if (s.renameEnabled) ...[
                  TextFormField(
                    initialValue: s.prefix,
                    decoration: const InputDecoration(labelText: '前缀'),
                    onChanged: (v) => controller.edit((s) => s.prefix = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: s.suffix,
                    decoration: const InputDecoration(labelText: '后缀'),
                    onChanged: (v) => controller.edit((s) => s.suffix = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('用顺序编号替代原名'),
                    value: s.sequence,
                    onChanged: (v) => controller.edit((s) => s.sequence = v),
                  ),
                  if (s.sequence)
                    Row(
                      children: [
                        Expanded(
                          child: NumberField(
                            label: '起始编号',
                            value: s.start,
                            minimum: 0,
                            onChanged: (v) =>
                                controller.edit((s) => s.start = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NumberField(
                            label: '编号位数 1–8',
                            value: s.digits,
                            maximum: 8,
                            onChanged: (v) =>
                                controller.edit((s) => s.digits = v),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  ..._namePreviews(context),
                ],
                const SizedBox(height: 8),
                const Text('同名自动追加 _1、_2…，永不覆盖原图或已有输出。'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('执行顺序', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (s.resizeEnabled) '尺寸',
                      if (s.crop != null) '裁剪',
                      if (s.quarterTurns % 4 != 0 ||
                          s.flipHorizontal ||
                          s.flipVertical)
                        '方向',
                      '格式 / 压缩',
                      if (s.stripMetadata) '清理元数据',
                      if (s.renameEnabled) '命名',
                      '另存新文件',
                    ].join(' → '),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '所有编辑一次编码。清理在编码前执行，避免写入被清理的标签。',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _namePreviews(BuildContext context) {
    final selected = controller.assets
        .where((a) => a.selected && a.info != null)
        .take(3)
        .toList();
    try {
      return List.generate(
        selected.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${selected[i].file.name}\n→ ${controller.proposedName(selected[i], i)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    } catch (_) {
      return [
        Text(
          '请检查编号参数',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ];
    }
  }

  Widget _section(
    BuildContext context,
    IconData icon,
    String title, {
    required List<Widget> children,
    bool expanded = false,
  }) => ExpansionTile(
    initiallyExpanded: expanded,
    leading: Icon(icon, size: 21),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    childrenPadding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
    children: children,
  );
}

class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minimum = 1,
    this.maximum = 16384,
  });
  final String label;
  final int value, minimum, maximum;
  final ValueChanged<int> onChanged;
  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final text = TextEditingController(text: '${widget.value}');
  @override
  void didUpdateWidget(NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        int.tryParse(text.text) != widget.value) {
      text.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: text,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.value < widget.minimum || widget.value > widget.maximum
          ? '${widget.minimum}–${widget.maximum}'
          : null,
    ),
    onChanged: (value) => widget.onChanged(int.tryParse(value) ?? -1),
  );
}
