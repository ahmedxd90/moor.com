package co.saki.saki_chat_flutter

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "co.saki.saki_chat_flutter/room_background"
        private const val EXTRA_ROOM_ID = "roomId"
        private const val EXTRA_ROOM_NAME = "roomName"
    }

    private var roomChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        roomChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        roomChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val roomId = call.argument<String>("roomId")
                    val roomName = call.argument<String>("roomName") ?: "غرفة Saki"
                    val roomNumber = call.argument<String>("roomNumber") ?: ""
                    val coverUrl = call.argument<String>("coverUrl")
                    RoomAudioService.start(this, roomId, roomName, roomNumber, coverUrl)
                    result.success(true)
                }
                "showBubble" -> {
                    if (!canDrawOverlays()) {
                        result.success(false)
                    } else {
                        val roomId = call.argument<String>("roomId")
                        val roomName = call.argument<String>("roomName") ?: "غرفة Saki"
                        val roomNumber = call.argument<String>("roomNumber") ?: ""
                        val coverUrl = call.argument<String>("coverUrl")
                        RoomAudioService.showBubble(this, roomId, roomName, roomNumber, coverUrl)
                        result.success(true)
                    }
                }
                "hideBubble" -> {
                    RoomAudioService.hideBubble(this)
                    result.success(null)
                }
                "stop" -> {
                    RoomAudioService.stop(this)
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(canDrawOverlays())
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !canDrawOverlays()) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        dispatchOpenRoomIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchOpenRoomIntent(intent)
    }

    private fun dispatchOpenRoomIntent(intent: Intent?) {
        if (intent?.action != RoomAudioService.ACTION_OPEN_ROOM) return
        roomChannel?.invokeMethod(
            "openRoom",
            mapOf(
                EXTRA_ROOM_ID to intent.getStringExtra(EXTRA_ROOM_ID),
                EXTRA_ROOM_NAME to intent.getStringExtra(EXTRA_ROOM_NAME),
            ),
        )
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
}
