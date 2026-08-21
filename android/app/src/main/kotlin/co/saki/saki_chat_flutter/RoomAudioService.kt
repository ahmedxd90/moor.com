package co.saki.saki_chat_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.net.URL

class RoomAudioService : Service() {
    companion object {
        const val ACTION_START = "co.saki.saki_chat_flutter.room.START"
        const val ACTION_SHOW_BUBBLE = "co.saki.saki_chat_flutter.room.SHOW_BUBBLE"
        const val ACTION_STOP = "co.saki.saki_chat_flutter.room.STOP"
        const val ACTION_HIDE_BUBBLE = "co.saki.saki_chat_flutter.room.HIDE_BUBBLE"
        const val ACTION_OPEN_ROOM = "co.saki.saki_chat_flutter.room.OPEN"

        private const val CHANNEL_ID = "saki_room_audio"
        private const val NOTIFICATION_ID = 2468
        private const val EXTRA_ROOM_ID = "roomId"
        private const val EXTRA_ROOM_NAME = "roomName"
        private const val EXTRA_ROOM_NUMBER = "roomNumber"
        private const val EXTRA_COVER_URL = "coverUrl"

        fun start(context: Context, roomId: String?, roomName: String, roomNumber: String, coverUrl: String?) {
            val intent = Intent(context, RoomAudioService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ROOM_ID, roomId)
                putExtra(EXTRA_ROOM_NAME, roomName)
                putExtra(EXTRA_ROOM_NUMBER, roomNumber)
                putExtra(EXTRA_COVER_URL, coverUrl)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun showBubble(context: Context, roomId: String?, roomName: String, roomNumber: String, coverUrl: String?) {
            val intent = Intent(context, RoomAudioService::class.java).apply {
                action = ACTION_SHOW_BUBBLE
                putExtra(EXTRA_ROOM_ID, roomId)
                putExtra(EXTRA_ROOM_NAME, roomName)
                putExtra(EXTRA_ROOM_NUMBER, roomNumber)
                putExtra(EXTRA_COVER_URL, coverUrl)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun hideBubble(context: Context) {
            val intent = Intent(context, RoomAudioService::class.java).apply {
                action = ACTION_HIDE_BUBBLE
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, RoomAudioService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var bubble: ImageView? = null
    private var roomId: String? = null
    private var roomName = "غرفة Saki"
    private var roomNumber = ""
    private var coverUrl: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            roomId = intent.getStringExtra(EXTRA_ROOM_ID) ?: roomId
            roomName = intent.getStringExtra(EXTRA_ROOM_NAME) ?: roomName
            roomNumber = intent.getStringExtra(EXTRA_ROOM_NUMBER) ?: roomNumber
            coverUrl = intent.getStringExtra(EXTRA_COVER_URL)
            when (intent.action) {
                ACTION_SHOW_BUBBLE -> {
                    startForegroundSafely()
                    showBubble()
                }
                ACTION_HIDE_BUBBLE -> {
                    startForegroundSafely()
                    hideBubble()
                }
                ACTION_STOP -> stopSelf()
                else -> startForegroundSafely()
            }
        } else {
            startForegroundSafely()
        }
        return START_STICKY
    }

    private fun startForegroundSafely() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_OPEN_ROOM
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentFlags(),
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(roomName)
            .setContentText("الغرفة الصوتية متصلة${if (roomNumber.isNotEmpty()) " • $roomNumber" else ""}")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setColor(Color.rgb(245, 130, 32))
            .build()
    }

    private fun pendingIntentFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "الغرف الصوتية",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "إبقاء جلسة الغرفة الصوتية متصلة في الخلفية"
                setShowBadge(false)
            },
        )
    }

    private fun hideBubble() {
        handler.post { removeBubble() }
    }

    private fun showBubble() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return
        handler.post {
            removeBubble()
            val image = ImageView(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.rgb(245, 130, 32))
                    setStroke(dp(2), Color.WHITE)
                }
                setPadding(dp(4), dp(4), dp(4), dp(4))
                scaleType = ImageView.ScaleType.CENTER_CROP
                contentDescription = "العودة إلى $roomName"
                setOnClickListener {
                    val intent = Intent(this@RoomAudioService, MainActivity::class.java).apply {
                        action = ACTION_OPEN_ROOM
                        putExtra(EXTRA_ROOM_ID, roomId)
                        putExtra(EXTRA_ROOM_NAME, roomName)
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    startActivity(intent)
                    removeBubble()
                }
            }
            bubble = image
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val params = WindowManager.LayoutParams(
                dp(68),
                dp(68),
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                x = dp(12)
                y = 0
            }
            try {
                windowManager?.addView(image, params)
                loadCoverAsync(image, coverUrl)
            } catch (_: Exception) {
                bubble = null
            }
        }
    }

    private fun loadCoverAsync(image: ImageView, url: String?) {
        if (url.isNullOrBlank()) return
        Thread {
            try {
                val bitmap = BitmapFactory.decodeStream(URL(url).openStream())
                handler.post {
                    if (bubble === image && bitmap != null) image.setImageBitmap(bitmap)
                }
            } catch (_: Exception) {
                // The orange bubble remains available when the cover cannot load.
            }
        }.start()
    }

    private fun removeBubble() {
        val current = bubble ?: return
        try {
            windowManager?.removeView(current)
        } catch (_: Exception) {
        }
        bubble = null
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        removeBubble()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
