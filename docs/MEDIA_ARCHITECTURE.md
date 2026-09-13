# 统一媒体架构

状态：Experimental，开发中，尚未接入正式 UI。完整需求见 MEDIA_UPGRADE_REQUIREMENTS.md。

保留 v1 的 imaging、services、持久化及 UI。在 `core/media` 增加独立模型、Backend/Adapter 接口、注册表、取消信号、有限并发调度、任务引擎及暂存输出管理。

- MediaProbe 表达真实格式、媒体类别、流、时长、尺寸、位率、采样率、声道、方向、透明与实际元数据。字幕作为流类型独立存在。
- MediaBackend 包含 probe/supports/execute；进度回调不假造图片百分比。
- DartImageBackend 包装既有 Isolate 服务。该后端开始编码后仍不可中断，完成则保留输出并明确返回 completed。原资源防护保留，直到原生大图路径验收后再改路由。
- ResourceScheduler 目前采用显式容量的 FIFO 槽，默认 1；取消排队立即退出，异常释放槽。尚未接入系统实时资源策略。
- AdapterRegistry 要求唯一 id、合法置信度；最高置信度并列时拒绝歧义。Adapter 仅准备标准输入，不承担编码。
- TempFileManager 在输出卷内新建私有暂存目录，完成后独占目标名称再 rename，重名编号。失败/取消清理仅限自己创建的目录。崩溃可能遗留暂存或空占位，尚不承诺断电事务恢复。
- MediaJobEngine 防止重复 id 同时启动，错误成为独立结果；一个任务失败不破坏调度器。

后续按 libvips → FFmpeg → 平台桥接 → 标准音视频 → 缓存适配 → UI → 回归逐步实施。未验证后端不开放为有效选项。
