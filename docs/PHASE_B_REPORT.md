# Phase B 验收报告

日期：2026-09-13。范围：完整工作流 UI、批量处理、常用工具。**本阶段完成，停在 B，不自动进入 C/D。** 以下区分自动测试、Windows 实测、构建和待验证内容。

## 1. 工程与交付

沿用 Phase A 的工程、核心和环境，没有 clone/init、origin 修改或环境重装。项目 imageshift，版本 1.0.0+1，Application ID io.github.shangguanpeiyuanbot.imageshift。APK 的 aapt 实际读取结果也一致：min SDK 24、target/compile SDK 36，包含 arm64-v8a、armeabi-v7a、x86_64。

实现内容：

- Material 3 设计系统、原创图像框/转换箭头图标及 Android/Windows 图标；首页、工作台、工具、任务结果、关于页。Windows 窄/双栏/三栏布局与 Android 底部导航、手机参数页；系统明暗主题。
- Windows 官方文件多选、目录选择、原生拖拽；Android 官方 SAF 导入/导出桥接，按用户授权访问。数据与 UI 分离，main.dart 只启动和登记许可证。
- 列表缩略图、实际格式/尺寸/大小、选择/全选/移除/清空、继续导入、搜索、排序、格式及状态过滤。
- JPG 质量及白/黑/自定义透明底色、PNG 压缩等级、静态无损 WebP；保持格式时不支持输出的输入格式明确失败。
- 指定宽高/百分比/固定边/长短边、尺寸预设、等比/禁止放大；自由及常见比例裁剪、旋转/翻转；流水线一次编码输出，未修改源像素文件。
- EXIF Orientation 校正、实际元数据字段查看、已知 EXIF/ICC/文本清理；前后缀/序号重命名预览与冲突自动编号。
- 后台 Isolate 串行工作槽、批量队列、防重复启动、单文件失败隔离、重试、取消未开始项；当前项允许安全完成。实际计数、耗时、字节增减，不伪造进度或压缩率。
- 几何效果预览、原图/输出对比、适应窗口、100% 完整像素、缩放/平移。
- Android 输出创建新文档并 SHA-256 回读校验；私有导入/暂存副本在列表移除/清空时按当前会话路径校验后清理，原图与已导出文档保留。

直接依赖：image 4.9.2、path 1.9.1、file_selector 1.1.0、desktop_drop 0.8.4 和 Flutter SDK。许可证及平台边界见 DEPENDENCY_AUDIT；未增加在线图片服务。

输入：JPG/PNG/WebP/BMP、静态 GIF、单页 TIFF、受限未压缩 TGA、单图像内嵌 PNG 的 ICO。输出：JPG、PNG、静态无损 WebP。保留 Phase A 的动画、多页、位深和变体限制，不将八类输入宣称为八类输出。

## 2. 自动测试与命令

| 命令 | 实际结果 |
| --- | --- |
| flutter pub get | Got dependencies，成功；插件 junction 准备后重新执行通过 |
| flutter analyze --no-pub | No issues found，退出 0 |
| flutter test --no-pub | **110 项全部通过**，退出 0 |
| flutter build windows --debug --no-pub | 成功，14.3 秒 |
| flutter build apk --debug --no-pub | 成功，113.2 秒 |
| dart run tool/verify_smoke_outputs.dart | 界面导出的四张文件全部通过真实格式/尺寸/白底校验 |

最终日志位于本机忽略目录 artifacts/phase-b：pub-get-final.log、analyze-final.log、test-final.log、windows-final-build.log、android-final-build.log。早期失败日志没有当作最终结果。

测试覆盖原有转换/格式/资源/异常回归，新增裁剪/旋转/翻转、处理顺序、背景/PNG 压缩、EXIF/元数据、重名、队列取消/失败/重试/互斥、控制器导入/保存错误/启动保护，以及响应式页面和真实图片弹窗交互。窗口规格 Windows 1600×1000、1100×800、800×650，Android 390×844、844×390、320×640，各主页检查明暗两种主题。新增预览测试验证 2400 px 图片的缩略图界限与完整像素，裁剪比例、重置和返回结果。图像测试检查真实文件、重新解码、格式和宽高，不是返回值模拟成功。

## 3. Windows 实际运行

实际启动 Debug 应用并检查：

