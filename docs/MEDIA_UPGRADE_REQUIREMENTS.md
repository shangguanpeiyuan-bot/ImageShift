你现在负责继续开发现有项目 ImageShift。不要把它当成新项目，不要重新初始化，不要只给方案，不要停留在分析阶段。你的任务是基于现有仓库实际状态，自主完成从当前 v1.0.0 图片转换器到高质量“本地综合媒体转换器”的工程升级。

==================================================
一、项目身份与不可破坏项
==================================================

项目：

本地目录：
D:\ImageShift

GitHub：
https://github.com/shangguanpeiyuan-bot/ImageShift

Flutter project name：
imageshift

Flutter organization：
io.github.shangguanpeiyuanbot

Android Application ID：
io.github.shangguanpeiyuanbot.imageshift

当前版本：
1.0.0+1

当前公开 Release：
v1.0.0

开发平台：
Windows + Android

已知开发环境：
Flutter 3.47.4 Stable
Dart 3.13.3
JDK 21
Windows x64
Android SDK 已配置

现有 Android 正式发布签名必须继续沿用原签名身份。
绝对不要重新生成新 Android 发布密钥替代现有密钥。
绝对不要把 keystore、p12、密码、DPAPI 文件、token、私钥等提交 Git。
如果正式签名需要用户本地已有秘密，不要打印秘密，也不要要求用户把密码粘贴到聊天或日志。

开始任何操作前必须依次阅读：

AGENTS.md
docs/PRODUCT_SPEC.md
docs/ROADMAP.md
docs/PHASE_A_REPORT.md
docs/PHASE_B_REPORT.md
docs/PHASE_C_REPORT.md
docs/PHASE_D_REPORT.md
docs/DEPENDENCY_AUDIT.md
README.md
pubspec.yaml
pubspec.lock

同时检查：

git status
git log
当前 branch
当前目录结构
现有测试
现有 Release 配置
Android Gradle
Windows CMake / Installer
当前实际源码

不要猜路径、类名、配置、API、包名和依赖行为。

如果本文与实际代码不一致：
以“最新用户目标 + 实际仓库状态”为准，
但不得擅自改变 project name、Application ID 和发布签名身份。

不要重新：

git init
git clone
更换 origin
force push
覆盖 v1.0.0 tag
重装正常工作的 Flutter/Android/JDK 环境

==================================================
二、最终产品目标
==================================================

把 ImageShift 从：

“图片格式转换器”

升级为：

“完全本地运行的图片 + 视频 + 音频综合媒体转换工作台”。

质量要求不是 Demo 水平，而是按照成熟付费软件的工程质量来做，即便最终软件免费开源。

用户应当可以：

1. 导入图片
2. 导入视频
3. 导入音频
4. 导入经过验证支持的本地媒体缓存/特殊媒体格式
5. 自动识别真实格式
6. 选择输出格式
7. 单个或批量转换
8. 查看真实转换进度
9. 取消任务
10. 失败任务独立失败
11. 查看结果
12. 管理输出
13. 保存预设
14. 查看历史
15. 大文件尽可能正常处理

核心体验：

“用户不需要知道底层用了 FFmpeg、libvips、某个 Adapter 或什么命令。”

用户只看到：

导入
→ 自动识别
→ 选择输出
→ 转换
→ 完成

==================================================
三、隐私和安全原则
==================================================

所有实际媒体处理默认必须本地完成。

禁止为了转换而：

上传用户文件
调用云端媒体转换 API
加入广告
加入账户系统
收集用户媒体内容
扫描无关目录

不得覆盖源文件。

所有输出创建新文件。

输出冲突：

photo.mp4
photo_1.mp4
photo_2.mp4

或对应格式。

禁止静默覆盖已有文件。

对于缓存、特殊格式和媒体结构：

只处理用户主动选择的本地文件/目录。

可以支持：
公开实现、经过验证、用户有权处理的本地媒体格式、缓存格式、容器结构、音视频分离流、普通分片。

不要设计“未知 DRM 通用破解器”。

如果某文件受到未支持 DRM / 授权保护：
明确告诉用户“不支持该保护格式”，而不是伪装成转换失败或承诺万能破解。

==================================================
四、架构原则
==================================================

禁止把 FFmpeg 命令、NCM 逻辑、B站缓存识别等直接塞进 UI Widget。

建立统一媒体架构。

建议结构方向：

