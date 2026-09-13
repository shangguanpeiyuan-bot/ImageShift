# Phase A 验收报告

日期：2026-09-13。范围：规范文件、基础工程、核心图片引擎、自动测试。当前停止在 Phase A，不进入 Phase B。

## 1. 初始状态与工程

实际检查 D:\ImageShift：只有 `.git`；`git status --short --branch` 显示 main 尚无提交。没有重复创建的业务代码可恢复，因此只执行一次用户指定的 Flutter create 命令，在根目录生成 Android 和 Windows 工程，没有 clone、git init 或修改 origin，也未重装环境。

实际生成配置已读取：

- pubspec.yaml：`name: imageshift`，`version: 1.0.0+1`。
- android/app/build.gradle.kts：namespace 与 applicationId 都是 `io.github.shangguanpeiyuanbot.imageshift`。
- windows/CMakeLists.txt：`project(imageshift)`，`BINARY_NAME imageshift`。
- 产品显示名称调整为 ImageShift；Application ID / project name 未变更。

PRODUCT_SPEC.md、AGENTS.md、ROADMAP.md 已创建；需求标记为产品目标，未冒充成已完成功能。

## 2. 已实现

- `lib/core/imaging/format_detector.dart`：内容签名/受限 TGA 结构检测，不依赖扩展名。
- `image_decoder.dart`：实际解码验证、尺寸检查、静态帧策略、ICO 容器检查、TIFF 页链检查、EXIF 方向规范化。
- `image_encoder.dart`：JPG、PNG、无损 WebP，JPG 默认质量 90，透明白底；保留 PNG Alpha，WebP 转为 8 位 RGB/RGBA。
- `image_resizer.dart`：指定宽高、等比 fit 边界框、默认禁止放大；非法及超限参数拒绝。
- `files/output_namer.dart`：photo / photo_1 / photo_2；独占新建，跳过文件/目录/链接占用，已存在文件及源文件不覆盖；四个并发 Isolate 的同名输出测试通过。
- `services/conversion_service.dart`：文件读写与 CPU 转换位于 Isolate，结构化成功/失败结果、中文主提示；本地文件处理，不包含网络请求。
- `models/`：格式、任务参数/状态、结果及错误类型独立。尚未实现完整队列和取消，只为 Phase B 提供基础模型。
- `app/`：最小启动页，明确标注核心引擎阶段；main.dart 仅启动，不包含业务代码。

已验证 PNG→JPG、JPG→PNG、BMP→PNG、PNG→无损 WebP；完整输入范围和限制见 [DEPENDENCY_AUDIT.md](DEPENDENCY_AUDIT.md)。

## 3. 实际验证

| 命令 | 实际结果 |
| --- | --- |
| 指定 flutter create 命令 | 退出码 0；根目录创建工程 |
| flutter pub get | 退出码 0；依赖解析完成；移除未使用的模板 Cupertino Icons |
| dart format lib test | 成功 |
| flutter analyze | 退出码 0；No issues found! |
| flutter test --reporter expanded | 退出码 0；62 项通过；All tests passed! |

最终复核运行使用 `flutter test --reporter expanded --concurrency=1`，62 项全部通过；完整本机记录见 [validation.log](../artifacts/phase-a/validation.log)。该日志包含本机信息，保存在被忽略的 artifacts 目录，不作为仓库源文件提交。

测试不是模拟转换：使用临时目录和程序生成的测试图片，检查真实输出文件、重新解码、格式、扩展名、宽高、实际字节数、源文件未改变。测试临时文件在结束后清理。

覆盖：八类输入识别及到 PNG；PNG→JPG/WebP；白底与半透明像素；PNG Alpha；WebP RGB 无损、Alpha、灰度 Alpha、16 位规范化及 Flutter 原生解码交叉检查；等比/非等比/放大开关/单像素；EXIF Orientation 6；有效质量范围及效果；重名与并发；损坏/CRC/非法/空输入/未知格式；读取不存在文件或目录；输出路径不存在或被文件占用；字节/像素/输出尺寸限制；GIF/APNG/多页 TIFF/多图像 ICO 拒绝；ICO 嵌入尺寸限制、TIFF 循环目录拒绝。

测试过程中发现并修复 ICO 通用尺寸字段为零的问题；多页测试改为真实双 IFD TIFF，避免依赖单页编码器制造错误测试素材。最终结果以上表的通过运行为准。

## 4. 当前限制与尚未做的工作

- 无 Phase A 范围内已知未修复的测试/分析失败；这不是完整产品已发布声明。
- 输入文件上限 128 MiB，解码和输出上限 2400 万像素、单边 16384；可配置限制是防护阈值，不保证任意设备不会 OOM。未做 4K/8K/大型 TIFF/大批次性能实测，默认 8K 超过像素阈值会拒绝。
- TGA 只开放受限无色表未压缩真彩；ICO 只开放单图像内嵌 PNG；不保存动画/多页。输出仅 JPG/PNG/无损 WebP，不提供 WebP 有损/质量滑块。
- 常规文件异常映射及无效路径已测；真实磁盘耗尽、权限 ACL、进程崩溃/断电未专项注入。写入失败尝试删除本次新输出；崩溃或清理失败可能遗留未完成文件，不能声称事务/断电安全。
- 元数据方向基础处理已实现；未承诺完整 EXIF/ICC 保留、色彩管理或彻底元数据清理。
- 尚无平台文件选择/SAF 保存、拖拽、完整 UI、批量队列/取消、裁剪、旋转/翻转工具、历史/预设/设置。这些属于后续阶段。
- Android 真机和 Release Build、Windows Release Build/启动验收、Installer、push、GitHub Release 均未执行，不把工程生成或测试通过等同于这些验收。
- Android 当前仍是 Flutter 模板调试密钥的 release signingConfig；正式签名与项目自身 License 待 Phase D 明确。品牌图标仍为模板资源，留待 Phase B。

## 5. Git 与阶段结论

当前 main 无提交，所有新工程/文档/源码均为未跟踪；未 git add/commit/push。此前空仓库造成的 `origin/main [gone]` 提示仍在，不为消除提示修改 origin 或远端状态。

实际 `git check-ignore` 确认 build/、android/local.properties、.dart_tool/、.idea/、签名 .jks、.env、Windows ephemeral 和 artifacts 日志等被忽略。71 个非忽略的新文件中未发现上述禁止产物；常见凭据签名扫描未命中。pubspec.lock 为需要保留的应用锁文件。当前没有发行产物。

结论：Phase A 验收通过，具备进入 Phase B 的基础条件。按用户要求在此停止，Phase B/C/D 状态保持未开始。
