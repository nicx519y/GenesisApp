package com.genesis.ai.genesis_flutter_android

import android.content.Context
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.genesis.ai/device"
    private val uidKey = "uid"
    private val prefsName = "genesis"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidId" -> {
                    val androidId =
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(androidId ?: "")
                }
                "setUid" -> {
                    val uid = call.argument<String>("uid") ?: ""
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    prefs.edit().putString(uidKey, uid).apply()
                    result.success(null)
                }
                "getUid" -> {
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    result.success(prefs.getString(uidKey, "") ?: "")
                }
                "clearUid" -> {
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    prefs.edit().remove(uidKey).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