1. 原生文件选择导入五项：四张有效图片、一项非法 PNG；有效项可继续，错误项留在列表但不参与转换。
2. 选择本机测试输出目录，四张成功输出；结果页显示真实字节增减，打开输出目录成功。
3. 从 Windows Explorer 拖入 mountain.png，应用进入工作台并显示 PNG、1280×800；不是仅调用 Dart 拖拽回调。
4. 最新构建在 800×650、1100×800、1600×1000 窗口运行检查，分别使用窄屏、双栏和三栏；窄且低窗口的操作区可纵向滚动。
5. 最新预览弹窗正确显示图片与真实信息，实际点击 100% 后切换完整像素。

本机截图：windows-final-home.png、windows-batch-import.png、windows-results.png、windows-native-drop.png、windows-narrow.png、windows-medium.png、windows-wide.png、windows-preview.png、windows-preview-100.png，位于 artifacts/phase-b。批量操作截图来自本阶段较早的成功构建；窗口/拖拽/完整预览来自最终构建。

界面生成的文件经单独重新解码：

| 文件 | 真实输出 | 字节 |
| --- | --- | --- |
| landscape.jpg | JPEG 1280×800 | 43090 |
| legacy.jpg | JPEG 640×400 | 14335 |
| mountain.jpg | JPEG 1280×800 | 42067 |
| transparent.jpg | JPEG 400×300，透明角落白色 | 9306 |

## 4. 构建产物

这些是 **Debug 验证产物，不是 Release 或安装器**：

- Android：build/app/outputs/flutter-apk/app-debug.apk，171263957 字节。SHA-256：75F47FB5A90C0EDEA04FBD38386EFFB8A93BC23169CAF1F65A128A939CE422F0。
- Windows：build/windows/x64/runner/Debug/imageshift.exe，1013760 字节。SHA-256：F51D3F2D6DF882213D03DD965733E32D781A95D35F464FB1202AAC966117FD48。必须保留同目录 DLL 与 data。
- Windows 原生 runner 未变化时会复用 exe；最新 Dart bundle 为 data/flutter_assets/kernel_blob.bin，51514320 字节，SHA-256：9D6AF0A4DEB3A416A6A29C657D58AA54D7A245BE6026005C0AA8A3DCA6372A95。本次成功构建与运行并非只检查旧 exe 时间。

## 5. 修复、限制与待验证

- Windows 无符号链接权限：根据实际插件清单建立 junction，pub get/构建通过，无需管理员、重装 SDK 或修改依赖源码。工具为 tool/prepare_windows_plugins.ps1。
- Android Kotlin 增量缓存跨 C:/D: 失败：android/gradle.properties 设置 kotlin.incremental=false 后通过。desktop_drop 仍有旧 KGP 的未来兼容警告；SDK XML 版本差异警告也未消失，目前不阻塞 Debug 构建。
- **Android 没有连接设备，emulator -list-avds 为空**。SAF、目录提供程序权限、返回与缓存清理已经实现并编译，但没有 Android 设备运行证据；不能把 Widget 测试称作真机通过。
- Release APK、Windows Release、正式签名、Installer、GitHub Release 均未执行。Android 仍保留模板 debug signing 供开发使用，不是发行签名。
- 限制 128 MiB/24 MP/16384 px、500 个列表项、Android 导入缓存 2 GiB；未进行大量文件和大图内存/耗时基准。崩溃后的旧会话缓存、失败导出的私有暂存与长期缓存回收需在 C 打磨，可通过系统应用缓存清理；不会把这些暂存计作成功导出。
- 完整色彩管理、全部私有元数据、动画/多页保存均未承诺。项目自身许可证待用户确定。
- 历史/预设/设置持久化、主题选择页、快捷键、文件夹和剪贴板等 C/P2 项没有伪装成已经可用的入口。

## 6. Git 与后续边界

当前 main，无提交；git status 显示 No commits yet on main...origin/main [gone]，工程和文档均为未跟踪文件。这个远端跟踪状态没有被擅自修复。未 commit/push/tag/release。

git check-ignore 已确认 build 产物、android/local.properties、artifacts 测试日志被忽略；pubspec.lock 保留。没有新增密钥或签名材料。

Phase B 已满足本阶段代码、测试和可用平台实测条件，Android 设备测试缺口已记录。具备进入 C 的基础，**本轮停止，不自动开始 C**；下一阶段应优先补 Android 设备验证和缓存生命周期，再做持久化与性能打磨。
