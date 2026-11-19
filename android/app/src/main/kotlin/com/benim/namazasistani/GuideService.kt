package com.benim.namazasistani

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Namaz rehberi çalışırken uygulama sürecini canlı tutan ön plan hizmeti.
 * Ekran kararsa da zamanlayıcı, titreşim ve (eklendiğinde) ses akışı sürer.
 * Bildirimde her zaman bir "Durdur" düğmesi bulunur.
 */
class GuideService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var title = "Namaz rehberi"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                running = false
                onStopRequested?.invoke()
                stopSelfSafely()
                return START_NOT_STICKY
            }
            else -> {
                title = intent?.getStringExtra(EXTRA_TITLE) ?: title
                ensureChannel()
                val n = build("Başlıyor…")
                if (Build.VERSION.SDK_INT >= 29) {
                    startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIF_ID, n)
                }
                if (wakeLock == null) {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "namaz:guide").apply {
                        setReferenceCounted(false)
                        acquire(60 * 60 * 1000L) // en fazla 1 saat
                    }
                }
            }
        }
        return START_NOT_STICKY
    }

    fun updateText(text: String) {
        getSystemService(NotificationManager::class.java).notify(NOTIF_ID, build(text))
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Namaz rehberi", NotificationManager.IMPORTANCE_LOW).apply {
                        description = "Rehber çalışırken görünür; buradan durdurabilirsiniz."
                        setSound(null, null)
                        enableVibration(false)
                    }
                )
            }
        }
    }

    private fun build(text: String): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, GuideService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        return b.setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_guide)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openIntent)
            .addAction(
                Notification.Action.Builder(
                    Icon.createWithResource(this, R.drawable.ic_stat_guide), "DURDUR", stopIntent
                ).build()
            )
            .build()
    }

    private fun stopSelfSafely() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        instance = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "guide"
        private const val NOTIF_ID = 7
        private const val ACTION_STOP = "stop"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"

        @Volatile
        var running = false
            private set

        var onStopRequested: (() -> Unit)? = null

        @Volatile
        private var instance: GuideService? = null

        fun start(ctx: Context, title: String) {
            running = true
            val i = Intent(ctx, GuideService::class.java).putExtra(EXTRA_TITLE, title)
            if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
        }

        fun update(ctx: Context, text: String) {
            if (!running) return
            instance?.updateText(text)
        }

        fun stop(ctx: Context) {
            if (!running) return
            running = false
            ctx.stopService(Intent(ctx, GuideService::class.java))
        }
    }
}
