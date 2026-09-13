import 'package:flutter/material.dart';

import '../../application/workspace_controller.dart';
import '../../core/image_engine.dart';
import '../theme.dart';
import '../widgets/preview_panel.dart';
import '../widgets/settings_panel.dart';
import '../widgets/status_badge.dart';

class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 880;
      final content = Padding(
        padding: EdgeInsets.all(wide ? 24 : 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '图片工作台',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${controller.assets.length} 项 · 已选择 ${controller.selectedCount} 张',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.busy ? null : controller.pickImages,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('添加图片'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (controller.importing)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(),
              ),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: box.maxWidth >= 1200 ? 4 : 5,
                          child: _FileList(controller: controller),
                        ),
                        if (box.maxWidth >= 1200) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: PreviewPanel(controller: controller),
                          ),
                        ],
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 320,
                          child: SettingsPanel(controller: controller),
                        ),
                      ],
                    )
                  : _FileList(controller: controller),
            ),
            const SizedBox(height: 12),
            if (!wide)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.focused?.info == null
                          ? null
                          : () =>
                                showImageDetails(context, controller.focused!),
                      icon: const Icon(Icons.zoom_in),
                      label: const Text('预览 / 信息'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showSettingsSheet(context, controller),
                      icon: const Icon(Icons.tune),
                      label: const Text('处理参数'),
                    ),
                  ),
                ],
              ),
            if (!wide) const SizedBox(height: 10),
            _OutputBar(controller: controller, wide: wide),
          ],
        ),
      );
      return box.maxHeight < 500
          ? SingleChildScrollView(child: SizedBox(height: 670, child: content))
          : content;
    },
  );
}

void showSettingsSheet(BuildContext context, WorkspaceController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ListenableBuilder(
        listenable: controller,
        builder: (context, child) => Scaffold(
          appBar: AppBar(title: const Text('处理参数')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SettingsPanel(controller: controller),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FileList extends StatelessWidget {
  const _FileList({required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final visible = controller.visibleAssets;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索文件名',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) {
                controller.search = value;
                controller.refresh();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  PopupMenuButton<String>(
                    tooltip: '按处理状态筛选',
                    onSelected: (value) {
                      controller.filterStatus = value.isEmpty
                          ? null
                          : TaskStatus.values.byName(value);
                      controller.refresh();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: '', child: Text('全部状态')),
                      ...TaskStatus.values.map(
                        (s) => PopupMenuItem(
                          value: s.name,
                          child: Text(statusLabel(s)),
                        ),
                      ),
                    ],
                    child: Chip(
                      label: Text(
                        controller.filterStatus == null
                            ? '全部状态'
                            : statusLabel(controller.filterStatus!),
                      ),
                      avatar: const Icon(Icons.filter_list, size: 17),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '按真实格式筛选',
                    onSelected: (value) {
                      controller.filterFormat = value.isEmpty
                          ? null
                          : RasterFormat.values.byName(value);
                      controller.refresh();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: '', child: Text('全部格式')),
                      ...controller.assets
                          .map((a) => a.info?.format)
                          .whereType<RasterFormat>()
                          .toSet()
                          .map(
                            (f) => PopupMenuItem(
                              value: f.name,
                              child: Text(f.label),
                            ),
                          ),
                    ],
                    child: Chip(
                      label: Text(controller.filterFormat?.label ?? '全部格式'),
                      avatar: const Icon(Icons.image_outlined, size: 17),
                    ),
                  ),
                  PopupMenuButton<FileSort>(
                    tooltip: '排序',
                    icon: const Icon(Icons.sort, size: 20),
                    onSelected: (value) {
                      controller.sort = value;
                      controller.refresh();
                    },
                    itemBuilder: (_) => [
                      for (final pair in [
                        (FileSort.name, '按名称'),
                        (FileSort.size, '按大小'),
                        (FileSort.resolution, '按分辨率'),
                        (FileSort.format, '按格式'),
                      ])
                        PopupMenuItem(value: pair.$1, child: Text(pair.$2)),
                    ],
                  ),
                  IconButton(
                    tooltip: controller.ascending ? '当前升序，切换降序' : '当前降序，切换升序',
                    onPressed: () {
                      controller.ascending = !controller.ascending;
                      controller.refresh();
                    },
                    icon: Icon(
                      controller.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value:
                    controller.selectedCount > 0 &&
                    controller.selectedCount ==
                        controller.assets.where((a) => a.info != null).length,
                onChanged: controller.busy
                    ? null
                    : (value) => controller.selectAll(value!),
              ),
              const Text('全选'),
              const Spacer(),
              IconButton(
                tooltip: '移除选中项',
                onPressed: controller.busy || controller.selectedCount == 0
                    ? null
                    : controller.removeSelected,
                icon: const Icon(Icons.remove_circle_outline, size: 21),
              ),
              TextButton(
                onPressed: controller.busy || controller.assets.isEmpty
                    ? null
                    : controller.clear,
                child: const Text('清空'),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 42,
                            color: colors.outline,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            controller.assets.isEmpty ? '还没有图片' : '没有匹配的图片',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            controller.assets.isEmpty
                                ? '添加图片后，即可预览与处理。'
                                : '试试其他文件名或筛选条件。',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final asset = visible[index];
                      final info = asset.info;
                      return Material(
                        color: controller.focused == asset
                            ? colors.primary.withValues(alpha: .06)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => controller.focus(asset),
                          onDoubleTap: info == null
                              ? null
                              : () => showImageDetails(context, asset),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 14, 12, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: asset.selected,
                                  onChanged: controller.busy || info == null
                                      ? null
                                      : (v) => controller.toggle(asset, v!),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: info == null
                                        ? Icon(
                                            asset.error == null
                                                ? Icons.hourglass_empty
                                                : Icons.broken_image_outlined,
                                            color: colors.outline,
                                          )
                                        : Image.memory(
                                            info.thumbnail,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asset.file.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      if (info != null)
                                        Text(
                                          '${info.format.label} · ${info.width}×${info.height} · ${formatBytes(info.bytes)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      if (asset.error != null)
                                        Text(
                                          asset.error!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: colors.error),
                                        ),
                                      const SizedBox(height: 7),
                                      StatusBadge(asset.status),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutputBar extends StatelessWidget {
  const _OutputBar({required this.controller, required this.wide});
  final WorkspaceController controller;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final destination = Row(
      children: [
        Icon(
          Icons.folder_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('输出位置', style: TextStyle(fontSize: 11)),
              Text(
                controller.outputLocation?.label ?? '请选择保存文件夹',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: controller.busy ? null : controller.chooseOutput,
          child: const Text('选择'),
        ),
      ],
    );
    final start = FilledButton.icon(
      onPressed: controller.busy || controller.selectedCount == 0
          ? null
          : controller.start,
      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
      label: Text('开始处理 · ${controller.selectedCount} 张'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: wide
            ? Row(
                children: [
                  Expanded(child: destination),
                  const SizedBox(width: 16),
                  start,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [destination, const SizedBox(height: 8), start],
              ),
      ),
    );
  }
}
