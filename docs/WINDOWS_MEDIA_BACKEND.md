# Windows 媒体后端

Implemented / Tested（所列本机合成测试），2026-09-14。

- 固定 BtbN n9.0.1-29-gad500d59cb-20260913 LGPL shared 构建，来源/完整 flags/逐文件 SHA256 在 tool/native/ffmpeg-windows.json。
- tool/prepare_media_bundle.ps1 校验压缩包和各文件，再准备私有 runtime。windows/media_bundle.cmake 仅安装指定文件到应用旁 media/ffmpeg。应用不搜索系统 PATH，不使用其他软件自带 FFmpeg。
- 启动读取实际 encoders；libvips 从应用目录加载 DLL。没有 runtime 时音视频显示不可用，不能悄悄回退系统程序。
- arg vector 启动、无 shell；ffprobe/FFmpeg 限制 file,pipe 协议；HLS 额外验证本地片段、子清单、禁止保护/网络/越界/直播引用。DASH/concat 清单当前明确拒绝。
- 当前验证：MP4/MKV/MOV/WebM；MP3/WAV/FLAC/AAC/M4A/OGG/Opus；H.264/HEVC/AV1/VP9 软件转码；尺寸/帧率/采样率/声道/码率；兼容流优先 copy；MP3/FLAC/M4A 的 JPEG 封面与 title；本地 HLS 和双 m4s 合并。每个测试输出重新 probe 并完整解码。
- HEVC libkvazaar 要求尺寸为 8 的倍数，转码按需补边，其他已验证编码补齐到偶数。原文件保留；不同编码器画质与码率不保证等价。
- 取消运行中的 FFmpeg 后等待进程退出，再清理私有暂存；真实取消测试和后续任务测试已通过。
- 硬件编码仅完成名称调查，没有设备编码测试，不显示为已验收。字幕兼容 copy 保留；不能保留的流拒绝，不静默删除。

Windows 原生图片路径的 24 组大图前后对照见 PERFORMANCE_REPORT_v1.1.md。新的媒体工作台已接入图片原生路径；旧图片页面继续保留兼容引擎。原生 UI 已实测混合导入 100MP JPG、视频、音频并导出成功；三份输出独立完整解码通过。替换音轨 UI 与源视频压缩流保留已有自动回归，最新原生 UI 快照仍需复查。

原生组件尚未公开分发。libimagequant 已核实为官方包采用的 BSD 2.4.1 分支；其余传递许可与完整对应源码材料仍需在发行前核齐。独立 Validation 身份的安装、运行中阻止替换、同版本修复及卸载均通过；不是用户现有 v1 安装的正式升级验收。
