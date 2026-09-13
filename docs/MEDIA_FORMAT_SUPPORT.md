# 媒体格式状态

2026-09-14。输入和输出分别记录。Tested 仅表示下列合成测试；不表示该格式所有变体。Android 新后端当前仅编译通过，全部设备能力为 Experimental。

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
| DASH / 音乐加密缓存 | 暂不开放 | 暂不开放 | Experimental / Unsupported，详见 CACHE_ADAPTERS |

默认永不覆盖原图、原媒体和已存在输出。大文件采用路径/流式处理，不用整个视频 readAsBytes。大 WebP 仍可能耗费全图内存，100MP 合成样本峰值约 801 MiB，不宣传恒定内存。
