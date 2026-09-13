# 本地缓存适配状态

2026-09-14。仅处理用户选中的本地文件/目录，不登录、下载、上传或扫描浏览器/客户端私人目录。

| Adapter | 状态 | 真实能力 | 未实现 / 拒绝 |
| --- | --- | --- | --- |
| Bilibili 双 m4s | Implemented / Tested Windows | 选中目录直接两个 m4s，ffprobe 分辨音/视频，不依赖文件名；H.264/AAC copy 到 MP4；完整解码/源文件保持测试 | 多节目歧义、奇异头部/加密、不兼容容器拒绝；entry 元数据标题尚未提取 |
| 本地 HLS | Implemented / Tested Windows | 完整结束列表、本地片段、子清单；逐引用检查后 remux | 网络、直播、密钥保护、越界、缺失、非标准 URI 拒绝 |
| DASH | Experimental | 已识别并安全拒绝未验证清单 | 未实现安全 MPD 解析/本地片段组合 |
| NCM / QMC / KGM / KWM | Experimental research | 调查了现有本地项目来源与 license，尚未复制未审计算法 | 当前均不显示可转换，不宣称通用解密；无经过验证的变体测试 |

研究中的 music-key 项目是年轻的 MIT 项目，不因 README 声称支持就采纳全部算法。后续逐变体核实来源、测试素材与失败模型；不支持 DRM、缺少必要参数或未知版本必须返回 UnsupportedProtection / UnsupportedFormat。
