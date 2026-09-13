# Phase A 依赖与格式能力审计

核查日期：2026-09-13。依据：pub.dev 当前 API/页面、下载后实际 package_config 定位的源码、pubspec.lock，以及本项目自动测试。下列“验证”均指本机 Windows 上 Flutter 测试，不代表 Android 真机或双平台 Release Build 已验收。

## 1. 选择与版本

| 依赖 | 实际版本 | 用途 | 平台与许可证 |
| --- | --- | --- | --- |
| Flutter / Dart | 3.47.4 Stable / 3.13.3 | 工程、启动页、Isolate、文件 IO、测试 | 使用既有开发环境 |
| image | 4.9.2，pub.dev 当前稳定版，发布于 2026-08-19 | 本地识别后的解码、像素变换、编码 | pub.dev 标记 Android/Windows；核心为 Dart 编解码；MIT，另有附属版权条款 |
| path | 1.9.1，pub.dev 当前稳定版 | 双平台路径拆分与拼接 | Dart 官方维护；Android/Windows；BSD-3-Clause |
| flutter_test | Flutter SDK 附带 | 单元、文件、原生图片解码和启动页测试 | 使用当前 SDK 版本 |
| flutter_lints | 6.0.0，实际 lock 版本 | 静态分析规则 | Flutter 模板生成的开发依赖 |

运行时直接依赖精确锁定 `image: 4.9.2`、`path: 1.9.1`；保留应用 pubspec.lock。没有导入网络图片服务、独立 Native 图片插件或额外状态管理方案。不能把 image 的开发依赖 http 等误认为应用联网能力。

主要间接依赖实际解析为 archive 4.2.0（MIT）、posix 6.5.2（MIT）、ffi 2.2.0（BSD-3-Clause）。archive 用于编解码中的压缩；源码中的 POSIX 调用属于归档解压到磁盘的权限操作，并带平台/异常检查，本项目不调用该功能。Windows 的真实编解码测试通过；Android 仍需后续设备与 Release 构建验收，不能仅凭平台标签宣称实测通过。

image 主许可证为 MIT，但 `LICENSE-other.md` 包含 JPEG/TIFF 的 Apache-2.0 来源声明、WebP 等 BSD 类版权条款。原文副本保存在 [third_party](third_party/)；这些不是 ImageShift 项目自身许可证，也不是完整发行许可证清单。Phase D 仍需按最终构建依赖完成发行声明及项目授权确认。

## 2. 输入与输出分开

| 格式 | 库源码/文档解码 | 库源码/文档编码 | Phase A 已验证输入 | Phase A 开放输出 |
| --- | --- | --- | --- | --- |
| JPG / JPEG | 有 | 有 | 是，生成 RGB JPEG，含 Orientation 6 用例 | 是，质量 1–100，默认 90、透明白底 |
| PNG | 有，含 APNG | 有，含 APNG | 是，RGB/RGBA/灰度 Alpha/16 位测试；动画拒绝 | 是，保留 Alpha |
| WebP | 有，含动画 | **仅无损 VP8L** | 是，无损 RGB/RGBA 自动样本；有损/动画变体未进行样本验收 | **是，仅静态无损**；Flutter 原生解码器交叉验证 |
| BMP | 有 | 有 | 是，生成 24 位 RGB BMP | 未开放，未来须增加编码集成与测试 |
| GIF | 有，含动画 | 有，含动画 | 是，单帧；双帧测试明确拒绝 | 未开放 |
| TIFF | 有，含多页 | 有；当前 encode 不写多页 | 是，经典单页 RGB；真实双页拒绝；循环目录拒绝 | 未开放 |
| TGA | 有多个分支，注释与实现范围不同 | 有未压缩真彩编码 | 受限：未压缩真彩、无色表、24/32 位，数据长度/可选页脚严格检查；不开放 RLE | 未开放 |
| ICO | 有 PNG/BMP 内嵌分支、多图像目录 | 有，当前使用内嵌 PNG | 受限：**单图像且内嵌 PNG**；其他变体拒绝，多图像拒绝 | 未开放 |

“是”不是对格式全部变体、位深、压缩、色彩管理或任意损坏文件的完整保证。格式候选由文件内容识别，再由解码器验证；TGA 无强制 magic，只采用严格受限结构，不依赖后缀。

Phase A 服务可以把上述启用输入转换为 JPG、PNG 或无损 WebP。测试重点是八类输入 → PNG，加 PNG → JPG / WebP、Alpha、尺寸、命名与错误处理；未做所有输入/输出笛卡尔积和真实设备验证。

## 3. 已读取并使用的真实 API

