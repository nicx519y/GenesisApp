package com.worldo.ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.os.UserManager
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.webkit.MimeTypeMap
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val channel = "com.worldo.ai/device"
    private val discussImagePickerChannel = "com.worldo.ai/discuss_image_picker"
    private val keyboardAnimationChannel = "com.worldo.ai/keyboard_animation"
    private val discussImagePickerRequestCode = 43021
    private val googleSignInRequestCode = 43022
    private val uidKey = "uid"
    private val authTokenKey = "auth_token"
    private val userInfoKey = "user_info"
    private val generatedDeviceIdKey = "generated_device_id"
    private val prefsName = "genesis"
    private val gatewayKeyAlias = "genesis_gateway_device_key_v1"
    private val normalizedDiscussImageMaxDimension = 4096
    private val normalizedDiscussImageMaxPixels = 16_000_000L
    private val legacyNormalizedDiscussImageMaxPixels = 8_000_000L
    private var pendingDiscussImagePickerResult: MethodChannel.Result? = null
    private var pendingDiscussImagePickerLimit = 0
    private var pendingDiscussImagePickerNormalizeForUpload = false
    private var pendingGoogleSignInResult: MethodChannel.Result? = null
    private var keyboardAnimationEventSink: EventChannel.EventSink? = null
    private var latestKeyboardAnimationEvent: Map<String, Any>? = null
    private var keyboardAnimationGeneration = 0
    private var lastImeInsetPx = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        WindowCompat.enableEdgeToEdge(window)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        configureKeyboardAnimationChannel(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidId", "getDeviceId" -> {
                    Thread {
                        val deviceId = resolveAndroidDeviceId()
                        runOnUiThread { result.success(deviceId) }
                    }.start()
                }
                "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "getAndroidDeviceIdDiagnostics" -> {
                    Thread {
                        val diagnostics = resolveAndroidDeviceIdDiagnostics()
                        runOnUiThread { result.success(diagnostics) }
                    }.start()
                }
                "getDeviceIdentitySnapshot" -> {
                    Thread {
                        val snapshot = resolveAndroidDeviceIdentitySnapshot()
                        runOnUiThread { result.success(snapshot) }
                    }.start()
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
                "getAppName" -> {
                    val label = applicationInfo.loadLabel(packageManager)?.toString() ?: ""
                    result.success(label)
                }
                "getAppVersion" -> {
                    result.success(buildAppVersion())
                }
                "getSystemUserAgent" -> {
                    result.success("Android ${Build.VERSION.RELEASE}")
                }
                "getTimeZone" -> {
                    result.success(TimeZone.getDefault().id)
                }
                "openExternalUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    result.success(openExternalUrl(url))
                }
                "gatewayPublicKey" -> {
                    Thread {
                        try {
                            val publicKey = ensureGatewayPublicKey()
                            runOnUiThread { result.success(base64Url(publicKey.encoded)) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("gateway_public_key_failed", error.message, null)
                            }
                        }
                    }.start()
                }
                "signGatewayCanonical" -> {
                    val canonical = call.argument<String>("canonical") ?: ""
                    Thread {
                        try {
                            val signature = signGatewayCanonical(canonical)
                            runOnUiThread { result.success(base64Url(signature)) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("gateway_signature_failed", error.message, null)
                            }
                        }
                    }.start()
                }
                "resetGatewayKey" -> {
                    Thread {
                        try {
                            resetGatewayKey()
                            runOnUiThread { result.success(null) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error("gateway_key_reset_failed", error.message, null)
                            }
                        }
                    }.start()
                }
                "signInGoogleLegacy" -> {
                    val serverClientId = call.argument<String>("serverClientId") ?: ""
                    signInGoogleLegacy(serverClientId, result)
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
                    val normalizeForUpload =
                        call.argument<Boolean>("normalizeForUpload") ?: false
                    pickDiscussImages(limit, normalizeForUpload, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun configureKeyboardAnimationChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            keyboardAnimationChannel,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                keyboardAnimationEventSink = events
                lastImeInsetPx = ViewCompat.getRootWindowInsets(window.decorView)
                    ?.getInsets(WindowInsetsCompat.Type.ime())
                    ?.bottom ?: 0
                latestKeyboardAnimationEvent?.let { events?.success(it) }
            }

            override fun onCancel(arguments: Any?) {
                keyboardAnimationEventSink = null
            }
        })

        ViewCompat.setWindowInsetsAnimationCallback(
            window.decorView,
            object : WindowInsetsAnimationCompat.Callback(
                WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE,
            ) {
                override fun onStart(
                    animation: WindowInsetsAnimationCompat,
                    bounds: WindowInsetsAnimationCompat.BoundsCompat,
                ): WindowInsetsAnimationCompat.BoundsCompat {
                    if (animation.typeMask and WindowInsetsCompat.Type.ime() == 0) {
                        return bounds
                    }
                    val density = resources.displayMetrics.density.coerceAtLeast(0.01f)
                    val startInsetPx = lastImeInsetPx
                    val lowerInsetPx = bounds.lowerBound.bottom
                    val upperInsetPx = bounds.upperBound.bottom
                    val endInsetPx = if (
                        kotlin.math.abs(startInsetPx - lowerInsetPx) <=
                            kotlin.math.abs(startInsetPx - upperInsetPx)
                    ) {
                        upperInsetPx
                    } else {
                        lowerInsetPx
                    }
                    val phase = when {
                        startInsetPx > 0 && endInsetPx > 0 -> "changing"
                        endInsetPx > startInsetPx -> "opening"
                        else -> "closing"
                    }
                    keyboardAnimationGeneration += 1
                    val event = mapOf<String, Any>(
                        "generation" to keyboardAnimationGeneration,
                        "phase" to phase,
                        "startInset" to startInsetPx / density,
                        "endInset" to endInsetPx / density,
                        "durationMillis" to animation.durationMillis,
                    )
                    latestKeyboardAnimationEvent = event
                    keyboardAnimationEventSink?.success(event)
                    return bounds
                }

                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: MutableList<WindowInsetsAnimationCompat>,
                ): WindowInsetsCompat {
                    lastImeInsetPx = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
                    return insets
                }
            },
        )
    }

    private fun resolveAndroidDeviceId(): String {
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        if (isValidDeviceIdentifier(androidId)) return androidId.trim()

        val advertisingId = readAdvertisingId()
        if (isValidDeviceIdentifier(advertisingId)) return advertisingId!!.trim()

        return generatedAndroidDeviceId()
    }

    private fun resolveAndroidDeviceIdDiagnostics(): Map<String, String> {
        val androidId =
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)?.trim() ?: ""
        val advertisingId = readAdvertisingId()?.trim() ?: ""
        val deviceId = when {
            isValidDeviceIdentifier(androidId) -> androidId
            isValidDeviceIdentifier(advertisingId) -> advertisingId
            else -> generatedAndroidDeviceId()
        }

        return mapOf(
            "android_id" to androidId,
            "aaid" to advertisingId,
            "device_id" to deviceId,
        )
    }

    private fun resolveAndroidDeviceIdentitySnapshot(): Map<String, Any?> {
        val androidId =
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)?.trim() ?: ""
        val advertisingId = readAdvertisingId()?.trim() ?: ""
        val source: String
        val deviceId: String
        when {
            isValidDeviceIdentifier(androidId) -> {
                source = "android_id"
                deviceId = androidId
            }
            isValidDeviceIdentifier(advertisingId) -> {
                source = "aaid"
                deviceId = advertisingId
            }
            else -> {
                source = "generated_uuid"
                deviceId = generatedAndroidDeviceId()
            }
        }

        return mapOf(
            "platform" to "android",
            "device_id" to deviceId,
            "device_id_source" to source,
            "signing_cert_sha256" to signingCertificateSha256(),
            "android_user_serial" to androidUserSerial(),
            "android_user_type" to androidUserType(),
            "gateway_public_key_hash" to runCatching {
                sha256Hex(ensureGatewayPublicKey().encoded)
            }.getOrDefault(""),
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "os_build_fingerprint_hash" to sha256Hex(
                Build.FINGERPRINT.toByteArray(Charsets.UTF_8),
            ),
        )
    }

    private fun signingCertificateSha256(): String {
        return runCatching {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(
                packageName,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    PackageManager.GET_SIGNING_CERTIFICATES
                } else {
                    PackageManager.GET_SIGNATURES
                },
            )
            @Suppress("DEPRECATION")
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.signingInfo?.apkContentsSigners.orEmpty()
            } else {
                info.signatures.orEmpty()
            }
            val certificate = signatures.firstOrNull()?.toByteArray() ?: return@runCatching ""
            sha256Hex(certificate)
        }.getOrDefault("")
    }

    private fun androidUserSerial(): Long? {
        return runCatching {
            val userManager = getSystemService(UserManager::class.java)
            userManager.getSerialNumberForUser(Process.myUserHandle()).takeIf { it >= 0 }
        }.getOrNull()
    }

    private fun androidUserType(): String {
        return runCatching {
            val userManager = getSystemService(UserManager::class.java)
            when {
                userManager.isManagedProfile -> "managed_profile"
                Process.myUid() / 100000 == 0 -> "system"
                else -> "secondary_or_guest"
            }
        }.getOrDefault("unknown")
    }

    private fun sha256Hex(bytes: ByteArray): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }

    private fun readAdvertisingId(): String? {
        return try {
            AdvertisingIdClient.getAdvertisingIdInfo(applicationContext).id
        } catch (_: Exception) {
            null
        }
    }

    private fun generatedAndroidDeviceId(): String {
        synchronized(this) {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val existing = prefs.getString(generatedDeviceIdKey, "") ?: ""
            if (isValidDeviceIdentifier(existing)) return existing.trim()

            val generated = UUID.randomUUID().toString()
            prefs.edit().putString(generatedDeviceIdKey, generated).apply()
            return generated
        }
    }

    private fun isValidDeviceIdentifier(value: String?): Boolean {
        val normalized = value?.trim()?.lowercase(Locale.US) ?: return false
        if (normalized.isEmpty()) return false
        if (normalized == "9774d56d682e549c") return false

        val compact = normalized.replace("-", "")
        return compact.isNotEmpty() && compact.any { it != '0' }
    }

    private fun buildAppVersion(): Map<String, Any> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "versionName" to (info.versionName ?: ""),
            "versionCode" to versionCode,
            "packageName" to packageName,
        )
    }

    private fun ensureGatewayPublicKey(): PublicKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        val existing = keyStore.getCertificate(gatewayKeyAlias)?.publicKey
        if (existing != null) return existing

        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore",
        )
        val spec = KeyGenParameterSpec.Builder(
            gatewayKeyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .build()
        generator.initialize(spec)
        return generator.generateKeyPair().public
    }

    private fun gatewayPrivateKey(): PrivateKey {
        ensureGatewayPublicKey()
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        return keyStore.getKey(gatewayKeyAlias, null) as PrivateKey
    }

    private fun signGatewayCanonical(canonical: String): ByteArray {
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(gatewayPrivateKey())
        signer.update(canonical.toByteArray(Charsets.UTF_8))
        return signer.sign()
    }

    private fun resetGatewayKey() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)
        keyStore.deleteEntry(gatewayKeyAlias)
    }

    private fun base64Url(bytes: ByteArray): String {
        return Base64.encodeToString(
            bytes,
            Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP,
        )
    }

    private fun openExternalUrl(url: String): Boolean {
        if (url.isBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun signInGoogleLegacy(serverClientId: String, result: MethodChannel.Result) {
        if (pendingGoogleSignInResult != null) {
            result.error("google_sign_in_active", "Google sign-in is already active.", null)
            return
        }
        if (serverClientId.isBlank()) {
            result.error("missing_server_client_id", "Missing Google server client id.", null)
            return
        }

        pendingGoogleSignInResult = result
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestEmail()
            .requestProfile()
            .requestIdToken(serverClientId)
            .build()
        val client = GoogleSignIn.getClient(this, options)
        try {
            startActivityForResult(client.signInIntent, googleSignInRequestCode)
        } catch (error: Exception) {
            pendingGoogleSignInResult = null
            result.error("google_sign_in_unavailable", error.message ?: "Cannot open Google sign-in.", null)
        }
    }

    private fun pickDiscussImages(
        limit: Int,
        normalizeForUpload: Boolean,
        result: MethodChannel.Result,
    ) {
        if (pendingDiscussImagePickerResult != null) {
            result.error("picker_active", "An image picker is already active.", null)
            return
        }

        pendingDiscussImagePickerResult = result
        pendingDiscussImagePickerLimit = limit
        pendingDiscussImagePickerNormalizeForUpload = normalizeForUpload

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
            pendingDiscussImagePickerNormalizeForUpload = false
            result.error("picker_unavailable", error.message ?: "Cannot open image picker.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == googleSignInRequestCode) {
            handleGoogleSignInResult(resultCode, data)
            return
        }

        if (requestCode != discussImagePickerRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingDiscussImagePickerResult ?: return
        val limit = pendingDiscussImagePickerLimit
        val normalizeForUpload = pendingDiscussImagePickerNormalizeForUpload
        pendingDiscussImagePickerResult = null
        pendingDiscussImagePickerLimit = 0
        pendingDiscussImagePickerNormalizeForUpload = false

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = selectedImageUris(data).take(limit)
        if (uris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }

        Thread {
            val paths = uris.mapIndexedNotNull { index, uri ->
                runCatching {
                    saveDiscussPickedImage(uri, index, normalizeForUpload)
                }.getOrNull()
            }
            runOnUiThread {
                if (paths.isEmpty()) {
                    result.error(
                        "image_copy_failed",
                        "Selected images could not be processed.",
                        null,
                    )
                } else {
                    result.success(paths)
                }
            }
        }.start()
    }

    private fun handleGoogleSignInResult(resultCode: Int, data: Intent?) {
        val result = pendingGoogleSignInResult ?: return
        pendingGoogleSignInResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.error("google_sign_in_cancelled", "Google sign-in cancelled.", null)
            return
        }

        try {
            val account = GoogleSignIn.getSignedInAccountFromIntent(data)
                .getResult(ApiException::class.java)
            val idToken = account.idToken.orEmpty()
            if (idToken.isBlank()) {
                result.error("empty_google_id_token", "Google did not return an idToken.", null)
                return
            }
            result.success(
                mapOf(
                    "idToken" to idToken,
                    "email" to account.email.orEmpty(),
                    "displayName" to account.displayName.orEmpty(),
                    "photoUrl" to (account.photoUrl?.toString() ?: ""),
                )
            )
        } catch (error: ApiException) {
            result.error("google_sign_in_failed", "Google sign-in failed: ${error.statusCode}", null)
        } catch (error: Exception) {
            result.error("google_sign_in_failed", error.message ?: "Google sign-in failed.", null)
        }
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

    private fun saveDiscussPickedImage(
        uri: Uri,
        index: Int,
        normalizeForUpload: Boolean,
    ): String {
        val mimeType = contentResolver.getType(uri) ?: "image/jpeg"
        if (normalizeForUpload) {
            require(!isGifImage(uri, mimeType)) { "GIF images are not supported." }
            return saveNormalizedDiscussImage(uri, index)
        }
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

    private fun saveNormalizedDiscussImage(uri: Uri, index: Int): String {
        val decoded = decodeDiscussImage(uri)
        try {
            val hasTransparency = bitmapHasTransparentPixels(decoded)
            val extension = if (hasTransparency) "png" else "jpg"
            val format = if (hasTransparency) {
                Bitmap.CompressFormat.PNG
            } else {
                Bitmap.CompressFormat.JPEG
            }
            val quality = if (hasTransparency) 100 else 90
            val dir = File(cacheDir, "discuss_image_picker")
            if (!dir.exists()) dir.mkdirs()
            val file = File(
                dir,
                "discuss_${System.currentTimeMillis()}_$index.$extension",
            )
            FileOutputStream(file).use { output ->
                check(decoded.compress(format, quality, output)) {
                    "Selected image could not be encoded."
                }
            }
            return file.absolutePath
        } finally {
            decoded.recycle()
        }
    }

    private fun decodeDiscussImage(uri: Uri): Bitmap {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(contentResolver, uri)
            return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val (targetWidth, targetHeight) = normalizedDiscussImageSize(
                    info.size.width,
                    info.size.height,
                )
                if (targetWidth != info.size.width || targetHeight != info.size.height) {
                    decoder.setTargetSize(targetWidth, targetHeight)
                }
            }
        }

        val bounds = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot open selected image." }
            BitmapFactory.decodeStream(input, null, bounds)
        }
        require(bounds.outWidth > 0 && bounds.outHeight > 0) {
            "Selected image dimensions could not be read."
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = normalizedDiscussImageSampleSize(
                bounds.outWidth,
                bounds.outHeight,
                legacyNormalizedDiscussImageMaxPixels,
            )
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Cannot open selected image." }
            requireNotNull(BitmapFactory.decodeStream(input, null, options)) {
                "Selected image could not be decoded."
            }
        }
        var resized = bitmap
        try {
            resized = resizeDiscussImageIfNeeded(
                bitmap,
                legacyNormalizedDiscussImageMaxPixels,
            )
            val orientation = runCatching {
                contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "Cannot open selected image metadata." }
                    ExifInterface(input).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL,
                    )
                }
            }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
            return applyExifOrientation(resized, orientation)
        } catch (error: Throwable) {
            if (!resized.isRecycled) resized.recycle()
            if (resized !== bitmap && !bitmap.isRecycled) bitmap.recycle()
            throw error
        }
    }

    private fun normalizedDiscussImageSize(
        sourceWidth: Int,
        sourceHeight: Int,
        maxPixels: Long = normalizedDiscussImageMaxPixels,
    ): Pair<Int, Int> {
        require(sourceWidth > 0 && sourceHeight > 0) {
            "Selected image dimensions are invalid."
        }
        val width = sourceWidth.toDouble()
        val height = sourceHeight.toDouble()
        val dimensionScale = normalizedDiscussImageMaxDimension / maxOf(width, height)
        val pixelScale = sqrt(maxPixels / (width * height))
        val scale = minOf(1.0, dimensionScale, pixelScale)
        return Pair(
            maxOf(1, floor(width * scale).toInt()),
            maxOf(1, floor(height * scale).toInt()),
        )
    }

    private fun normalizedDiscussImageSampleSize(
        sourceWidth: Int,
        sourceHeight: Int,
        maxPixels: Long,
    ): Int {
        var sampleSize = 1
        while (sampleSize <= Int.MAX_VALUE / 2) {
            val sampledWidth = ceil(sourceWidth.toDouble() / sampleSize).toLong()
            val sampledHeight = ceil(sourceHeight.toDouble() / sampleSize).toLong()
            if (
                sampledWidth <= normalizedDiscussImageMaxDimension &&
                sampledHeight <= normalizedDiscussImageMaxDimension &&
                sampledWidth * sampledHeight <= maxPixels
            ) {
                break
            }
            sampleSize *= 2
        }
        return sampleSize
    }

    private fun resizeDiscussImageIfNeeded(
        bitmap: Bitmap,
        maxPixels: Long,
    ): Bitmap {
        val (targetWidth, targetHeight) = normalizedDiscussImageSize(
            bitmap.width,
            bitmap.height,
            maxPixels,
        )
        if (targetWidth == bitmap.width && targetHeight == bitmap.height) {
            return bitmap
        }
        return try {
            Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true).also {
                if (it !== bitmap) bitmap.recycle()
            }
        } catch (error: Throwable) {
            bitmap.recycle()
            throw error
        }
    }

    private fun applyExifOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return bitmap
        }
        val oriented = Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
        if (oriented !== bitmap) bitmap.recycle()
        return oriented
    }

    private fun bitmapHasTransparentPixels(bitmap: Bitmap): Boolean {
        if (!bitmap.hasAlpha()) return false
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            if (row.any { pixel -> Color.alpha(pixel) < 255 }) return true
        }
        return false
    }

    private fun isGifImage(uri: Uri, mimeType: String): Boolean {
        if (mimeType.equals("image/gif", ignoreCase = true)) return true
        return runCatching {
            contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input)
                val header = ByteArray(6)
                if (input.read(header) != header.size) return@use false
                val signature = header.toString(Charsets.US_ASCII)
                signature == "GIF87a" || signature == "GIF89a"
            }
        }.getOrDefault(false)
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
