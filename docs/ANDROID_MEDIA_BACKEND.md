# Android 原生媒体后端

2026-09-14，Implemented / Experimental。编译通过不等于设备验收。

## 实际来源和构建

- 固定 Maven：`dev.ffmpegkit-maintained:ffmpeg-kit-full:8.1.7`，实际 AAR 30,962,496 B；SHA256 `c3cbc81d498175fd2aa69ee2dfe7dafbf519052a96283c2568fe5b3b16618456`，与 Maven Central 提供值一致，Gradle 再次校验。
- [上游源码](https://github.com/ffmpegkit-maintained/ffmpeg/tree/48d306bcb0e119582dfecd661e4c6777b8f44b4f)，FFmpeg source.sh 指向 arthenica/FFmpeg `n8.1.2`；原生字符串含 enable-version3、enable-shared、disable-static、libopenh264、libkvazaar、libaom、libvpx、libopus、libmp3lame 等，无 enable-gpl / enable-nonfree。
- LGPL-3.0。上游是年轻的社区分支，不能把 README 的维护/安全保证当作独立审计结论。AAR 内 source.txt 仍为旧 FFmpegKit 文案，发行前必须补齐对应源码和传递许可证。
- 实际包含 arm64-v8a / x86_64；所有 20 个 ELF 的 LOAD 段对齐为 0x4000。armeabi-v7a 继续保留图片功能，音视频明确不可用。
- FFmpegKitNext v9.0.0 为 source-only，没有可直接使用的 Maven 包；未伪造已自编译。

## C++ 冲突处理

第一次构建在 mergeReleaseNativeLibs 失败：libvips 和 FFmpeg 各带 libc++_shared.so。当前 Gradle 校验原始 FFmpeg AAR 后重新打包，仅排除其两个 C++ runtime，其他库及许可证保留；统一使用 libvips 从项目 NDK 28.2.13676358 构建带入的 runtime。不使用 pickFirst。

实际核对 FFmpeg 每个 ABI 所需的 58 个 C++ 动态符号，项目 runtime 均提供，缺失数为 0。APK 中 ARM64 runtime SHA256 `cd61762848882a16c8244c964a6f396c0caa0b440588a210ce9cc4ab0e6d9f0c`，与 Gradle strip 后产物相同。这仍不能替代真机动态加载和运行测试。

R8 随后发现 FFmpegKit 的真实 Java 依赖缺失。读取上游 build.gradle 后补入 `com.arthenica:smart-exception-java:0.2.1`（含 common 0.2.1，BSD-3-Clause），没有用 dontwarn 隐藏运行时缺类。

## 实现和限制

独立 Kotlin bridge 调用经 javap 核实的异步参数数组 API；EventChannel 传真实 Statistics 时间；Dart 取消等待 native session 完成回调后再清理暂存。屏蔽 FFmpegKit 日志直接打印，探测结果只在本机使用。启动时读取真实 encoders，缺失则不开放。

Android 15+ 使用 mediaProcessing 前台服务，旧版本使用 dataSync，含返回应用/取消通知。服务覆盖整批任务，避免后台项间重新启动服务受到限制；超时回调取消并停止，不从开机后台自动启动。依据 [Android 前台服务类型](https://developer.android.com/develop/background-work/services/fgs/service-types#media-processing)。未完成队列可保留 24 小时供用户恢复，重启后不自动执行，仍不能宣称后台永不中断。

Release 合并 Manifest 无 INTERNET 权限。SAF 媒体导入用流式拷贝，没有继承旧图片的 128 MiB 限制；正式多 GB 文件/空间不足/权限撤销设备测试尚未完成。

## 实测证据

`flutter build apk --release --no-pub` 已成功，开发快照 APK 148,777,144 B，SHA256 `3585323568e942b9b5238d7b3552af2663fe8056821dd9b9f43742153c4b2447`。apksigner verify 预期失败：此 APK 未签名，不能安装并冒充正式发行包。现有签名文件未读取、改动或重新生成。

该快照之后仍有代码迭代，最终交付必须重新构建。构建日志：artifacts/media-upgrade/android-native-build4.log。desktop_drop 的旧 KGP 警告仍存在，本次未通过重装环境解决警告。

### 2026-09-14 API 35 x86_64 模拟器实测

现有 Emulator/WHPX 可用；查询 SDK 仓库后安装官方 `system-images;android-35;default;x86_64` revision 2，创建独立 `ImageShift_API35_Test`。测试 APK 使用 Flutter Debug 测试身份，没有改动正式签名文件。它不是用户 ARM64 真机或正式 Release 验收。

`integration_test/native_media_test.dart` 的三组原生测试通过，日志 `artifacts/media-upgrade/android-native-device-test6.log`：PNG→JPG/PNG/WebP 透明/白底/真实尺寸/不覆盖；七种音频输出重新探测及完整解码；MP4/MKV/MOV/WebM、H.264/HEVC/AV1 重编码、尺寸和完整解码；运行中的 FFmpeg 取消。

真实发现并修复/限制：

- Android 不允许本次使用的 hard-link 发布方式，改为 bionic `renameat2(RENAME_NOREPLACE)`，API 30 前按 NDK 已核对的 ABI syscall；不支持时安全失败，不回退到覆盖。API 35 路径已实测，旧 Android syscall 路径尚未设备验收。
- Android libvips 没有 TIFF saver，设备错误为 `VipsForeignSave ... is not a known file format`。Android 不展示 TIFF 输出；输入仍独立探测/回退，不套用 Windows 的 TIFF 能力。
- FFmpegKit 把 JSON 和 decoder 日志汇入一个 session。按它自身 MediaInformation 的实现，仅 `AV_LOG_STDERR` 组成 ffprobe JSON，其余诊断分开返回，native worker 等待日志排空，不阻塞 Android main。
- Android AAR 虽列出 libvpx-vp9，其产物在完整解码中失败：`RGB not supported in profile 0`。此包的 Android VP9 编码被禁用，WebM 改为通过实测的 AV1；Windows VP9 不受影响。根因尚未确定，不把列出的 encoder 当作已验证能力。硬件编码均未开放。

另一个后台测试通过：服务开始后以 adb 按 Home，两个各 8 秒的本地 FFmpeg 命令顺序完成。`android-background-device-test.log` 记录两个完成标记；`android-background-service.txt` 记录运行中的 MediaProcessingService、startForegroundCount=1。结束后服务列表为空。仍未证明真机省电策略、长时间任务、通知按钮或 SAF 提供程序兼容性。