- `image/lib/src/formats/formats.dart`：`encodeJpg`、`encodePng`、`encodeWebP`；实际 WebP 函数没有质量参数。
- `webp_encoder.dart`：VP8L，先规范化为 8 位 RGB/RGBA；避免灰度 Alpha 丢失、16 位数值错误截断。
- `decoder.dart`：`startDecode`、`DecodeInfo.numFrames`、`decodeFrame`；头部信息优先、拒绝多帧、再解码。
- `ico/ico_info.dart`：通用 width/height 为零，尺寸在容器条目中。本项目自己验证目录、长度和内嵌 PNG 的真实尺寸，不信任名义宽高。
- `tiff_encoder.dart`：`singleFrame` 参数不代表实现了多页编码。测试通过生成真正的第二个 IFD 验证多页拒绝。
- `bake_orientation.dart`：在尺寸计算前处理 EXIF Orientation。仅方向规范化，不宣称完整保留或清理元数据。
- `copy_resize.dart`：本项目先计算最终目标尺寸，再调用 `copyResize`，避免把库的带边框 maintainAspect 语义误用为 fit。
- Dart SDK `dart:io File.createSync(exclusive: true)`：原子占用新名称，避免“先 exists 再覆盖写”竞争。

## 4. 平台边界

Phase A 接口接收可读的本地文件路径和已存在的可写输出目录；Android SAF/content URI 的导入与导出适配属于 Phase B，不应把 content URI 直接传给 File。每个转换在独立 Isolate 执行。当前没有完整批量调度器、进度回调或取消 API，调用方不得无界启动并发任务。

## 5. 可复核来源

- [image 当前包页面](https://pub.dev/packages/image)，[机器可读发布记录](https://pub.dev/api/packages/image)
- [image 上游源码](https://github.com/brendan-duncan/image)，本项目实际使用版本见 pubspec.lock
- [path 当前包页面](https://pub.dev/packages/path)，[发布记录](https://pub.dev/api/packages/path)
- 实际安装源码由 `.dart_tool/package_config.json` 定位；不把个人缓存路径写成项目必需配置。

## 6. Phase B 增量审计（2026-09-13）

以上 Phase A 记录保留为历史；当前能力以本节和 PHASE_B_REPORT 为准。

| 依赖 | 实际版本与许可 | 平台及用途 |
| --- | --- | --- |
| file_selector | 1.1.0，BSD-3-Clause | Flutter 官方插件，支持 Android/Windows；Windows 使用 openFiles/getDirectoryPath。Android 不支持 save location，不能冒充统一保存接口。 |
| desktop_drop | 0.8.4，Apache-2.0 | Windows DropTarget 原生拖拽，已从 Explorer 拖入验证；Android 插件能力未当作经过验证的导入途径。 |
| file_selector_windows | 0.9.3+6，BSD-3-Clause | 实际锁定版本，Windows 原生选择。 |
| file_selector_android | 0.5.2+11，BSD-3-Clause | 实际锁定的 federated 平台依赖；本应用 Android 使用自有官方 SAF 边界。 |

引入前读取发布记录、pubspec、许可证和实际缓存源码：[file_selector](https://pub.dev/packages/file_selector)、[发布 API](https://pub.dev/api/packages/file_selector)、[desktop_drop](https://pub.dev/packages/desktop_drop)、[发布 API](https://pub.dev/api/packages/desktop_drop)。新增运行时依赖许可证副本在 third_party；image 额外 codec 声明也登记到应用许可证页面。

Android 使用 ACTION_OPEN_DOCUMENT/ACTION_OPEN_DOCUMENT_TREE、ContentResolver 与 DocumentsContract，不将 content URI 当磁盘路径。复制在单线程 executor；发布创建新文档、重名编号并 SHA-256 回读校验，失败只尝试移除本次新文档。列表清空/移除清理当前会话对应副本，不触及输出文档。依据 [Android 官方 SAF 文档](https://developer.android.com/training/data-storage/shared/documents-files)。设备行为尚待实测。

image 新增 API 经源码和测试验证：copyCrop/copyRotate/copyFlip、ExifData、imageIfd/exifIfd/gpsIfd、decodeJpgExif、ICC/textData 和 encodePng 的 level。JPEG 解码会自行烘焙 Orientation，因此预先提取原始标签。清理仅对解码器暴露的标签，不保证未知 APP 段、私有 metadata 或完整色彩管理。

当前导入检查/预览/转换共用串行 CPU 槽，编解码仍在 Isolate。取消只停止未开始项，不伪造单图进度。

Windows 插件目录使用读取实际插件清单后创建的 junction，解决无开发者模式的符号链接权限限制。Android 因 C: 缓存与 D: 工程的 Kotlin incremental 路径错误，依据 [Kotlin 官方缓存文档](https://kotlinlang.org/docs/gradle-compilation-and-caches.html) 配置 `kotlin.incremental=false`，未修改依赖缓存。两个 Debug 构建成功；desktop_drop 旧 KGP 和 SDK XML 版本差异仍有警告，未来升级须再次验证。
