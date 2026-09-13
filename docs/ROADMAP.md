# ImageShift 四阶段路线

产品目标见 [PRODUCT_SPEC.md](PRODUCT_SPEC.md)。状态只按已验证结果更新；用户已授权继续 C/D。历史报告保留当时的边界，当前状态以本文件为准。

## Phase A — 基础工程 + 核心图片引擎 + 测试

- **目标**：建立正确身份的 Android/Windows Flutter 工程，把真实识别、编解码、尺寸和安全输出底层做稳。
- **交付物**：PRODUCT_SPEC、AGENTS、ROADMAP；独立引擎模块/任务及错误模型；依赖能力审计；自动测试；Phase A 真实报告及当前 README。
- **验收条件**：project name/Application ID/版本正确；PNG→JPG、JPG→PNG、BMP→PNG 可重新解码；确认 WebP 编码后实现并测试；透明转 JPG 白底、宽高/等比/禁止放大、自动编号、损坏/非法/读写失败处理、源文件保护。
- **测试条件**：生成测试图片；实际输出存在、格式/尺寸正确；运行 flutter pub get、flutter analyze、flutter test 并修复 Phase A 问题。输入/输出能力单独记录，不将依赖支持视为平台设备实测。
- **当前状态**：已完成（2026-09-13）。工程身份已核实，pub get 成功，analyze 无问题，阶段 A 的 62 项测试通过。历史证据见 [PHASE_A_REPORT.md](PHASE_A_REPORT.md)；随后按用户授权实施 B。

## Phase B — 完整 UI + 批量处理 + 常用图片工具

- **目标**：把引擎接入 Windows 桌面和 Android 手机交互，完成 P0 工作流与常用工具。
- **交付物**：设计系统、原创图标、双平台布局、选择/拖拽/保存、缩略图与预览、输出参数、任务队列与取消、失败隔离、结果与对比、压缩/裁剪/旋转/翻转/批量重命名及流水线、元数据可验证工具。
- **验收条件**：UI 功能均有真实后端；无覆盖和静默动画损失；批处理计数真实、单文件失败不中断整批；触摸/鼠标/返回行为合理；不引入未验证格式参数。
- **测试条件**：核心回归、队列取消/失败隔离/重名并发、工具与流水线测试、响应式 Widget 测试；实际启动 Windows 检查多窗口尺寸，Android 可用设备上验证文件访问及交互；记录未做的设备测试。
- **当前状态**：已完成并停止（2026-09-13）。pub get、analyze、110 项测试通过；Android/Windows Debug 构建成功，Windows 原生导入/拖拽/导出/预览及多窗口实测完成。没有 Android 设备，设备验收缺口及警告如实列于 [PHASE_B_REPORT.md](PHASE_B_REPORT.md)。不自动进入 C/D。

## Phase C — 历史 / 预设 / 设置 / 性能 / 双平台打磨

- **目标**：完善长期使用体验、持久化、主题及大图性能，稳定后再考虑 P2。
- **交付物**：本地历史、自定义/内置预设、设置/首次启动/主题持久化、元数据限制说明、无障碍和状态打磨、性能报告；可靠时加入文件夹导入、剪贴板、快捷键、通知及高级预览。
- **验收条件**：重启后持久化正确，历史不存图片；浅/深/系统主题覆盖双平台；目录权限失效可恢复；有实际资源/并发限制和清理策略；P2 不破坏 P0 与双平台构建。
- **测试条件**：持久化/迁移/权限失效测试、主题/布局回归；4K/8K/手机高像素/TIFF/大批次性能实测，记录硬件、数据量、耗时、内存和限制；阶段性构建验证。
- **当前状态**：已完成当前可用平台验收（2026-09-13）。本地历史/预设/设置/主题、缓存和权限恢复已实现；全量 131 项测试通过，4K/高像素/TIFF/100 张批量性能实测完成，8K 按 24 MP 上限明确拒绝。Android 真机仍未验证。见 [PHASE_C_REPORT.md](PHASE_C_REPORT.md)。

## Phase D — 全面测试 + Release Build + Installer + GitHub Release

- **目标**：完成公开发行所需验收与实际交付，禁止将构建计划写成成品。
- **交付物**：完整测试报告、Android Release APK、完整 Windows Release 应用、Windows Installer、真实 README/许可证/依赖声明、Git 提交与 push、v1.0.0 GitHub Release 及安装附件。
- **验收条件**：APK/Windows 构建真实成功并核实产物，Android 签名策略明确；Installer 有开始菜单/卸载/可选快捷方式且不需要 Flutter SDK；Release 附件为真实构建；无敏感内容提交，无 force push。
- **测试条件**：完整 analyze/test、双平台 Release Build、实际 UI/安装/启动/卸载验收、断网本地处理、数据安全和大图回归；Git 安全检查与发布附件校验。人工授权/签名/UAC 问题在实际步骤明确报告。
- **当前状态**：进行中。Windows Release、完整 ZIP、Installer 已真实生成，安装/启动/主题重启/卸载已验证；Android Release 编译成功但未签名。正式签名、项目许可证与 GitHub 写入登录仍待完成，不能称作已公开发行。见 [PHASE_D_REPORT.md](PHASE_D_REPORT.md)。