lib/
  core/
    media/
      model/
      probe/
      backend/
      adapter/
      jobs/
      output/

最终至少形成这些抽象：

MediaKind
MediaProbe
MediaStreamInfo
MediaJob
MediaResult
MediaError
MediaProgress
MediaBackend
MediaAdapter
AdapterRegistry
CancellationToken
MediaJobEngine
ResourceScheduler
TempFileManager

实际文件位置根据当前项目架构合理调整，不要机械照抄。

现有：

lib/core/imaging/

先保留。

不要第一步就删除重写。

先把已有图片引擎包装成新的统一 Backend。

最终逻辑应类似：

ImageShift UI
        ↓
Unified Media Job Engine
        ↓
┌──────────┬───────────┬────────────┐
Probe      Backend     Adapter
│           │            │
图片识别    libvips      Bilibili cache
ffprobe     FFmpeg       NCM
            Dart image   QMC
                         KGM
                         KWM
                         其他未来 Adapter

Adapter 只负责：

“特殊来源 → 标准媒体输入描述”

真正编码尽量交给统一 Backend。

==================================================
五、第一阶段：统一媒体模型
==================================================

先完成统一媒体领域层。

至少具备：

enum MediaKind {
  image,
  video,
  audio,
  unknown
}

MediaProbe 应能表达：

真实媒体类型
container / format
文件大小
宽度
高度
时长
编码
音视频流
字幕流
bitrate
sample rate
channels
metadata
orientation
alpha（图片需要时）
其他实际探测信息

不要只根据文件扩展名判断媒体类型。

图片继续使用现有真实格式检测。

视频/音频后续由 ffprobe 做真实检测。

建立：

abstract interface class MediaBackend

至少包含：

backend id
supports()
execute()
progress
cancellation

建立：

abstract interface class MediaAdapter

至少包含：

inspect()
prepare()

不要在这一阶段破坏现有 UI。

为所有模型和接口增加真正的单元测试。

==================================================
六、图片引擎升级
==================================================

现有 Dart image 4.9.2 图片后端已经证明可用，但当前存在资源限制：

128 MiB 输入文件
24 MP
单边 16384 px

已知 24MP 图片处理会占用较高内存。

不要简单做：

24MP → 100MP

或：

128MB → 1GB

这是错误解决方案。

目标：

ImageShift 不设置人为固定图片大小上限。

但不要宣传“真正无限”。

准确产品定义：

“ImageShift 不设置人为固定媒体文件大小上限；实际处理能力取决于设备可用内存、磁盘空间、文件系统和编解码器。”

研究并实际验证：

libvips

同时研究当前维护状态良好的 Dart/Flutter FFI 集成，例如：

fluttercandies/libvips_ffi

但：

不要仅因为项目存在就直接采用。

必须验证：

当前版本
维护情况
License
Windows x64
Android ARM64
Android 16 KB page alignment
Flutter 3.47.4
Dart 3.13.3
二进制体积
HEIC/HEIF
AVIF
JPEG
PNG
WebP
TIFF
ICC
Orientation
Alpha
Metadata
异常处理
取消
临时文件

目标架构：

Small Image Fast Path
→ 当前 Dart image 或最适合的小图 Backend

Large Image Low-Memory Path
→ libvips/native backend

不要人为按固定 24MP 判死。

由 ResourceScheduler / backend 根据资源和图像特征决定。

大图尽量使用：

lazy processing
demand-driven processing
tile/region
scanline
shrink-on-load
decode-time resize
streaming encode
减少 full-frame buffer
减少 RGBA 全图复制
减少重复 orientation bake
减少重复 composite buffer

==================================================
七、图片 benchmark
==================================================

必须建立可重复 benchmark。

至少测试：

3840×2160
4000×3000
6000×4000
7680×4320
约 50MP
约 100MP

格式至少：

JPEG
PNG
WebP
TIFF

如果实际 backend 稳定支持：
HEIC
AVIF

记录：

输入格式
输入字节
分辨率
处理操作
Backend
耗时
峰值 RSS
输出大小
输出真实格式
输出尺寸
是否成功重新解码

必须提供：

Before
vs
After

不要只说“理论上更快”。

==================================================
八、视频/音频核心：FFmpeg
==================================================

研究当前 FFmpeg 官方稳定版本。

不要凭记忆指定版本。

核实：

License
Windows
Android
codec
hardware acceleration
build flags
binary size
维护状态

Windows 第一方案：

