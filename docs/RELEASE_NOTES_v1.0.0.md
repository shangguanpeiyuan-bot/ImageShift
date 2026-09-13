# ImageShift v1.0.0

面向 Windows 和 Android 的完全本地图片处理工具，采用 MIT 许可证。

## 功能

- 基于文件内容识别格式，输出 JPG、PNG、静态无损 WebP。
- 批量转换、尺寸调整、裁剪、旋转、翻转、透明背景合成、已知元数据清理、批量命名。
- 原图保护、自动重名编号、后台串行队列、取消未开始项、单文件失败隔离。
- 真实结果统计、前后对比、100% 预览、主题、历史摘要、内置与自定义预设。
- Windows 原生文件选择/拖拽；Android 官方 SAF 文件及目录授权。

## 下载

- `ImageShift-v1.0.0-Android.apk`：Android 7.0 / API 24 及以上，包含 ARM64、ARMv7、x86_64；专用发布密钥签名。
- `ImageShift-v1.0.0-Windows-Setup.exe`：Windows x64 当前用户安装，包含运行库、开始菜单、卸载及可选桌面快捷方式。
- `ImageShift-v1.0.0-Windows-x64.zip`：完整便携目录，请全部解压，不要只复制 exe。
- `SHA256SUMS.txt`：附件 SHA-256 校验值。

## 验证与边界

131 项自动测试通过，静态分析无问题，双平台 Release 构建成功。Windows 安装、启动、主题重启恢复和卸载已实测。Android APK v2/v3 签名及 16 KB zip 对齐验证通过。

**Android 尚无真机/模拟器运行验收**；系统文档提供程序、实际触摸交互和手机内存行为仍待设备验证。Windows 安装器未作 Authenticode 签名；未测试 ARM64 模拟及全新 Windows 机器。

所有图片处理在本机完成，不上传图片；Android Release 没有 INTERNET 或全盘存储权限。默认永不覆盖原图和已有输出。

当前输入限制：128 MiB / 2400 万像素 / 单边 16384 px，每批最多 500 项。8K 超过像素上限会拒绝。动画、多页以及部分 TIFF/TGA/ICO 变体不支持；WebP 只输出无损，不提供伪有损质量参数。元数据清理不保证所有未知私有标签或完整色彩管理。

Android 签名证书 SHA-256：`10dd62ac70bd268f23cb3ddf1b7f699501e09752ea6adc0e45d2eb2d55dd72ba`。
密钥与密码不包含在仓库或发行附件中。
