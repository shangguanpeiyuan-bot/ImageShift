package io.github.shangguanpeiyuanbot.imageshift

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.arthenica.ffmpegkit.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

/** No shell, remote URLs, or system executable lookup. */
class AndroidMediaBridge(context: Context, messenger: BinaryMessenger) {
    private val context = context.applicationContext
    private var batchActive = false
    private val main = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<String, Session>()
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    private var sink: EventChannel.EventSink? = null
    init {
        EventChannel(messenger, "io.github.shangguanpeiyuanbot.imageshift/media-progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
                override fun onCancel(arguments: Any?) { sink = null }
            })
        MethodChannel(messenger, "io.github.shangguanpeiyuanbot.imageshift/media")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "beginBatch" -> {
                            check(!batchActive)
                            MediaProcessingService.onBatchCancel = {
                                main.post { sink?.success(mapOf("batchCancelled" to true)) }
                            }
                            startService()
                            batchActive = true
                            result.success(null)
                        }
                        "endBatch" -> {
                            batchActive = false
                            MediaProcessingService.onBatchCancel = null
                            context.stopService(Intent(context, MediaProcessingService::class.java))
                            result.success(null)
                        }
                        "cancel" -> {
                            val id = call.argument<String>("id")!!
                            cancelled.add(id)
                            sessions[id]?.cancel()
                            result.success(null)
                        }
                        "execute" -> {
                            if (Build.SUPPORTED_ABIS.none { it == "arm64-v8a" || it == "x86_64" }) {
                                result.error("ABI", "当前架构没有媒体组件", null)
                            } else {
                                FFmpegKitConfig.setLogRedirectionStrategy(LogRedirectionStrategy.NEVER_PRINT_LOGS)
                                FFmpegKitConfig.setSessionHistorySize(1)
                                execute(call.argument<String>("id")!!,
                                    call.argument<String>("program")!!,
                                    call.argument<List<String>>("arguments")!!.toTypedArray(), result)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Throwable) {
                    result.error("MEDIA_NATIVE", "无法启动本地媒体组件", null)
                }
            }
    }
    private fun startService() {
        val intent = Intent(context, MediaProcessingService::class.java)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
    }
    private fun execute(id: String, program: String, args: Array<String>, result: MethodChannel.Result) {
        require(program == "ffmpeg" || program == "ffprobe")
        val ownService = !batchActive && program == "ffmpeg" && args.contains("-i")
        if (ownService) startService()
        fun complete(session: Session) {
            // FFmpegKit's own MediaInformation path uses AV_LOG_STDERR for
            // ffprobe JSON. Decoder diagnostics are separate log levels.
            // Drain on this native callback thread, never block Android main.
            val logs = session.getAllLogs(1000)
            val output = if (program == "ffprobe") logs.filter { it.level == Level.AV_LOG_STDERR }
                .joinToString("") { it.message } else logs.joinToString("") { it.message }
            val diagnostics = if (program == "ffprobe") logs.filter { it.level != Level.AV_LOG_STDERR }
                .joinToString("") { it.message } else ""
            main.post {
                sessions.remove(id)
                cancelled.remove(id)
                if (ownService) context.stopService(Intent(context, MediaProcessingService::class.java))
                result.success(mapOf("exitCode" to (session.returnCode?.value ?: -1),
                    "cancelled" to ReturnCode.isCancel(session.returnCode),
                    "output" to output.take(4 * 1024 * 1024),
                    "diagnostics" to diagnostics.take(16 * 1024)))
            }
        }
        try {
        val session: Session = if (program == "ffprobe") {
            FFprobeKit.executeWithArgumentsAsync(args, { complete(it) }, { })
        } else {
            FFmpegKit.executeWithArgumentsAsync(args, { complete(it) }, { }, { statistics ->
                main.post { sink?.success(mapOf("id" to id, "timeUs" to (statistics.time * 1000).toLong())) }
            })
        }
        sessions[id] = session
        if (cancelled.contains(id)) session.cancel()
        } catch (error: Throwable) {
            if (ownService) context.stopService(Intent(context, MediaProcessingService::class.java))
            throw error
        }
    }
}