固定版本：

ffmpeg.exe
ffprobe.exe

由 ImageShift 控制版本和配置。

不要依赖用户自己安装 FFmpeg。

优点：

进程隔离
崩溃不拖死 Flutter
升级简单
日志可控
ffprobe 完整
进度可获取

Android：

研究当前维护的 FFmpeg Android/Flutter 方案。

优先研究：

FFmpegKitNext
或
自建 FFmpeg native package

但不要直接假设最终方案。

验证：

arm64-v8a
armeabi-v7a 是否值得继续
x86_64 emulator
minSdk 24
target SDK
Flutter 当前版本
Android 16 KB page alignment
Release APK
ABI
体积
FFmpeg license
FFmpeg build flags

==================================================
九、FFmpeg License
==================================================

这是硬性要求。

建立：

docs/THIRD_PARTY_COMPONENTS.md

FFmpeg 每次构建必须记录：

FFmpeg version/tag
source commit
target
configure command
enabled libraries
是否 --enable-gpl
是否 --enable-nonfree
static / dynamic
binary SHA256
License files
codec smoke tests

不要随便从第三方网站下载一个 ffmpeg.exe 就加入 Release。

优先：

官方来源
可信维护方
或自己构建。

所有外部 binary 要记录来源、版本和 SHA256。

==================================================
十、标准视频能力
==================================================

实现常见视频容器和编码探测。

优先支持常见输入：

MP4
MKV
MOV
WebM
AVI
FLV
MPEG-TS / TS
M4V

根据实际 FFmpeg build 能力再扩展。

常见输出：

MP4
MKV
WebM
MOV

不要为了“格式数量”堆一堆未经测试格式。

实现：

视频转封装
视频重新编码
提取音频
替换/合并音频
视频 + 音频流合并
基础字幕流保留
基础 metadata
分辨率
码率
帧率
codec 选择

==================================================
十一、必须优先 Remux
==================================================

如果输入 codec 已经兼容目标 container：

不要重新编码。

例如：

视频流 H.264
音频 AAC

需要变成 MP4

优先：

-c copy

而不是重新压一遍。

实现决策：

Probe
→ 判断 stream 与目标 container 是否兼容
→ 可以 stream copy：
   Remux
→ 不兼容：
   Transcode

UI 应区分：

无损快速转换
重新编码

但普通用户不必理解所有技术细节。

==================================================
十二、视频转码
==================================================

至少研究：

H.264
H.265 / HEVC
AV1
VP9

但输出能力必须基于实际 build 验证。

不要显示没有 encoder 的选项。

可用时支持：

software encoder
hardware encoder

Windows 可研究：

NVENC
QSV
AMF

Android 可研究 MediaCodec/平台硬件路径。

但硬件编码只能作为优化：

软件编码必须作为兼容 fallback。

不要假定所有电脑都有 NVIDIA。

==================================================
十三、音频
==================================================

标准音频优先支持：

MP3
WAV
FLAC
AAC
M4A
OGG
Opus

根据实际 codec 验证增加。

支持：

格式转换
码率
采样率
声道
无损/有损
metadata
封面
音量基本处理（后续能力）

不要无意义把 FLAC → FLAC 重新有损编码。

==================================================
十四、大文件
==================================================

视频和音频必须使用流式处理。

禁止：

readAsBytes() 整个读取 30GB 视频

正确模型：

read packet
↓
decode
↓
process
↓
encode
↓
write
↓
continue

100GB 视频不能因为“100GB”本身就直接被拒绝。

实际失败只能来自：

磁盘空间不足
文件系统限制
真实内存不足
codec 不支持
文件损坏
权限失败
用户取消

转换前尽量预估：

需要临时空间
输出空间

如果磁盘空间明显不足：
提前提示。

==================================================
十五、统一进度
==================================================

不能伪造百分比。

FFmpeg：

优先使用机器可解析 progress：

-progress
或当前稳定可靠机制

基于：

out_time
duration

计算。

Remux 根据真实时间戳或处理进度。

图片如果后端无法给精确百分比：

显示：

处理中

而不是做假 37%。

统一 MediaProgress：

queued
probing
preparing
processing
finalizing
completed
failed
cancelled

==================================================
十六、取消与临时文件
==================================================

所有媒体转换先写：

临时输出

例如：

.video.mp4.imageshift.part

成功：
原子 publish/rename

失败：
清理 temp

取消：
安全停止
清理 temp

