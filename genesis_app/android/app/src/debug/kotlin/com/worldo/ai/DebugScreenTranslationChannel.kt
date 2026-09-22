package com.worldo.ai

import android.graphics.BitmapFactory
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class DebugScreenTranslationChannel private constructor(
    messenger: BinaryMessenger,
) {
    companion object {
        private const val CHANNEL_NAME = "com.worldo.ai/debug_screen_translation"
        private const val MAX_LINES = 60
        private val ENGLISH_PATTERN = Regex("[A-Za-z]")

        fun bind(messenger: BinaryMessenger): DebugScreenTranslationChannel {
            return DebugScreenTranslationChannel(messenger)
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val translator: Translator = Translation.getClient(
        TranslatorOptions.Builder()
            .setSourceLanguage(TranslateLanguage.ENGLISH)
            .setTargetLanguage(TranslateLanguage.CHINESE)
            .build(),
    )
    private val downloadConditions = DownloadConditions.Builder().build()
    private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) {
                result.error("disposed", "Screen translation has been disposed.", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "prepare" -> prepare(result)
                "translateScreen" -> {
                    val bytes = call.argument<ByteArray>("pngBytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("invalid_image", "The screen capture is empty.", null)
                    } else {
                        translateScreen(bytes, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        recognizer.close()
        translator.close()
    }

    private fun prepare(result: MethodChannel.Result) {
        translator.downloadModelIfNeeded(downloadConditions)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { error ->
                result.error(
                    "model_download_failed",
                    error.message ?: "Could not download the English-Chinese model.",
                    null,
                )
            }
    }

    private fun translateScreen(bytes: ByteArray, result: MethodChannel.Result) {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        if (bitmap == null) {
            result.error("invalid_image", "Could not decode the screen capture.", null)
            return
        }
        val image = InputImage.fromBitmap(bitmap, 0)
        translator.downloadModelIfNeeded(downloadConditions)
            .continueWithTask { recognizer.process(image) }
            .addOnSuccessListener { visionText ->
                bitmap.recycle()
                translateRecognizedLines(visionText, result)
            }
            .addOnFailureListener { error ->
                bitmap.recycle()
                result.error(
                    "recognition_failed",
                    error.message ?: "Could not recognize text on this screen.",
                    null,
                )
            }
    }

    private fun translateRecognizedLines(
        visionText: Text,
        result: MethodChannel.Result,
    ) {
        val lines = visionText.textBlocks
            .flatMap { block -> block.lines }
            .filter { line ->
                line.boundingBox != null && ENGLISH_PATTERN.containsMatchIn(line.text)
            }
            .take(MAX_LINES)

        if (lines.isEmpty()) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        val translationTasks = lines.map { line -> translator.translate(line.text) }
        Tasks.whenAllSuccess<String>(translationTasks)
            .addOnSuccessListener { translations ->
                val translatedLines = lines.mapIndexedNotNull { index, line ->
                    val bounds = line.boundingBox ?: return@mapIndexedNotNull null
                    val translated = translations.getOrNull(index)?.trim().orEmpty()
                    if (translated.isEmpty()) return@mapIndexedNotNull null
                    mapOf(
                        "text" to translated,
                        "left" to bounds.left,
                        "top" to bounds.top,
                        "right" to bounds.right,
                        "bottom" to bounds.bottom,
                    )
                }
                result.success(translatedLines)
            }
            .addOnFailureListener { error ->
                result.error(
                    "translation_failed",
                    error.message ?: "Could not translate recognized text.",
                    null,
                )
            }
    }
}
