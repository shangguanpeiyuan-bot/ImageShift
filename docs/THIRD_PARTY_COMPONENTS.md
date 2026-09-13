# 第三方媒体组件（开发审计）

2026-09-14。状态描述：Implemented=已接入代码；Tested=仅所列测试通过；Experimental=评估中；Unsupported=未开放。新原生组件尚未作为公开 Release 分发。

| Component / Upstream URL | Version / Commit | Purpose | License / Distribution | Linkage / Build Flags | Windows x64 | Android arm64 | Modified Code / Notices / Update Policy |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [FFmpeg](https://ffmpeg.org/download.html) / [BtbN](https://github.com/BtbN/FFmpeg-Builds) | n9.0.1-29-gad500d59cb-20260913 / ad500d59cb6e0126add4fcb95afb4e2557c4292c | probe、流式音视频转换 | LGPL-3.0-or-later，官方页面链接的构建维护方，固定日期附件 | CLI + shared；enable-version3；无 enable-gpl/nonfree；完整 configure/逐文件 SHA256 见 tool/native/ffmpeg-windows.json | Tested：4 视频容器及 7 音频输出 smoke | Unsupported：此包仅 Windows | 未修改上游代码；LGPL 原文已保存；锁定哈希，升级后重跑全部 smoke，不跟随 latest 自动变化 |
| [libvips_ffi](https://github.com/fluttercandies/libvips_ffi) | 0.1.2+8.16.0；上游 HEAD e9dbdd3372f209208a38c16addd3402b427a2e42（2025-12-18） | Flutter Android 原生包 | 发布 archive LICENSE 为 Apache-2.0 + libvips 自身许可；README 的 LGPL 简称不能替代实际许可证 | FFI / shared，实际 Gradle/CMake 已读 | 需要独立 Windows 包 | Experimental：3 ABI；ARM64 所有随包 ELF LOAD 对齐 0x4000，未设备运行 | 无上游代码修改；版本较早，禁止把发布包号当成当前 libvips 最新版 |
| libvips_ffi_windows | 0.1.0+8.17.3 | Windows 原生 DLL | 包自身 Apache-2.0；38 DLL 的传递许可证尚须逐项补齐，不能仅带一个 LGPL 声明就发行 | FFI / shared；23390720 B DLL | Tested：8K 单样本、PNG/JPG/WebP/TIFF 与 Alpha/尺寸 | Unsupported | pub archive SHA256 5eaaa04f6ccff38c52fbf7ee11ff26fce21cf61bfe534a44b517c65780b6934b |
| libvips_ffi_api / core | 0.1.3+8.16.0 / 0.1.0+8.16.0 | Dart pipeline 与 FFI binding | 发布包许可证随上游；锁定 pubspec.lock | Dart / FFI | Tested：实际文件 API | Experimental | 未复制上游源码到 lib；Windows 需多 DLL 符号查询，不能只 initVips 就假设 API 层已初始化 |
| [FFmpegKitNext](https://github.com/arthenica/ffmpeg-kit-next) | v9.0.0（2026-08-23），基于 FFmpeg 9.0.1 | Android 路线评估 | 默认 LGPL-3.0，GPL 变体另计 | 最新 release 明确 source-only；不提供 Maven/pub 即装包 | 不用其 Windows wrapper | Experimental，尚未集成 | 需自建或可核验替代；当前机器 WSL 未安装，不能声称已构建 |

FFmpeg bundle archive SHA256：536d71dba608d9c61167f0fae8e286f6784d037f9d6a8748d950e549470db39c，已与 GitHub asset digest 对照。Archive 实际 76400244 B。来源是固定 `autobuild-2026-09-13-14-50`，不是浮动 latest。官方稳定 tarball 是 9.0.1；这个二进制为其维护分支之后 29 个提交，明确区别。

当前 smoke 使用本机程序生成的 color/sine，无用户媒体上传。FFmpeg 编码器清单显示 libopenh264、libkvazaar、AV1、VP9 等，但只把实际通过的编码配置作为 Tested；硬件 encoder 名字存在不代表硬件可用。

后续核查：插件全部 38 个 Windows DLL 与官方 build-win64-mxe v8.17.3 web 包哈希一致；逐文件清单见 tool/native/vips-windows.json，版本表见 third_party/vips-windows-versions.json。官方构建提交 3c9ae8ebc1f0d72eba55b03af26c60177031d711 的依赖表确认 imagequant 为 BSD-2-Clause 的 2.4.1 分支，不能套用当前 imagequant 主分支 GPL 许可。libvips 确实链接该 DLL，已用 PE imports 核实。

Android FFmpeg 的固定 AAR、上游源码、C++ runtime 统一、实际缺失的 smart-exception 依赖与构建证据见 ANDROID_MEDIA_BACKEND.md。发行前仍需补齐全部传递组件版权/许可文本、对应源码分发说明、最终包清单和设备回归；整个二进制组合不能只标 MIT。

已从校验过 SHA-256 的 Android AAR `res/raw/license*.txt` 原样提取 33 个许可文本，存入 `third_party/android-ffmpegkit-*`；应用离线开源许可证页动态登记全部随包 txt/md notices。未复制 AAR 中过时的 source.txt 对上游邮箱的源码提供承诺；该承诺不能由 ImageShift 冒用，对应源码闭环仍是公开二进制发行前的未解决项。Windows 官方构建表将组合包用于 LGPLv3 条款，不能把 libvips 自身 LGPL2.1 文本当作整个组合的唯一许可。