绝对不能留下半个文件却被 UI 标成成功。

Windows FFmpeg：

取消时优雅终止；
如果无法终止再强制 kill。

Android：

使用对应 session cancellation。

==================================================
十七、ResourceScheduler
==================================================

不要：

Future.wait(500 个大型任务)

建立统一资源调度器。

考虑：

CPU core
available memory
任务类型
媒体尺寸
codec
磁盘速度/空间
平台

初始原则：

Probe：
可以有限并发

超大图片：
1 个重任务

视频转码：
默认 1 个重任务

音频：
根据资源 1~2

Remux：
主要磁盘 IO，仍限制并发

小图：
有限并发

以后根据 benchmark 动态调整。

==================================================
十八、Bilibili 本地缓存
==================================================

用户希望：

B站本地缓存
→ MP4

不要把已归档 BBDown 作为长期核心依赖。

可以研究：

BBDown 的历史实现和经验
m4s-converter 类项目
B站缓存目录结构
其他维护良好的项目

建立独立：

BilibiliCacheAdapter

用户主动选择缓存文件/目录。

Adapter：

识别实际缓存结构
读取可用 metadata
定位 video stream
定位 audio stream
调用 ffprobe 复核
生成标题/输出名
交给 FFmpeg remux

不要仅用：

“大文件就是 video，小文件就是 audio”

这种脆弱规则。

如果本质上是：

video.m4s
audio.m4s

优先无损：

stream copy
→ MP4

不要重新编码。

原缓存不得修改。

==================================================
十九、HLS / DASH / 分片
==================================================

研究成熟项目：

N_m3u8DL-RE
以及其他当前维护良好的实现。

目标是支持用户主动选择的、本地合法媒体清单/分片：

.m3u8
.mpd
.ts
m4s segments

适合时：

合并
remux
转换

不要擅自加入“抓取所有网站付费资源”的宣传。

如果 playlist/segment 受到当前未支持的 DRM：
明确拒绝。

==================================================
二十、特殊音乐缓存 Adapter
==================================================

研究维护良好的 GitHub 项目，例如：

MusicKey
Unlock Music 系历史项目
其他当前可靠实现

重点研究它们：

流式解码
格式嗅探
metadata
封面
批量任务
错误处理
内存控制

目标逐个 Adapter：

NcmAdapter
QmcAdapter
KgmAdapter
KwmAdapter

根据实际格式还可增加：

KGMA
VPR
MFLAC
MGG

但必须逐格式验证。

禁止：

一个巨大 decrypt_music.dart 塞所有逻辑。

每种格式记录：

格式版本
magic/识别方式
结构
streaming
输出实际 codec
metadata
cover
Windows 测试
Android 测试
来源项目
许可证
已知不支持变体

不要把未知 DRM 保护包装成“万能解密”。

==================================================
二十一、第三方项目融合原则
==================================================

目标不是复制几十个仓库。

目标是：

研究成熟项目
→ 学习其设计
→ 必要时在许可证允许范围复用
→ 抽象成 ImageShift Backend/Adapter
→ 统一用户体验

每个项目必须审查：

最近维护情况
issues
release
license
架构
平台
依赖
binary
安全
测试
代码来源

建立：

docs/THIRD_PARTY_COMPONENTS.md

字段至少：

Component
Upstream URL
Version
Commit
Purpose
License
Distribution
Static/Dynamic/CLI
Build Flags
Windows x64
Android arm64
Binary SHA256
Modified Code
Notices
Update Policy

如果复制具体代码：

必须记录：

来源 repo
commit
具体文件
许可证
修改情况
attribution

==================================================
二十二、Media Adapter Registry
==================================================

以后新增特殊格式不应该修改整个系统。

建立：

AdapterRegistry

例如：

StandardImageAdapter
StandardVideoAdapter
StandardAudioAdapter
BilibiliCacheAdapter
NcmAdapter
QmcAdapter
KgmAdapter
KwmAdapter

后续可以继续添加。

每个 Adapter：

inspect

返回可信度/匹配结果。

不能多个 Adapter 都瞎猜成功。

==================================================
二十三、图片格式能力扩展
==================================================

在 backend 实际验证的前提下逐步加入：

JPG/JPEG
PNG
WebP
BMP
TIFF
GIF
TGA
ICO
HEIC
HEIF
AVIF

未来可评估：

JPEG XL

但：

