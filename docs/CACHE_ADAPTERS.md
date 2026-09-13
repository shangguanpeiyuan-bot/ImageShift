# 本地缓存适配状态

2026-09-14。仅处理用户选中的本地文件/目录，不登录、下载、上传或扫描浏览器/客户端私人目录。

| Adapter | 状态 | 真实能力 | 未实现 / 拒绝 |
| --- | --- | --- | --- |
| Bilibili 双 m4s | Implemented / Tested Windows | 选中目录直接两个 m4s，ffprobe 分辨音/视频，不依赖文件名；H.264/AAC copy 到 MP4；完整解码/源文件保持测试 | 多节目歧义、奇异头部/加密、不兼容容器拒绝；entry 元数据标题尚未提取 |
| 本地 HLS | Implemented / Tested Windows | 完整结束列表、本地片段、子清单；逐引用检查后 remux | 网络、直播、密钥保护、越界、缺失、非标准 URI 拒绝 |
| DASH | Experimental | 已识别并安全拒绝未验证清单 | 未实现安全 MPD 解析/本地片段组合 |
| KWM legacy | Experimental / Windows synthetic fixture tested | 16-byte magic、0x400 头、unsigned 64-bit 值，Isolate 内 64 KiB 分块处理；输出经 ffprobe 校验；保留内嵌音频标签/封面字节，失败/取消清理 | 仅合成互操作样本；没有当前客户端样本或 Android 验收，未知变体拒绝，不宣称通用 KWM |
| NCM | Unsupported | 已查证 MIT ncmdump 等参考实现，尚未接入 | 缺少经授权且可独立验证的真实变体样本；不能把自行构造算法闭环当作厂商格式完整兼容 |
| QMC / MFLAC / MGG | Unsupported | 参考实现明确同一后缀可对应多个版本，不能靠扩展名判断 | 尚未完成版本/密钥派生及样本审计；不自动尝试未知保护 |
| KGM / KGMA / VPR | Unsupported | 已读取历史 Unlock Music 系源码入口，依赖额外 WASM 组件 | 组件对应源码/版本和测试样本尚未核实，未复制或包装为可用功能 |

研究中的 music-key 项目是年轻的 MIT 项目，不因 README 声称支持就采纳全部算法。后续逐变体核实来源、测试素材与失败模型；不支持 DRM、缺少必要参数或未知版本必须返回 UnsupportedProtection / UnsupportedFormat。

KWM 参考：[Magiicccc/music-batch-unlock](https://github.com/Magiicccc/music-batch-unlock/blob/837c2ccd09d85eb0ae96132e96b84d2e5897b4c6/src/decrypt/kwm.ts)，固定提交 `837c2ccd09d85eb0ae96132e96b84d2e5897b4c6`，MIT (2019–2025 MengYX)。改写为 Dart streaming/Isolate、严格头验证、临时文件所有权及取消；未采用其联网 metadata 查询。完整声明在 third_party/Unlock-Music-MIT.txt；合成样本来源和哈希在 test/fixtures/media/README.md。
