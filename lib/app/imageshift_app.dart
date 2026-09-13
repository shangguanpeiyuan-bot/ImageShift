import 'package:flutter/material.dart';

import '../application/workspace_controller.dart';
import '../application/local_library.dart';
import '../ui/theme.dart';
import '../ui/workspace_shell.dart';

class ImageShiftApp extends StatelessWidget {
  const ImageShiftApp({
    super.key,
    this.controller,
    this.themeMode = ThemeMode.system,
    this.library,
  });
  final WorkspaceController? controller;
  final ThemeMode themeMode;
  final LocalLibrary? library;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library ?? const AlwaysStoppedAnimation(0),
    builder: (context, _) => MaterialApp(
      title: 'ImageShift',
      debugShowCheckedModeBanner: false,
      theme: ShiftTheme.build(Brightness.light),
      darkTheme: ShiftTheme.build(Brightness.dark),
      themeMode: library?.theme ?? themeMode,
      home: WorkspaceShell(controller: controller),
    ),
  );
}