动画 GIF
APNG
animated WebP
multi-page TIFF
multi-image ICO

必须有明确策略。

不得静默只保存首帧却装作完整转换成功。

如果不能完整保留：
提前明确提示或拒绝。

==================================================
二十四、ICC / 色彩管理
==================================================

这是成熟软件必须处理的问题。

研究：

ICC profile
sRGB
Display P3
CMYK JPEG
wide gamut

libvips/lcms2 路线。

至少避免：

P3 图片转完明显偏色
CMYK JPEG 错色
ICC 被错误丢弃

建立真实测试素材和测试。

==================================================
二十五、EXIF / metadata
==================================================

继续保留现有 Orientation 正确处理。

以后统一 metadata pipeline。

对：

图片
视频
音乐

分别处理。

不能声称“完整保留所有 metadata”除非真正验证。

Metadata 清理也一样。

==================================================
二十六、UI 重构
==================================================

底层稳定后再重构 UI。

不要第一天改 UI。

最终导航可以从图片专用变成：

首页
转换
批量任务
媒体工具
历史
设置
关于

或根据现有设计系统做更合理方案。

首页：

导入文件

自动接受：

图片
视频
音频
已支持缓存

导入后自动识别媒体。

工作台根据类型切换：

图片参数
视频参数
音频参数

不要展示无效选项。

==================================================
二十七、统一任务列表
==================================================

一批任务可以混合：

photo.png
movie.mkv
song.flac

每一项：

类型
真实格式
大小
状态
目标格式
进度
耗时
错误

但参数按媒体类型设置。

批量不能因为一个损坏视频就整批失败。

==================================================
二十八、历史与预设
==================================================

现有历史/预设不要推倒。

逐步升级为：

ImagePreset
VideoPreset
AudioPreset
GeneralPreset

历史仍只记录摘要。

不要存用户媒体本体。

不要把整个原文件路径永久写入不必要的数据。

==================================================
二十九、安装包体积
==================================================

加入：

libvips
FFmpeg
native codecs

之后体积肯定会上升。

记录：

v1.0 size
增加 libvips 后
增加 FFmpeg 后
Android APK
Windows Setup
Windows ZIP

避免无意义打包：

所有 codec
所有 ABI
所有开发文件
sample
docs
debug symbols

但不要为了减体积删掉必需 License。

==================================================
三十、GitHub Actions
==================================================

建立：

.github/workflows/ci.yml

至少：

flutter pub get
flutter analyze
flutter test

Windows：

Release build regression

Android：

不依赖私人签名材料的 compile/build regression

不要把正式 Android 私钥放 GitHub Secrets，除非用户以后明确要求自动正式发布。

现在 CI 只做构建验证即可。

缓存 Flutter 依赖以节省时间。

CI 失败必须修。

==================================================
三十一、测试策略
==================================================

目前已有大量测试。

原测试不得丢。

每阶段：

原测试全部通过
+
新增测试

必须包含真实媒体输出测试。

图片：

输出重新 decode

视频：

ffprobe 输出

音频：

ffprobe 输出

检查：

container
codec
duration
dimensions
audio stream
file exists
file nonzero

不要写：

expect(true, true)

这种假测试。

==================================================
三十二、FFmpeg smoke tests
==================================================

自动生成小型测试媒体：

color video
sine audio

测试：

video remux
video transcode
audio extract
audio convert
mux
metadata

不要在 Git 仓库提交几 GB 测试文件。

大型 benchmark 放：

artifacts/

并保持 Git ignore。

==================================================
三十三、B站测试
==================================================

不要依赖在线账户。

使用用户提供或自己合法生成的、本地结构测试素材。

验证：

双 m4s
audio/video identification
remux
输出 MP4
duration
audio
video
文件名
源文件不变

==================================================
三十四、大文件 benchmark
==================================================

至少准备：

图片：
4K
12MP
24MP
8K
50MP
100MP

视频：
短视频功能测试
1GB 级 remux（可生成 sparse/测试素材，按实际条件）
更大文件只在磁盘和时间允许时测试

不要为了 benchmark 把 SSD 填满。

记录：

elapsed
peak memory
CPU
input
output
backend
success/failure

==================================================
三十五、性能目标
==================================================

不要写死虚假 KPI。

原则：

小文件：
启动和 probe 快

remux：
接近磁盘 IO 能力

图片：
比当前全内存 Dart 路径显著降低大图内存

UI：
任何媒体转换不得阻塞 Flutter UI thread

