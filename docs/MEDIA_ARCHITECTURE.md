# 统一媒体架构

状态：Implemented / 已列平台测试 Tested；升级仍在收尾，已接入双平台媒体工作台。完整需求见 MEDIA_UPGRADE_REQUIREMENTS.md，实际支持范围见 MEDIA_FORMAT_SUPPORT.md。

保留 v1 的 imaging、services、持久化及 UI。在 `core/media` 增加独立模型、Backend/Adapter 接口、注册表、取消信号、有限并发调度、任务引擎及暂存输出管理。

- MediaProbe 表达真实格式、媒体类别、流、时长、尺寸、位率、采样率、声道、方向、透明与实际元数据。字幕作为流类型独立存在。
- MediaBackend 包含 probe/supports/execute；进度回调不假造图片百分比。
- DartImageBackend 包装既有 Isolate 服务。该后端开始编码后仍不可中断，完成则保留输出并明确返回 completed。原资源防护保留，直到原生大图路径验收后再改路由。
- ResourceScheduler 采用显式容量的 FIFO 槽，默认 1；取消排队立即退出，异常释放槽。图片任务读取 Windows/Android 当前可用内存形成保守预算，复杂 WebP/旋转单独估算；这不是 OOM 保证或自动并发调优。
- AdapterRegistry 要求唯一 id、合法置信度；最高置信度并列时拒绝歧义。Adapter 仅准备标准输入，不承担编码。
- TempFileManager 在输出卷内新建私有暂存目录，完成并探测后使用不覆盖的原子发布，重名编号。Windows MoveFileW、Android renameat2(RENAME_NOREPLACE)；不提前创建空占位。失败/取消只清理自己创建的目录；崩溃仍可能遗留私有暂存，不承诺断电事务恢复。
- MediaJobEngine 防止重复 id 同时启动，错误成为独立结果；一个任务失败不破坏调度器。

MediaWorkspaceController 与 UI 分离，负责混合导入、单文件失败隔离、预设兼容性、汇总历史和 24 小时未完成队列。重 CPU 图片在 Isolate；Windows 音视频在子进程，Android 在 FFmpegKit async session，整批使用前台服务。未验证后端不开放为有效选项；替换音轨先复核，再使用明确 input/map，不改变原视频文件。
