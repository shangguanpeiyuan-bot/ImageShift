# 媒体升级续接记录

2026-09-14；升级持续实施中，尚未完成全部产品要求，不能发布为完成版本。

已完成架构小提交 b835ae0。随后实现 libvips / FFmpeg、Windows 固定组件准备、Android native bridge/前台服务、混合媒体工作台、参数弹窗、局部缓存适配，当前改动需继续分组提交。

本轮真实检查：flutter pub get 成功（沿用原镜像与 archive 4.2.0）；flutter analyze 无问题；包含真实原生后端的 flutter test 161 项通过（current-tests3.log）。新增检查覆盖 Windows 原子编号、实际内存、中断恢复/迁移、KWM 合成样本。之后的 current-tests4.log 在 Windows 测试临时目录清理出现共享冲突 errno 32；已对测试拥有的临时目录增加有限重试，业务断言未放宽，后续重跑结果继续记录。

Android 旧未签名 Release 快照编译通过；新增 API 35 x86_64 模拟器的 3 组图片/音频/视频 native 测试与 1 组真实按 Home 后连续任务测试均通过，详见 ANDROID_MEDIA_BACKEND。修复 Android 原子保存和 ffprobe JSON/诊断混合；禁用实际失败的 Android TIFF saver / VP9 encoder，不套用 Windows 能力。缺少 ARM64 真机，不能标真机通过。最终必须重建 Release，现有 APK 是中间快照。

Windows Release 更新构建成功（windows-upgrade-build2.log，31.4 s）；原生 UI 从首页混合导入 100MP JPG/视频/音频，选择独立输出目录，三项完成，输出分别 2,758,221 / 7,508,719 / 9,565 B，FFmpeg 独立完整解码均退出 0。全部测试用自建样本与独立 LOCALAPPDATA，不修改用户的 v1 数据。

媒体历史/预设、24 小时队列恢复、动态可用内存预算、KWM legacy 分块 Isolate 解包、1GiB remux benchmark 已实现/实测，见对应文档。安装器改为 AppMutex/运行中关闭提示及 Restart Manager，独立 Validation 身份的首次安装、运行中拒绝（exit 1、DLL 不变）、同版本修复（exit 0）、卸载（exit 0）已执行。不是 v1→新正式版本的完整升级验收；尚未形成新发行包。

后续续接：已完成替换音轨 UI 与实际 Windows 合并/时长/压缩视频流 hash/源文件保留测试；只改音频时兼容视频流 copy。预设报告实际应用/跳过数，恢复丢失替换音轨的任务时拒绝，而非改回原音频。全量 current-tests5.log 165 项通过、current-analyze7.log 无问题；新增许可证独立测试 licenses-test2.log 1 项通过。最初许可证测试使用陈旧资源 manifest 失败，正常资源刷新后通过，不删断言。

Windows windows-upgrade-build3.log 成功（32.2 秒），Android android-upgrade-release5.log 成功（39.5 秒，142.2 MB）。这两个快照包含替换音轨但早于离线许可证页面更新，最终打包前仍需刷新资源。Android Release 的 integration_test Java 注册失败已查明是 --no-pub 跳过 release tooling 刷新，默认 pub 构建已成功，CI 已修正。

继续任务：ICC/更完整元数据与图片能力；Android ARM64/SAF/16KB设备验收；更多缓存变体；包大小/全部许可证与对应源码审计；CI 实际运行、最终双平台 Release / ZIP / Installer 回归。只有全面验收后才更新版本/提交最终发行结果，不覆盖 v1.0.0，不修改原签名文件。
