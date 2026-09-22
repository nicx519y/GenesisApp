package com.worldo.ai

import io.flutter.plugin.common.BinaryMessenger

class DebugScreenTranslationChannel private constructor() {
    companion object {
        fun bind(messenger: BinaryMessenger): DebugScreenTranslationChannel {
            return DebugScreenTranslationChannel()
        }
    }

    fun dispose() = Unit
}
