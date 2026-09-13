# ImageShift 工作约定

开始任何项目工作前，必须先读 `docs/PRODUCT_SPEC.md`，再读 `docs/ROADMAP.md` 及已有阶段报告。最新用户指令优先。规范中的产品目标不代表已经实现。

## 身份与现场

- 先读当前实际文件和 Git 状态，从中断处继续；不重复已完成步骤。
- 不得重新 clone、git init 或修改 origin。使用现有分支；禁止 force push。
- 不得擅自修改 Flutter project name `imageshift`、organization `io.github.shangguanpeiyuanbot`、Android Application ID `io.github.shangguanpeiyuanbot.imageshift`。
- 版本目标 `1.0.0+1`；显示名称 ImageShift。不要重复安装正常环境。
- 不得猜测路径、配置项、包名/包 ID、API 或依赖能力。不确定时先查实际文件、命令输出、当前官方依赖文档/源码与错误日志。
- 加依赖前核实稳定版本、维护、Android/Windows 支持、License，格式解码和编码分别核实并测试；锁定真实解析版本。

## 数据与实现

- 所有图片处理必须本地完成；禁止上传图片、在线转换、广告、账户和不必要网络依赖。
- 不得删除或覆盖原图；也不得覆盖已存在输出。所有变换输出新文件，冲突自动编号或跳过。
- P0 优先 P1/P2，次要功能不能破坏 Android / Windows Release Build。
- 所有 UI 同时考虑 Windows 和 Android；禁止以桌面侧栏直接照搬手机。
- 业务逻辑与 UI 分离，不允许把项目写进 `main.dart`。至少分离格式识别、解码、编码、转换服务、输出命名、任务模型、错误模型。
- 重 CPU 工作放后台 Isolate，限制大图资源和并发，不在 UI 线程长期编码。
- 动画/多页未验证保留时不得静默丢失；无确认机制则拒绝。
- 不支持的格式、质量参数或工具不能显示成有效功能；本地处理也不能伪称完整保留或清除所有元数据。

## 验证与安全

- 每阶段结束必须运行对应测试，至少执行该阶段要求的 pub get / analyze / test；失败时根据真实错误修复，禁止伪造成功。
- 测试应验证真实输出存在、可解码、格式及尺寸，不写仅镜像实现或返回 true 的无效测试。
- 每阶段报告实际完成内容、命令结果、Git 状态、限制和未解决问题。只有实际验收后才能更新为完成。
- 不得提交 `build/`、`.dart_tool/`、IDE/平台缓存、`local.properties`、本地 SDK 路径、token、key、keystore、`.jks`、密码、`.env` 或签名配置。
- 保留应用 `pubspec.lock`；提交前先检查 diff、ignore 和敏感内容。Phase A 不 commit/push/tag/release。
- 不随意删除用户文件，不做未经用户请求的环境重装和仓库重置。

## 当前执行边界

遵循四阶段路线。用户已明确授权继续 Phase C 和 D，沿用 A/B 成果，不重复初始化。先完成 C 的持久化、性能和平台打磨，再做 D 的测试、Release 构建、Installer、Git 提交/push 与 GitHub Release。按实际结果更新报告；签名和项目许可证未确定时先核实，不得冒用调试签名为正式签名。

用户已明确同意采用 MIT 许可证，并生成保存在仓库外的 ImageShift 专用 Android 发布密钥。沿用该密钥为后续同 Application ID 更新签名，不得擅自重新生成替换。密钥、密码和保护文件均不得进入 Git 或 Release 附件。

v1.0.0 已公开发布，发布证据及 Android 设备验收缺口见 PHASE_D_REPORT.md。本轮四阶段交付完成。后续工作先检查新请求和实际状态，不重复创建或覆盖 v1.0.0 标签/附件。

工程尚不存在时才可在仓库根执行：

```powershell
flutter create --platforms=android,windows --org io.github.shangguanpeiyuanbot --project-name imageshift .
```

工程生成后读取实际配置验证身份。不要因为文件缺失或不确定而未经检查重新生成整个项目。

## 当前媒体升级
最新要求见 docs/MEDIA_UPGRADE_REQUIREMENTS.md，架构见 docs/MEDIA_ARCHITECTURE.md。持续完成媒体升级，不在每阶段等待确认；现有 A-D 为 v1 历史。开发保持当前版本，原签名文件不修改、不移动、不重新生成。不得覆盖公开 v1.0.0。
