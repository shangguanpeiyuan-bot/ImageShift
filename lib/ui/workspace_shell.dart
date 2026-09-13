import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/workspace_controller.dart';
import '../platform/file_access.dart';
import 'pages/home_page.dart';
import 'pages/results_page.dart';
import 'pages/workbench_page.dart';
import 'pages/about_page.dart';
import 'pages/library_pages.dart';
import 'widgets/brand_mark.dart';
import 'widgets/preview_panel.dart';

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key, this.controller});
  final WorkspaceController? controller;
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  late final c = widget.controller ?? WorkspaceController();
  String version = '';
  bool dragging = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final l = c.library;
      if (l != null && !l.welcomed && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('欢迎使用 ImageShift'),
              content: const Text(
                '图片只在本机处理，永不覆盖原图。\n\n选择图片，设置参数，然后保存到你选择的位置。历史仅保存任务摘要，你可随时在设置中关闭。',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('开始使用'),
                ),
              ],
            ),
          ),
        );
        l.welcomed = true;
        await l.save();
      }
    });
    rootBundle.loadString('pubspec.yaml').then((value) {
      final actual = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(value)?.group(1);
      if (mounted) setState(() => version = actual ?? '版本信息不可用');
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  void _tool(int index) {
    c.navigate(1);
    if (index == 2) {
      c.edit((s) {
        s.keepFormat = true;
        s.quality = 80;
        s.pngCompression = 9;
      });
    }
    if (index == 3) c.edit((s) => s.resizeEnabled = true);
    if (index == 7) c.edit((s) => s.stripMetadata = true);
    if (index == 6 && c.focused?.info != null) {
      showImageDetails(context, c.focused!);
    }
    if (index >= 2 && index != 6 && MediaQuery.sizeOf(context).width < 1000) {
      showSettingsSheet(context, c);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      return LayoutBuilder(
        builder: (context, box) {
          final desktop =
              Theme.of(context).platform == TargetPlatform.windows &&
              box.maxWidth >= 800;
          final wideRail = box.maxWidth >= 1180;
          final body = switch (c.page) {
            0 => HomePage(controller: c, onTool: _tool),
            1 => WorkbenchPage(controller: c),
            2 => HomePage(controller: c, onTool: _tool, toolsOnly: true),
            3 => ResultsPage(controller: c),
            5 => HistoryPage(controller: c),
            6 => PreferencesPage(controller: c),
            7 => PresetsPage(controller: c),
            _ => AboutPage(version: version),
          };
          Widget content = Column(
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (!desktop) ...[
                      const BrandMark(size: 30),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        desktop
                            ? [
                                '首页',
                                '格式转换与批量处理',
                                '图片工具',
                                '任务与结果',
                                '关于',
                                '处理历史',
                                '设置',
                                '预设',
                              ][c.page]
                            : 'ImageShift',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.lock_outline, size: 16, color: colors.primary),
                    const SizedBox(width: 6),
                    if (box.maxWidth >= 360)
                      Text(
                        '离线可用',
                        style: TextStyle(fontSize: 12, color: colors.primary),
                      ),
                    if (!desktop)
                      IconButton(
                        tooltip: '任务与结果',
                        onPressed: () => c.navigate(3),
                        icon: const Icon(Icons.task_alt, size: 20),
                      ),
                    if (!desktop)
                      IconButton(
                        tooltip: '关于 ImageShift',
                        onPressed: () => c.navigate(4),
                        icon: const Icon(Icons.info_outline, size: 20),
                      ),
                  ],
                ),
              ),
              if (c.message != null)
                Container(
                  color: colors.errorContainer,
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 19,
                        color: colors.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.message!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭提示',
                        onPressed: c.clearMessage,
                        icon: const Icon(Icons.close, size: 19),
                      ),
                    ],
                  ),
                ),
              Expanded(child: body),
            ],
          );
          if (Platform.isWindows &&
              Theme.of(context).platform == TargetPlatform.windows) {
            content = DropTarget(
              enable: !c.busy && (ModalRoute.isCurrentOf(context) ?? true),
              onDragEntered: (_) => setState(() => dragging = true),
              onDragExited: (_) => setState(() => dragging = false),
              onDragDone: (details) {
                setState(() => dragging = false);
                c.importFiles(
                  details.files
                      .map((f) => ImportedFile(f.path, f.name))
                      .toList(),
                );
              },
              child: Stack(
                children: [
                  content,
                  if (dragging)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: .96,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.primary, width: 2),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 58,
                                  color: colors.primary,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '松开以添加图片',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
              ): () =>
                  _shortcut(c.pickImages),
              const SingleActivator(
                LogicalKeyboardKey.keyA,
                control: true,
              ): () =>
                  _shortcut(() => c.selectAll(true)),
              const SingleActivator(LogicalKeyboardKey.delete): () =>
                  _shortcut(c.removeSelected),
              const SingleActivator(
                LogicalKeyboardKey.enter,
                control: true,
              ): () =>
                  _shortcut(c.start),
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _shortcut(() => c.selectAll(false)),
            },
            child: Focus(
              autofocus: true,
              child: PopScope(
                canPop: c.page == 0,
                onPopInvokedWithResult: (didPop, result) {
                  if (!didPop) c.navigate(0);
                },
                child: Scaffold(
                  body: SafeArea(
                    child: Row(
                      children: [
                        if (desktop) _sidebar(context, wideRail),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                  bottomNavigationBar: desktop
                      ? null
                      : NavigationBar(
                          selectedIndex: switch (c.page) {
                            2 => 1,
                            5 => 2,
                            6 => 3,
                            _ => 0,
                          },
                          onDestinationSelected: (i) =>
                              c.navigate([0, 2, 5, 6][i]),
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home_rounded),
                              label: '首页',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.grid_view_outlined),
                              label: '工具',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.history),
                              label: '历史',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.settings_outlined),
                              label: '设置',
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  void _shortcut(VoidCallback action) {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (Theme.of(context).platform != TargetPlatform.windows ||
        !(ModalRoute.isCurrentOf(context) ?? false) ||
        focus?.widget is EditableText ||
        focus?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return;
    }
    action();
  }

  Widget _sidebar(BuildContext context, bool wide) {
    final colors = Theme.of(context).colorScheme;
    const navigation = [
      (Icons.home_outlined, '首页'),
      (Icons.swap_horiz, '转换 / 批量'),
      (Icons.grid_view_outlined, '图片工具'),
      (Icons.task_alt, '任务与结果'),
      (Icons.info_outline, '关于'),
      (Icons.history, '处理历史'),
      (Icons.settings_outlined, '设置'),
      (Icons.bookmarks_outlined, '预设'),
    ];
    return Container(
      width: wide ? 206 : 76,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 22 : 17,
              vertical: 26,
            ),
            child: Row(
              children: [
                const BrandMark(size: 40),
                if (wide) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ImageShift',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < navigation.length; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 12 : 10,
                      vertical: 4,
                    ),
                    child: Tooltip(
                      message: navigation[i].$2,
                      child: Material(
                        color: c.page == i
                            ? colors.primary.withValues(alpha: .1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => c.navigate(i),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  navigation[i].$1,
                                  size: 22,
                                  color: c.page == i
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                                if (wide) ...[
                                  const SizedBox(width: 14),
                                  Text(
                                    navigation[i].$2,
                                    style: TextStyle(
                                      fontWeight: c.page == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: c.page == i
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: wide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 7),
                          const Text('只在你的设备上'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ImageShift ${version.isEmpty ? '' : 'v$version'}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  )
                : const Icon(Icons.shield_outlined, size: 22),
          ),
        ],
      ),
    );
  }
}
