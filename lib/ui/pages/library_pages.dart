import 'package:flutter/material.dart';

import '../../application/local_library.dart';
import '../../application/workspace_controller.dart';
import '../../application/editor_serialization.dart';
import '../../application/editor_settings.dart';
import '../theme.dart';

Future<String?> _nameDialog(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final field = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        maxLength: 60,
        autofocus: true,
        decoration: const InputDecoration(labelText: '预设名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (field.text.trim().isNotEmpty) {
              Navigator.pop(context, field.text.trim());
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  // Disposal after the exit animation avoids a TextField using a dead controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  field.dispose();
  return value;
}

class PresetsPage extends StatelessWidget {
  const PresetsPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final l = controller.library;
    if (l == null) return const Center(child: Text('本地预设不可用'));
    return ListenableBuilder(
      listenable: l,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('把常用参数，留到下一次', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('预设只保存处理参数。应用后可继续调整，不会自动处理图片。'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: controller.busy || l.presets.length >= 100
                  ? null
                  : () async {
                      final name = await _nameDialog(context, '保存当前参数');
                      if (name != null) {
                        await l.addPreset(name, controller.settings);
                      }
                    },
              icon: const Icon(Icons.add),
              label: Text(
                l.presets.length >= 100 ? '已达 100 个预设上限' : '保存当前参数为预设',
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final p in [...LocalLibrary.builtIns, ...l.presets])
            Card(
              child: ListTile(
                leading: Icon(p.builtIn ? Icons.tune : Icons.bookmark_outline),
                title: Text(p.name),
                subtitle: Text(
                  '${p.builtIn ? '内置' : '自定义'} · ${p.parameters['format'] == 'webp'
                      ? '无损 WebP'
                      : p.parameters['format'] == 'png'
                      ? 'PNG · 压缩级别 ${p.parameters['pngCompression']}'
                      : 'JPG · 质量 ${p.parameters['quality']}'}',
                ),
                onTap: controller.busy
                    ? null
                    : () => controller.applyParameters(p.parameters),
                trailing: p.builtIn
                    ? const Icon(Icons.chevron_right)
                    : PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'delete') {
                            l.presets.remove(p);
                            await l.save();
                          }
                          if (action == 'rename' && context.mounted) {
                            final name = await _nameDialog(
                              context,
                              '重命名预设',
                              initial: p.name,
                            );
                            if (name != null) {
                              p.name = name;
                              await l.save();
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('重命名')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final l = controller.library;
    if (l == null) return const Center(child: Text('暂无历史记录'));
    return ListenableBuilder(
      listenable: l,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('处理历史', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('仅保留最近 200 次任务摘要和参数，不保存图片或原文件名。'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('清空历史'),
              onPressed: l.history.isEmpty
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('清空历史记录？'),
                          content: const Text('只删除任务摘要，已导出的图片保留。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('清空'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        l.history.clear();
                        await l.save();
                      }
                    },
            ),
          ),
          if (l.history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48),
                  SizedBox(height: 14),
                  Text('完成一次处理后，在这里继续你的工作。'),
                ],
              ),
            ),
          for (final h in l.history)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${h.time.toLocal().toString().split('.').first} · ${h.total} 张',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${h.succeeded} 成功 · ${h.failed} 失败 · ${h.cancelled} 取消',
                    ),
                    Text(
                      '${formatBytes(h.inputBytes)} → ${formatBytes(h.outputBytes)}（成功项）',
                    ),
                    if (h.output != null)
                      Text(
                        '输出：${h.output!.label}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: controller.busy
                              ? null
                              : () => controller.applyParameters(h.parameters),
                          child: const Text('复用参数'),
                        ),
                        if (h.output != null)
                          TextButton(
                            onPressed: () async {
                              try {
                                await controller.files.validateOutput(
                                  h.output!,
                                );
                                await controller.files.openOutput(h.output!);
                              } catch (_) {
                                controller.message = '历史目录已不可用，请重新选择输出目录。';
                                controller.refresh();
                              }
                            },
                            child: const Text('打开输出位置'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final l = controller.library;
    if (l == null) return const Center(child: Text('设置不可用'));
    return ListenableBuilder(
      listenable: l,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('按你的习惯工作', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          DropdownButtonFormField<ThemeMode>(
            initialValue: l.theme,
            decoration: const InputDecoration(labelText: '外观'),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
            ],
            onChanged: (value) async {
              l.theme = value!;
              await l.save();
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('记住处理参数'),
            subtitle: const Text('下次启动恢复格式、质量、尺寸、工具与命名参数'),
            value: l.rememberParameters,
            onChanged: (v) async {
              l.rememberParameters = v;
              if (!v) {
                l.defaults = EditorSettings();
              } else {
                l.defaults = editorFromJson(controller.settings.toJson());
              }
              await l.save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('保存任务历史'),
            subtitle: const Text('仅保存摘要；关闭不删除已有历史'),
            value: l.recordHistory,
            onChanged: (v) async {
              l.recordHistory = v;
              await l.save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('完成后打开输出目录'),
            value: l.autoOpen,
            onChanged: (v) async {
              l.autoOpen = v;
              await l.save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('应用内完成提示'),
            subtitle: const Text('处理结束时在应用内显示结果摘要'),
            value: l.completionNotice,
            onChanged: (v) async {
              l.completionNotice = v;
              await l.save();
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('默认输出位置'),
            subtitle: Text(controller.outputLocation?.label ?? '每次首次处理前选择'),
            trailing: const Icon(Icons.folder_open),
            onTap: controller.busy ? null : controller.chooseOutput,
          ),
          TextButton(
            onPressed: controller.busy
                ? null
                : () async {
                    controller.outputLocation = null;
                    l.output = null;
                    await l.save();
                    controller.refresh();
                  },
            child: const Text('忘记默认输出位置'),
          ),
          const Divider(),
          const Text(
            '输出安全：永不覆盖原图或已有文件，重名自动编号。无损 WebP 没有有损质量参数。元数据清理仅针对可解析字段，不保证未知私有标签。',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => controller.navigate(7),
            icon: const Icon(Icons.bookmarks_outlined),
            label: const Text('管理预设'),
          ),
          if (l.storageError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l.storageError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
