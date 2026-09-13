# 媒体格式状态

2026-09-14。输入和输出分别记录。Tested 仅表示下列合成测试；不表示该格式所有变体。Android 新后端已在 API 35 x86_64 模拟器完成原生测试，尚不能替代 ARM64 真机验收。

| 类别 | Windows 输入 | Windows 输出 | 状态 / 边界 |
| --- | --- | --- | --- |
| 原生图片 | JPEG、PNG、WebP、TIFF | JPEG、PNG、WebP lossless、TIFF | Tested：alpha、白底、尺寸、4K–100MP 四格式；不是 ICC/动画完整验收 |
| 兼容图片 | 旧 BMP/GIF/TGA/ICO 等见 PHASE_A_REPORT | JPG/PNG/WebP | 沿用 v1 限制；动画/多页不能静默首帧 |
| HEIC / AVIF | 不开放 | 不开放 | Experimental：插件存在加载库不等于能力已验证 |
| 视频容器 | MKV、MP4、分片 MP4、HLS TS | MP4、MKV、MOV、WebM | Tested；AVI/FLV/其他输入变体尚需独立测试 |
| 视频编码 | H.264 及测试重新读取的 HEVC/AV1/VP9 | H.264 / HEVC / AV1 / VP9 | Tested：软件编码；按实际 encoder 和容器兼容性提供选项 |
| 音频 | AAC/MP3 及输出重新读取的各格式 | MP3/WAV/FLAC/AAC/M4A/OGG/Opus | Tested；不是全部采样率/声道/元数据组合 |
| 音频封面 | JPEG attached picture | MP3/FLAC/M4A | Tested；不支持的目标明确拒绝；PNG 封面仍待独立素材测试 |
| 本地缓存 | 两个真实音/视频 m4s、本地完整 HLS | 兼容容器 | Tested：无加密/前缀修复；不保证所有平台缓存版本 |
| KWM legacy | 合成头/音频样本 | 解包后走音频工作流 | Windows synthetic Tested / Experimental，非全部客户端版本 |
| DASH / NCM / QMC / KGM | 暂不开放 | 暂不开放 | Unsupported，详见 CACHE_ADAPTERS |

## Android 独立矩阵（API 35 x86_64 Debug 模拟器）

| 类别 | 实际测试输入 | 实际测试输出 | 限制 |
| --- | --- | --- | --- |
| 原生图片 | PNG；重新读取 JPEG/PNG/WebP | JPEG/PNG/WebP | 透明、白底、宽高、自动编号/原图保留；此包无 TIFF saver，未展示 TIFF 输出；大图/ICC/ARM64 尚未在设备验证 |
| 视频容器 | MP4；重新读取 MKV/MOV/WebM | MP4/MKV/MOV/WebM | 全部实际完整解码；兼容格式 remux，WebM 用 AV1 |
| 视频编码 | H.264、重新读取 HEVC/AV1 | H.264/HEVC/AV1 | VP9 advertised 但产物完整解码失败，已禁用 Android VP9 编码；硬件编码未开放 |
| 音频 | WAV 及输出重新读取 | MP3/WAV/FLAC/AAC/M4A/OGG/Opus | 全部完整解码；没有证明所有封面/声道/采样率组合 |
| 后台任务 | 两段各 8 秒本地媒体命令 | 两段顺序完成 | 真实按 Home 后前台服务保持到整批结束；不是长时间/省电模式/真机厂商策略验收 |

默认永不覆盖原图、原媒体和已存在输出。大文件采用路径/流式处理，不用整个视频 readAsBytes。大 WebP 仍可能耗费全图内存，100MP 合成样本峰值约 801 MiB，不宣传恒定内存。

Windows 新增真实验证：仅调整音频参数时，兼容的视频流直接复制，输出压缩视频 streamhash SHA-256 与输入相同。替换音轨入口接受用户选中的单音轨文件，保留视频时长、截去过长音频，短音频结束后无音频；只支持单视频且无字幕/附加流的输入。合成 WAV 替换为 MKV 的输出完整解码、视频流 hash、时长与源文件保留均通过；恢复时替换音轨丢失会拒绝恢复该任务，不偷偷换回原音频。Android 的新增替换音轨路径尚需设备回归。
