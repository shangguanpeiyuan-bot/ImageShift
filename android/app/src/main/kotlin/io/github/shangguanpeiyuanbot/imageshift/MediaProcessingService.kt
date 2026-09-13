package io.github.shangguanpeiyuanbot.imageshift

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import com.arthenica.ffmpegkit.FFmpegKit

/** Visible foreground work only; never restarts a conversion after process death. */
class MediaProcessingService : Service() {
    companion object {
        var onBatchCancel: (() -> Unit)? = null
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        val channel = "imageshift-local-media"
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(channel, "本地媒体处理", NotificationManager.IMPORTANCE_LOW))
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 1, Intent(this, MediaProcessingService::class.java).setAction("cancel"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = builder.setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("ImageShift 正在本地处理媒体")
            .setContentText("原文件保留，点击返回查看进度")
            .setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "取消", stop).build()).build()
        if (Build.VERSION.SDK_INT >= 29) {
            val type = if (Build.VERSION.SDK_INT >= 35) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING else ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            startForeground(701, notification, type)
        } else startForeground(701, notification)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "cancel") { onBatchCancel?.invoke(); FFmpegKit.cancel() }
        return START_NOT_STICKY
    }
    override fun onTimeout(startId: Int, fgsType: Int) { onBatchCancel?.invoke(); FFmpegKit.cancel(); stopSelf() }
    override fun onDestroy() { stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy() }
}
