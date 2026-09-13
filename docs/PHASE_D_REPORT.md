# Phase D 实际进度与交付

日期：2026-09-13。**v1.0.0 发行交付已完成并公开发布。** 构建、Windows 安装验收、源码 push、MIT 授权、Android 正式签名与附件校验均完成。下文明确保留尚未执行的设备验收，不把公开发布等同于所有环境测试通过。

## 已执行

- flutter pub get 成功，flutter analyze 无问题，flutter test **131 项全部通过**。最终日志在 artifacts/phase-d，先前测试/lint 失败已修复，不把失败日志当作最终结果。
- flutter build windows --release 成功。完整 runner、flutter_windows.dll、插件 DLL、data/app.so、字体/资源/开源声明均在构建目录。
- flutter build apk --release 成功。已取消模板 debug signing 回退；构建后的 unsigned APK 已使用仓库外专用 RSA 3072 位密钥另行签名。最终附件 apksigner verify 返回 Verifies，v2/v3 签名通过，zipalign 16 KB 检查通过。没有以调试签名冒充正式签名。
- Android Release 合并权限检查仅含应用自身的非导出 receiver 权限，**没有 INTERNET 或全盘存储权限**。没有断开用户网络或把静态权限检查称作 Android 真机断网测试。
- 从本机实际已安装 Visual Studio 的可再分发 CRT 目录带入 DLL；安装后检查进程模块，VCRUNTIME140、VCRUNTIME140_1、MSVCP140、flutter_windows 均从应用安装目录加载，未依赖 Flutter SDK。
- 使用实际 winget 查询得到的 Inno Setup 6.7.3（JRSoftware.InnoSetup），当前用户安装成功。构建脚本 tool/imageshift.iss 和 tool/package_windows.ps1 不含开发机 SDK 路径。
- Installer 安装退出 0，程序实际启动。包含开始菜单应用/卸载入口及可选桌面快捷方式。深色主题写入本地 JSON 后关闭重启仍恢复，welcome 状态正确。
- 卸载退出 0，程序 exe 与开始菜单快捷方式移除，用户设置保留。最终安装器再次安装退出 0，桌面快捷方式实际创建，最终 Release 启动成功；本机保留可运行安装。

## 本机 Windows 交付物

路径为 artifacts/phase-d/dist（Git 忽略，不把大二进制提交源码仓库）：

| 文件 | 字节 | SHA-256 |
| --- | --- | --- |
| ImageShift-v1.0.0-Windows-Setup.exe | 11521008 | 369C81E720C29C2A929522A817A46E82595EFC9082BAA74F592F9B21781B0A02 |
| ImageShift-v1.0.0-Windows-x64.zip | 13634240 | 2D7EEEC9D9B9275FE9AD7E779D3E44CCD610A4C3E80227408376600508B86E91 |

安装范围为当前用户，默认使用系统 LOCALAPPDATA/Programs/ImageShift。ZIP 必须整体解压，不可只取 exe。安装器没有 Windows Authenticode 签名，不伪称已认证发布者。原生架构为 x64；未测试 ARM64 模拟运行和全新 Windows 机器。

Android 最终附件 ImageShift-v1.0.0-Android.apk 为 55562302 字节，SHA-256 为 F4AD8458E31198353FC658E7DA39E7DCC3CD5508A26AF423AD2BC0661869D740。证书 SHA-256 为 10dd62ac70bd268f23cb3ddf1b7f699501e09752ea6adc0e45d2eb2d55dd72ba。Application ID、版本 1.0.0 / code 1、min SDK 24 / target 36 与三种 ABI 已从最终 APK 验证。原始 unsigned 文件和对齐暂存不上传。

## 日志与截图

artifacts/phase-d：pub-get.log、analyze.log、test.log、windows-release.log、android-release.log、installer-build.log、install.log、uninstall.log、install-final.log。截图：installed-welcome.png、installed-settings.png、restart-dark.png、installed-final.png。文件、命令和原生 UI 都实际检查过。

源码、文档及测试已整理为本地提交范围；检查排除了 build、artifacts、local.properties、私钥/keystore 与本机 SDK 配置。上游许可证保留原文空白，Git 属性仅免除这些许可证的空白检查。Git 提交哈希以实际 git log 为准；没有将构建产物放入源码提交。

## 已知限制与密钥维护

1. 用户已明确选择 **MIT**；根 LICENSE、应用许可页、Android assets、Windows 安装目录和 ZIP 均包含许可。安装后 LICENSE 哈希与源码相同。
2. 用户已明确授权生成专用发布密钥。密钥在当前用户 LOCALAPPDATA/ImageShiftSigning，目录 ACL 仅当前用户与 SYSTEM，密码用当前 Windows 用户 DPAPI 保护；没有密码/私钥进入 Git、日志或附件。后续更新必须沿用此密钥。尚未创建离机备份，迁移或重装 Windows 前须安全备份密钥和可恢复的密码。
3. GitHub 浏览器授权后，Credential Manager 登录进程退出 0，账号列表确认 shangguanpeiyuan-bot。随后 push 实际成功，main 跟踪 origin/main。此前缺凭据的错误属于授权前尝试，不代表本次授权失败。正式 v1.0.0 标签指向 478c2d2a4ab447a6fdf98d237ce843c2175fcf6a，包含 MIT 应用与发行代码；后续仅补充发行记录文档。不修改 origin，不 force push。
4. **Android 无真机或 AVD**，SAF、真实触摸/系统返回/缓存回收和实际手机内存仍未验收。此缺口不等于编译失败，亦不能称为设备测试通过。
5. desktop_drop 旧 KGP 与 SDK XML 版本差异仍有非阻塞警告；未来 Flutter 升级须复查。Windows CRT 应用本地部署由发行者跟进安全更新。
6. 8K 超过 24 MP 上限会明确拒绝。性能与格式变体限制见 C/A/B 报告；P2 文件夹/剪贴板/系统通知未实现，不作为 v1 已有能力。

## 可复核官方资料

- [Inno Setup 非管理员模式](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm)、[安装参数](https://jrsoftware.org/ishelp/topic_setupcmdline.htm)、[许可证](https://jrsoftware.org/files/is/license.txt)
- [Microsoft C++ 部署示例](https://learn.microsoft.com/en-us/cpp/windows/deployment-examples?view=msvc-170)
- [Android 签名说明](https://developer.android.com/studio/publish/app-signing)

## GitHub Release 实际结果

- 地址：[ImageShift v1.0.0](https://github.com/shangguanpeiyuan-bot/ImageShift/releases/tag/v1.0.0)，Release ID 387935714，draft=false。
- 发布时间：2026-09-13 15:05:37 UTC（香港时间 23:05:37）。上传先在草稿完成，逐个验证 GitHub 返回的 size 与 SHA-256 digest 一致后才公开。
- 附件：专用签名 APK、Windows Setup、完整 Windows ZIP、SHA256SUMS.txt，全部上传成功。checksum 文件为 301 字节，SHA-256 CA6FDB3C3ACA7C74900D513F44CB65F585A8C27CA9C458B67A2873D9F42D09EC；其他附件哈希见前表与 Android 记录。
- 公开后通过不带凭据的 GitHub API 再读 v1.0.0，确认页面已公开、四个附件及 digest 正确；从 origin 取得标签后确认提交 SHA 一致。
- Android 密钥/密码/DPAPI 文件、unsigned APK、对齐暂存、SDK 路径配置均未上传；发行目录使用明确的四文件白名单，不上传整个目录。

本轮完成后停止。未来更新应读取当前规范与报告，沿用发布密钥；不得重新 clone、重装环境或覆盖已发布标签。
