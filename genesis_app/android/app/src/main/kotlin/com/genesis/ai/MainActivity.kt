package com.genesis.ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channel = "com.genesis.ai/device"
    private val discussImagePickerChannel = "com.genesis.ai/discuss_image_picker"
    private val discussImagePickerRequestCode = 43021
    private val uidKey = "uid"
    private val authTokenKey = "auth_token"
    private val userInfoKey = "user_info"
    private val prefsName = "genesis"
    private var pendingDiscussImagePickerResult: MethodChannel.Result? = null
    private var pendingDiscussImagePickerLimit = 0

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            discussImagePickerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImages" -> {
                    val limit = maxOf(1, call.argument<Int>("limit") ?: 6)
                    pickDiscussImages(limit, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pickDiscussImages(limit: Int, result: MethodChannel.Result) {
        if (pendingDiscussImagePickerResult != null) {
            result.error("picker_active", "An image picker is already active.", null)
            return
        }

        pendingDiscussImagePickerResult = result
        pendingDiscussImagePickerLimit = limit

        val request = PickVisualMediaRequest.Builder()
            .setMediaType(ActivityResultContracts.PickVisualMedia.ImageOnly)
            .build()
        val intent = if (limit <= 1) {
            ActivityResultContracts.PickVisualMedia().createIntent(this, request)
        } else {
            ActivityResultContracts.PickMultipleVisualMedia(limit).createIntent(this, request)
        }

        try {
            startActivityForResult(intent, discussImagePickerRequestCode)
        } catch (error: Exception) {
            pendingDiscussImagePickerResult = null
            pendingDiscussImagePickerLimit = 0
            result.error("picker_unavailable", error.message ?: "Cannot open image picker.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != discussImagePickerRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingDiscussImagePickerResult ?: return
        val limit = pendingDiscussImagePickerLimit
        pendingDiscussImagePickerResult = null
        pendingDiscussImagePickerLimit = 0

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = selectedImageUris(data).take(limit)
        if (uris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }

        val paths = uris.mapIndexedNotNull { index, uri ->
            runCatching { saveDiscussPickedImage(uri, index) }.getOrNull()
        }
        if (paths.isEmpty()) {
            result.error("image_copy_failed", "Selected images could not be copied.", null)
            return
        }

        result.success(paths)
    }

    private fun selectedImageUris(data: Intent): List<Uri> {
        val uris = mutableListOf<Uri>()
        val clipData = data.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index)?.uri?.let { uris.add(it) }
            }
        } else {
            data.data?.let { uris.add(it) }
        }
        return uris
    }

    private fun saveDiscussPickedImage(uri: Uri, index: Int): String {
        val mimeType = contentResolver.getType(uri) ?: "image/jpeg"
        val extension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(mimeType)
            ?.takeIf { it.isNotBlank() }
            ?: "jpg"
        val dir = File(cacheDir, "discuss_image_picker")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "discuss_${System.currentTimeMillis()}_$index.$extension")

        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot open selected image." }
            FileOutputStream(file).use { output ->
                input.copyTo(output)
            }
        }

        return file.absolutePath
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
