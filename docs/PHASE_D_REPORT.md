# Phase D 实际进度与交付

日期：2026-09-13。**D 尚未全部完成，不能宣称已经公开发布。** 已完成本地构建、Windows 安装验收和源码 push，剩余 Android 正式签名、项目许可证与 GitHub Release。

## 已执行

- flutter pub get 成功，flutter analyze 无问题，flutter test **131 项全部通过**。最终日志在 artifacts/phase-d，先前测试/lint 失败已修复，不把失败日志当作最终结果。
- flutter build windows --release 成功。完整 runner、flutter_windows.dll、插件 DLL、data/app.so、字体/资源/开源声明均在构建目录。
- flutter build apk --release 成功。已取消模板 debug signing 回退；产物当前 **未签名**，apksigner verify 返回 DOES NOT VERIFY / Missing META-INF/MANIFEST.MF，不能安装发行。没有以调试签名冒充正式签名。
- Android Release 合并权限检查仅含应用自身的非导出 receiver 权限，**没有 INTERNET 或全盘存储权限**。没有断开用户网络或把静态权限检查称作 Android 真机断网测试。
- 从本机实际已安装 Visual Studio 的可再分发 CRT 目录带入 DLL；安装后检查进程模块，VCRUNTIME140、VCRUNTIME140_1、MSVCP140、flutter_windows 均从应用安装目录加载，未依赖 Flutter SDK。
- 使用实际 winget 查询得到的 Inno Setup 6.7.3（JRSoftware.InnoSetup），当前用户安装成功。构建脚本 tool/imageshift.iss 和 tool/package_windows.ps1 不含开发机 SDK 路径。
- Installer 安装退出 0，程序实际启动。包含开始菜单应用/卸载入口及可选桌面快捷方式。深色主题写入本地 JSON 后关闭重启仍恢复，welcome 状态正确。
- 卸载退出 0，程序 exe 与开始菜单快捷方式移除，用户设置保留。最终安装器再次安装退出 0，桌面快捷方式实际创建，最终 Release 启动成功；本机保留可运行安装。

## 本机 Windows 交付物

路径为 artifacts/phase-d/dist（Git 忽略，不把大二进制提交源码仓库）：

| 文件 | 字节 | SHA-256 |
| --- | --- | --- |
| ImageShift-v1.0.0-Windows-Setup.exe | 11519612 | 5A137F720EECF293BA776020DB80A0F6EB710988FA210B04021E9081E9A604EC |
| ImageShift-v1.0.0-Windows-x64.zip | 13632442 | E63BF3B813B0DCC542B48DC9C253B3ADEB06347D5B4242E2317A4446D39200F0 |

安装范围为当前用户，默认使用系统 LOCALAPPDATA/Programs/ImageShift。ZIP 必须整体解压，不可只取 exe。安装器没有 Windows Authenticode 签名，不伪称已认证发布者。原生架构为 x64；未测试 ARM64 模拟运行和全新 Windows 机器。

Android 原始 unsigned 产物在 build/app/outputs/flutter-apk/app-release.apk；它不是最终 ImageShift-v1.0.0-Android.apk，不加入可安装下载附件。签名后的哈希必须重新生成。

## 日志与截图

artifacts/phase-d：pub-get.log、analyze.log、test.log、windows-release.log、android-release.log、installer-build.log、install.log、uninstall.log、install-final.log。截图：installed-welcome.png、installed-settings.png、restart-dark.png、installed-final.png。文件、命令和原生 UI 都实际检查过。

源码、文档及测试已整理为本地提交范围；检查排除了 build、artifacts、local.properties、私钥/keystore 与本机 SDK 配置。上游许可证保留原文空白，Git 属性仅免除这些许可证的空白检查。Git 提交哈希以实际 git log 为准；没有将构建产物放入源码提交。

## 已知限制与剩余步骤

1. **项目许可证尚未选定**，没有擅自套用 MIT 或把依赖许可冒充整个项目许可。
2. **Android 签名尚待用户确认**是否沿用已有密钥，或生成仓库外 ImageShift 专用密钥；密码/密钥不入 Git。正式发行前必须 apksigner 验证成功，并核实最终 Application ID/版本。
3. GitHub 浏览器授权后，Credential Manager 登录进程退出 0，账号列表确认 shangguanpeiyuan-bot。随后 `git push -u origin main` 实际成功，源码提交 18193a2 已推送，main 跟踪 origin/main。此前缺凭据的错误属于授权前尝试，不代表本次授权失败。尚未创建 v1.0.0 Release；待签名和许可确定后上传验证过的 APK 与安装器。不修改 origin，不 force push。
4. **Android 无真机或 AVD**，SAF、真实触摸/系统返回/缓存回收和实际手机内存仍未验收。此缺口不等于编译失败，亦不能称为设备测试通过。
5. desktop_drop 旧 KGP 与 SDK XML 版本差异仍有非阻塞警告；未来 Flutter 升级须复查。Windows CRT 应用本地部署由发行者跟进安全更新。
6. 8K 超过 24 MP 上限会明确拒绝。性能与格式变体限制见 C/A/B 报告；P2 文件夹/剪贴板/系统通知未实现，不作为 v1 已有能力。

## 可复核官方资料

- [Inno Setup 非管理员模式](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm)、[安装参数](https://jrsoftware.org/ishelp/topic_setupcmdline.htm)、[许可证](https://jrsoftware.org/files/is/license.txt)
- [Microsoft C++ 部署示例](https://learn.microsoft.com/en-us/cpp/windows/deployment-examples?view=msvc-170)
- [Android 签名说明](https://developer.android.com/studio/publish/app-signing)

下一次继续应从签名/许可/登录的实际状态接续，不能重新 clone、安装 Flutter 或重复整个工程开发。
