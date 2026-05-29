package com.genesis.ai

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channel = "com.genesis.ai/device"
    private val uidKey = "uid"
    private val authTokenKey = "auth_token"
    private val userInfoKey = "user_info"
    private val prefsName = "genesis"

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidId", "getDeviceId" -> {
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
                "setAuthToken" -> {
                    val token = call.argument<String>("token") ?: ""
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    prefs.edit().putString(authTokenKey, token).apply()
                    result.success(null)
                }
                "getAuthToken" -> {
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    result.success(prefs.getString(authTokenKey, "") ?: "")
                }
                "setUserInfo" -> {
                    val userInfo = call.argument<String>("userInfo") ?: ""
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    prefs.edit().putString(userInfoKey, userInfo).apply()
                    result.success(null)
                }
                "getUserInfo" -> {
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    result.success(prefs.getString(userInfoKey, "") ?: "")
                }
                "getSignInDiagnostics" -> {
                    result.success(buildSignInDiagnostics())
                }
                "clearUid" -> {
                    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    prefs.edit().remove(uidKey).remove(authTokenKey).remove(userInfoKey).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildSignInDiagnostics(): Map<String, Any> {
        val certBytesList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            info.signingInfo?.apkContentsSigners?.map { it.toByteArray() }.orEmpty()
        } else {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            @Suppress("DEPRECATION")
            info.signatures?.map { it.toByteArray() }.orEmpty()
        }
        val sha1 = certBytesList.map { digest(it, "SHA-1") }.distinct()
        val sha256 = certBytesList.map { digest(it, "SHA-256") }.distinct()
        return mapOf(
            "packageName" to packageName,
            "sha1" to sha1,
            "sha256" to sha256,
            "defaultWebClientId" to readStringResource("default_web_client_id"),
            "googleAppId" to readStringResource("google_app_id"),
            "firebaseProjectId" to readStringResource("project_id"),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun readStringResource(name: String): String {
        val id = resources.getIdentifier(name, "string", packageName)
        if (id == 0) return ""
        return runCatching { getString(id) }.getOrDefault("")
    }

    private fun digest(bytes: ByteArray, algorithm: String): String {
        val hash = MessageDigest.getInstance(algorithm).digest(bytes)
        return hash.joinToString(":") { b -> "%02X".format(b) }
    }
}
