package com.worldo.ai

import android.app.Activity
import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Watches the picker task, including Home/Recents while Flutter is stopped. */
internal class ImagePickerLifecycleChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val methods = MethodChannel(messenger, "com.worldo.ai/image_picker_lifecycle")
    private val events = EventChannel(messenger, "com.worldo.ai/image_picker_lifecycle/events")
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var active = false
    private var backgrounded = false
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val reason = intent?.getStringExtra("reason")
            if (intent?.action == Intent.ACTION_SCREEN_OFF ||
                intent?.action == Intent.ACTION_CLOSE_SYSTEM_DIALOGS && reason in listOf("homekey", "recentapps")) {
                background()
            }
        }
    }
    private val watch = object : Runnable {
        override fun run() {
            if (!active) return
            val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            var taskVisible: Boolean? = null
            if (Build.VERSION.SDK_INT >= 32) {
                taskVisible = try {
                    val tasks = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    tasks.appTasks.firstOrNull { it.taskInfo.taskId == activity.taskId }?.taskInfo?.isVisible ?: false
                } catch (_: Exception) { false }
            }
            if (!power.isInteractive || keyguard.isKeyguardLocked || taskVisible == false) background()
            if (active && !backgrounded) handler.postDelayed(this, 250)
        }
    }
    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
                sink = eventSink
                if (active && backgrounded) sink?.success("background")
            }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "begin" -> result.success(begin())
                "end" -> { end(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun begin(): Boolean {
        end()
        backgrounded = false
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            else activity.registerReceiver(receiver, filter)
            receiverRegistered = true
            active = true
            handler.postDelayed(watch, 250)
            return true
        } catch (_: Exception) { end(); return false }
    }
    private fun background() {
        if (!active || backgrounded) return
        backgrounded = true
        sink?.success("background")
    }
    private fun end() {
        active = false
        handler.removeCallbacks(watch)
        if (receiverRegistered) {
            try { activity.unregisterReceiver(receiver) } catch (_: Exception) { }
            receiverRegistered = false
        }
    }
    fun dispose() {
        end()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
    }
}