后台：

Isolate
native process
native library

==================================================
三十六、错误模型
==================================================

统一错误：

unsupportedFormat
unsupportedCodec
unsupportedProtection
corruptedMedia
permissionDenied
diskFull
outOfMemory
resourceUnavailable
encoderUnavailable
decoderUnavailable
invalidParameters
cancelled
processFailed
temporaryFileFailure
unknown

用户看到中文可理解信息。

技术日志保留：

exit code
backend
codec
stage

但不要记录：

账号 token
秘密
密钥
敏感完整 metadata

==================================================
三十七、Windows Installer
==================================================

现有 Installer 已能工作。

继续完善。

此前用户遇到过：

desktop_drop_plugin.dll
DeleteFile failed; code 5
拒绝访问

说明升级/重装时可能存在运行中 DLL 锁定。

改进安装器：

检测 ImageShift 是否正在运行
友好提示关闭
能正常升级/修复
避免裸露 Inno Setup Code 5 给普通用户
不要粗暴杀用户其他程序

测试：

安装
启动
覆盖安装
同版本 repair
升级
卸载
运行中升级
安装后启动

==================================================
三十八、Windows Authenticode
==================================================

当前 Windows Installer 无 Authenticode 签名。

不要伪造证书。

如果没有用户真实代码签名证书：

保持未签名
文档明确

不要生成自签名证书冒充可信发行者。

==================================================
三十九、Android
==================================================

用户已经实际在 Android 真机上验证现有 v1.0 可以运行。

更新以前文档中：

“Android 真机未验收”

这种已过时内容。

但新 FFmpeg/libvips 功能必须重新做真机测试。

重点：

SAF
大文件
长任务
内存
后台/锁屏
取消
系统杀进程
缓存
磁盘
16KB alignment
ARM64

如果当前电脑连接用户手机：
实际运行测试。

如果未连接：
不要假装完成。

==================================================
四十、Android 长任务
==================================================

视频转码可能需要：

30分钟
1小时
更久

研究 Android 正确长任务方案：

Foreground Service
notification
lifecycle

不要仅依赖 Flutter 页面活着。

如果涉及新的 Android 权限：

只请求必要权限
解释用途。

不要申请全盘存储权限。

==================================================
四十一、任务恢复
==================================================

长期目标：

应用被关闭/崩溃后：

已完成任务保留
未完成任务能够标记 interrupted
可以重新开始

不要伪装从编码一半断点继续，除非实际支持。

==================================================
四十二、文件安全
==================================================

任何 output：

先 temp
后 publish

源文件：

永不覆盖

用户删除任务：
默认只从列表移除

不能删除源文件。

==================================================
四十三、版本管理
==================================================

不要一开始直接发布。

开发期间：

保持明确 feature branch 或按照实际 git 流程安全工作。

建议新版本：

1.1.0

但最终版本号在所有功能/测试完成后再更新。

不要修改已经发布：

v1.0.0

不要移动 tag。

==================================================
四十四、Git 工作方式
==================================================

开始：

git status
git branch
git log

开发过程中小步提交。

建议：

stage0 media architecture
image backend
ffmpeg backend
audio/video
adapters
ui
tests
docs

不要一个 20000 行巨大 commit。

每次 commit 前：

flutter analyze
相关 test

最终：

完整 test
完整 build

不要 force push。

==================================================
四十五、不要浪费 Codex 配额
==================================================

虽然这次任务很大，但不要无意义重复：

flutter pub get
全量 build
下载 SDK
重建 Flutter 工程
读同一个文件几十遍

优先：

先检查
制定执行顺序
小步修改
针对性测试
阶段完成后全量回归

不要在没有改 native 层时反复 build APK。

==================================================
四十六、不要停在计划
==================================================

非常重要：

不要只回复：

“我建议……”
“下一步可以……”
“需要确认……”

你拥有当前项目开发授权。

按安全边界自主执行。

除非遇到：

需要付款
需要用户密码
需要账号登录
需要删除用户私人文件
需要替换 Android 发布密钥
需要不可逆外部操作
需要购买代码签名证书

否则不要停下来询问。

如果一种技术路线失败：

看错误
查官方资料
查维护仓库
选择替代路线
继续。

==================================================
四十七、研究时的规则
==================================================

不懂就查。

优先级：

官方文档
官方源码
项目 release
维护中的 GitHub repo
issue
benchmark

