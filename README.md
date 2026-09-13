# ImageShift

面向 Windows 与 Android 的完全本地图片处理软件。当前完成 A/B/C 的核心、双平台界面、批量工具与持久化。D 阶段已生成 Windows Release、安装器与完整 ZIP；Android Release 已用专用密钥签名并验证，GitHub Release 附件已准备就绪。

## 当前功能

- Windows 文件多选、原生拖拽、输出目录选择；Android 系统文档选择与目录授权，content URI 经私有暂存适配，输出重新读取并校验。
- 文件列表、缩略图、真实格式/尺寸/大小、搜索、排序、格式/状态过滤、多选与移除。
- 输出 JPG、PNG、**静态无损 WebP**；JPG 质量和透明背景颜色、PNG 压缩级别。结果如实显示体积增加或减少。
- 百分比、宽高、长短边、预设尺寸、保持比例和禁止放大；自由/比例裁剪、90°/180°旋转、水平/垂直翻转。
- EXIF 方向规范化、已解析元数据查看、清理已知 EXIF/ICC/文本标签；不保证所有私有元数据类型或完整色彩管理。
- 前缀/后缀/序号重命名、组合处理流水线、安全编号输出，永不覆盖原图或已有文件。
- 串行后台队列、取消未开始项、单文件失败隔离、重试；结果统计与转换前后对比。
- 响应式 Windows/Android 布局、浅/深色主题随系统、原创应用图标；适应窗口、100% 完整像素、缩放平移预览。
- 浅色/深色/跟随系统即时切换与持久化、首次使用引导、记住参数和目录、应用内完成提示；本地历史摘要、内置/自定义预设保存/重命名/删除及复用。
- 历史只保存最近 200 次摘要，不保存图片与原图路径；自定义预设最多 100 个。Windows 基础快捷键可用，Android 目录授权失效后提示重新选择。

输入验证与输出验证分开：输入 JPG/JPEG、PNG、WebP、BMP、单帧 GIF、单页 TIFF、受限未压缩 TGA、单图像内嵌 PNG 的 ICO。当前不输出 BMP/GIF/TIFF/TGA/ICO，不处理动画或多页，不静默保留首帧。WebP 没有有损质量选项。各变体证据见[依赖与能力审计](docs/DEPENDENCY_AUDIT.md)。

## 使用与验证

选择图片 → 选择处理参数和输出文件夹 → 开始处理 → 查看结果与对比。所有处理在本机完成，不上传图片、不使用在线图片转换服务。Windows 原文件不写入；Android 仅将用户选择的文件复制到应用私有缓存，清空/移除列表时清理对应副本，已导出的文档保留。

当前 **131 项自动测试通过，flutter analyze 无问题**。Windows 原生选择/导出/拖拽与多窗口尺寸已实测，Release 安装、启动、主题重启恢复与卸载通过。Android Release 编译及专用密钥签名验证通过；**尚无 Android 真机/模拟器运行验收。**

单文件限制 128 MiB、2400 万像素、单边 16384 px；列表最多 500 项，Android 本次导入缓存最多 2 GiB。CPU 处理共享一个后台执行槽。取消允许正在执行的一张安全完成。4K、12/24 MP、TIFF 与 100 张批处理已测；8K 超出像素上限会拒绝。详细数据与内存测量边界见 [C 报告](docs/PHASE_C_REPORT.md)。Android 旧会话私有缓存超过 24 小时按目录边界回收。

## 从源码运行

本机验证环境为 Flutter 3.47.4 Stable / Dart 3.13.3。项目 imageshift，版本 1.0.0+1，Application ID io.github.shangguanpeiyuanbot.imageshift。

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Release 构建命令：

```powershell
flutter build apk --release
flutter build windows --release
```

若 Windows 的 pub get 在依赖解析后提示缺少符号链接权限，可运行 `./tool/prepare_windows_plugins.ps1` 后再次执行 pub get。脚本从实际生成的插件清单读取路径，创建本地目录联接，不安装工具或修改 Flutter SDK。清理 ephemeral 或切换依赖源后需重新检查插件链接。

Android 的 Kotlin 增量编译已关闭，以规避本机包缓存与工程跨盘的路径错误。desktop_drop 仍有未来 KGP 迁移警告，SDK XML 版本也有非阻塞警告，详见阶段报告。

Windows 运行需要完整构建目录中的 DLL/data，不能只复制 exe。本机产物在 artifacts/phase-d/dist：ImageShift-v1.0.0-Windows-Setup.exe（当前用户安装，含开始菜单、卸载、可选桌面快捷方式）及 ImageShift-v1.0.0-Windows-x64.zip。无需 Flutter SDK。安装器尚无 Authenticode 签名；当前不提供 GitHub 下载承诺。

Windows 打包脚本为 tool/package_windows.ps1，传入实际 Inno Setup ISCC.exe 与 Visual Studio 可再分发 CRT 目录，自动包含完整 Release 和 DLL。Android 构建不再回退到 debug signing；已使用用户确认的仓库外专用密钥签名，ImageShift-v1.0.0-Android.apk 的 APK v2/v3 签名与 16 KB 对齐检查通过。后续更新必须使用相同密钥，不得重新生成替换。GitHub 登录及源码 push 已成功。

## 结构

```text
lib/main.dart       启动与附属许可证登记
lib/app/            应用入口与主题接入
lib/core/imaging/   识别、解码、编码、尺寸、流水线
lib/core/files/     原子占名与安全输出
lib/core/models/    格式、参数、任务、结果、错误
lib/core/services/  Isolate 转换、检查、共享工作槽、队列
lib/application/   工作台状态与编辑参数
lib/platform/      文件访问边界
lib/ui/            设计系统、页面与独立控件
 test/             实际图片、队列、控制器、响应式及交互测试
 tool/             原创图标/测试素材生成、Windows 验证辅助
 docs/             规格、路线、验收报告、依赖声明
```

## 规范与许可证

- [产品规格](docs/PRODUCT_SPEC.md)、[四阶段路线](docs/ROADMAP.md)、[AGENTS](AGENTS.md)
- [Phase A 报告](docs/PHASE_A_REPORT.md)、[Phase B 报告](docs/PHASE_B_REPORT.md)、[Phase C 报告](docs/PHASE_C_REPORT.md)、[Phase D 报告](docs/PHASE_D_REPORT.md)
- 直接依赖：image 4.9.2（MIT 及附属条款）、path 1.9.1（BSD-3-Clause）、file_selector 1.1.0（BSD-3-Clause）、desktop_drop 0.8.4（Apache-2.0）、Flutter SDK。锁定解析版本见 pubspec.lock，原文见 [third_party](docs/third_party/)。
- **ImageShift 采用 [MIT 许可证](LICENSE)**；第三方组件保留各自许可证。
- 发布状态以 D 报告和实际 Git 结果为准；当前无已发布的 [GitHub Release](https://github.com/shangguanpeiyuan-bot/ImageShift)。
