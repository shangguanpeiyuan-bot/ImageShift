import 'package:flutter/material.dart';

import '../../application/workspace_controller.dart';
import '../widgets/brand_mark.dart';

const toolDefinitions = <(IconData, String, String)>[
  (Icons.swap_horiz_rounded, '格式转换', 'JPG、PNG、无损 WebP'),
  (Icons.layers_outlined, '批量处理', '多张图片，一次完成'),
  (Icons.compress_rounded, '图片压缩', '调整体积，保留所需细节'),
  (Icons.photo_size_select_large_rounded, '调整尺寸', '按比例、边长或指定尺寸'),
  (Icons.crop_rounded, '裁剪图片', '为画面找到更好的构图'),
  (Icons.rotate_90_degrees_ccw_rounded, '旋转与翻转', '轻松调整画面方向'),
  (Icons.info_outline_rounded, '图片信息', '查看真实格式与元数据'),
  (Icons.cleaning_services_outlined, '清理元数据', '生成不带已知标签的新图片'),
];

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onTool,
    this.toolsOnly = false,
    this.onImportMedia,
  });
  final WorkspaceController controller;
  final void Function(int) onTool;
  final bool toolsOnly;
  final VoidCallback? onImportMedia;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        return ListView(
          padding: EdgeInsets.all(compact ? 20 : 36),
          children: [
            if (!toolsOnly) ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: colors.primary),
                  Text(
                    '本地处理 · 原文件安全',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '你的媒体，\n在本地自在转换。',
                style: compact
                    ? theme.textTheme.headlineMedium
                    : theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                '图片、视频、音频，一个本地工作台',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: EdgeInsets.all(compact ? 24 : 34),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .3),
                  ),
                ),
                child: Column(
                  children: [
                    const BrandMark(size: 58),
                    const SizedBox(height: 18),
                    Text(
                      theme.platform == TargetPlatform.windows
                          ? '拖入文件，即刻开始'
                          : '选择文件，即刻开始',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '自动识别图片、视频、音频与已支持的本地缓存\n始终另存新文件，媒体内容不会上传',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : onImportMedia ?? controller.pickImages,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('导入文件'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              OutlinedButton.icon(
                onPressed: () => controller.navigate(8),
                icon: const Icon(Icons.perm_media_outlined),
                label: const Text('打开本地媒体工作台'),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    toolsOnly ? '图片工具' : '常用工具',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (!compact)
                  Text(
                    '每一步，都在本机完成',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (_, box) {
                final columns = box.maxWidth >= 1000
                    ? 4
                    : box.maxWidth >= 520
                    ? 2
                    : 1;
                final width = (box.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: List.generate(toolDefinitions.length, (index) {
                    final tool = toolDefinitions[index];
                    return SizedBox(
                      width: width,
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onTool(index),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                      alpha: .08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    tool.$1,
                                    color: colors.primary,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tool.$2,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tool.$3,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '所有图片处理均在本地完成，不会上传至服务器。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