不要凭记忆猜：

Flutter API
FFmpeg 参数
libvips API
Android Gradle
NDK
16 KB alignment
codec availability

如果项目 2 年没维护：
提高风险评级。

==================================================
四十八、文档
==================================================

更新：

README.md
docs/PRODUCT_SPEC.md
docs/ROADMAP.md
AGENTS.md
docs/DEPENDENCY_AUDIT.md

新增：

docs/MEDIA_ARCHITECTURE.md
docs/THIRD_PARTY_COMPONENTS.md
docs/MEDIA_FORMAT_SUPPORT.md
docs/PERFORMANCE_REPORT_v1.1.md
docs/ANDROID_MEDIA_BACKEND.md
docs/WINDOWS_MEDIA_BACKEND.md
docs/CACHE_ADAPTERS.md

所有状态必须：

Implemented
Tested
Experimental
Unsupported

不能混淆。

==================================================
四十九、README 最终不要吹牛
==================================================

不要写：

支持所有格式
无限大小
破解所有平台
完美兼容所有缓存

应该写：

支持列表
验证平台
已知限制
本地处理
没有人为固定大小上限
实际能力取决于设备和编解码器

==================================================
五十、最终验收
==================================================

最终只有满足下面条件才算任务完成：

A. 原图片功能
- 全部原测试通过
- Windows 正常
- Android 正常
- 不破坏 v1 数据

B. 大图
- 8K 能正常处理
- 50MP 能正常处理
- 100MP 在测试设备资源足够时验证
- 不再简单因 24MP 固定阈值拒绝
- 内存比旧架构有明确改善

C. 视频
- MP4
- MKV
- MOV
- WebM
至少基本转换/探测经过真实验证
- remux 正常
- transcode 正常

D. 音频
至少：
MP3
WAV
FLAC
AAC/M4A
Opus/OGG（实际 codec 支持为准）
经过真实测试

E. 缓存
至少完成并验证：
Bilibili 本地缓存 Adapter

音乐特殊格式：
NCM/QMC/KGM/KWM
逐个实现并验证实际可支持部分。

如果某格式因版本/技术/许可问题无法可靠实现：
明确标记 Unsupported / Experimental，
不要假装完成。

F. 大文件
- 不存在人为固定 GB 上限
- 视频/音频走 streaming
- 图片走低内存策略

G. 任务系统
- progress
- cancel
- retry
- failure isolation
- batch
- temp cleanup

H. CI
- analyze
- test
- Windows build
- Android build

I. Release regression
- Windows Release Build
- Android Release/compile validation
- 现有签名身份不被替换

J. 文档
全部与实际结果一致。

==================================================
五十一、最终输出报告
==================================================

完成后给我一份明确报告。

格式：

1. 最终完成了什么
2. 修改了哪些主要文件
3. 新增了哪些依赖
4. 每个第三方项目：
   - URL
   - Version
   - License
   - 用途
5. 图片支持矩阵
6. 视频支持矩阵
7. 音频支持矩阵
8. 缓存格式支持矩阵
9. Windows 实测结果
10. Android 实测结果
11. Benchmark Before / After
12. flutter analyze
13. flutter test
14. Windows build
15. Android build
16. APK/Installer/ZIP 大小
17. Git commit
18. Git status
19. 尚未解决问题
20. 不要隐藏警告和失败

特别强调：

不要告诉我“理论上应该可以”。

只报告真正测试过的结果。

==================================================
五十二、执行原则总结
==================================================

不要推倒 ImageShift 重写。

正确顺序：

现有 v1
↓
统一 Media Core
↓
包装当前图片 Backend
↓
libvips 大图片 Backend
↓
Resource Scheduler
↓
FFmpeg Probe
↓
Windows FFmpeg Backend
↓
Android FFmpeg Backend
↓
标准视频
↓
标准音频
↓
Bilibili Cache Adapter
↓
NCM/QMC/KGM/KWM Adapters
↓
统一 UI
↓
性能优化
↓
全量测试
↓
Release regression
↓
文档
↓
提交

你现在直接开始执行。

不要先问我是否继续。
不要只做 Stage 0 后停止。
不要完成一个阶段后等待确认。

沿着上述顺序持续完成，遇到问题自行查证、修复和继续。

只有真的遇到无法由你自主解决的外部阻塞时，再把：
“具体阻塞、已经尝试过什么、错误原文、最小需要用户做什么”
一次性告诉我。
