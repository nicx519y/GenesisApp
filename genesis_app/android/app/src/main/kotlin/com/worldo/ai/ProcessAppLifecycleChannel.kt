package com.worldo.ai

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque

/**
 * Reports process-level visibility changes to Dart.
 *
 * ProcessLifecycleOwner delays ON_STOP briefly so Activity recreation and
 * in-process Activity transitions do not look like app backgrounding.
 */
internal object ProcessAppLifecycleChannel : DefaultLifecycleObserver {
    private const val CHANNEL_NAME = "com.worldo.ai/app_lifecycle"
    private const val BACKGROUND_EVENT = "background"
    private const val FOREGROUND_EVENT = "foreground"
    private const val MAX_PENDING_EVENTS = 8

    private enum class Visibility {
        UNKNOWN,
        FOREGROUND,
        BACKGROUND,
    }

    private val pendingEvents = ArrayDeque<String>()
    private var activeBinding: Binding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var visibility = Visibility.UNKNOWN
    private var backgroundEventEmitted = false
    private var observing = false

    fun bind(messenger: BinaryMessenger): Binding {
        if (!observing) {
            observing = true
            ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        }
        activeBinding?.detach()
        eventSink = null
        return Binding(messenger).also { binding ->
            activeBinding = binding
            binding.attach()
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        when (visibility) {
            Visibility.UNKNOWN -> {
                // Establish the cold-start baseline without reporting a resume.
                visibility = Visibility.FOREGROUND
            }
            Visibility.BACKGROUND -> {
                visibility = Visibility.FOREGROUND
                if (backgroundEventEmitted) {
                    backgroundEventEmitted = false
                    emit(FOREGROUND_EVENT)
                }
            }
            Visibility.FOREGROUND -> Unit
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        when (visibility) {
            Visibility.UNKNOWN -> {
                // A process can be initialized without ever becoming visible.
                // Treat that as a baseline, not a real foreground-to-background
                // transition.
                visibility = Visibility.BACKGROUND
            }
            Visibility.FOREGROUND -> {
                visibility = Visibility.BACKGROUND
                backgroundEventEmitted = true
                emit(BACKGROUND_EVENT)
            }
            Visibility.BACKGROUND -> Unit
        }
    }

    private fun onListen(binding: Binding, events: EventChannel.EventSink?) {
        if (activeBinding !== binding) return
        eventSink = events
        if (events == null) return
        while (pendingEvents.isNotEmpty()) {
            events.success(pendingEvents.removeFirst())
        }
    }

    private fun onCancel(binding: Binding) {
        if (activeBinding !== binding) return
        eventSink = null
    }

    private fun unbind(binding: Binding) {
        binding.detach()
        if (activeBinding !== binding) return
        activeBinding = null
        eventSink = null
    }

    private fun emit(event: String) {
        val sink = eventSink
        if (sink == null) {
            if (pendingEvents.size >= MAX_PENDING_EVENTS) {
                pendingEvents.removeFirst()
            }
            pendingEvents.addLast(event)
        } else {
            sink.success(event)
        }
    }

    internal class Binding internal constructor(
        messenger: BinaryMessenger,
    ) {
        private val channel = EventChannel(messenger, CHANNEL_NAME)
        private val streamHandler = object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ProcessAppLifecycleChannel.onListen(this@Binding, events)
            }

            override fun onCancel(arguments: Any?) {
                ProcessAppLifecycleChannel.onCancel(this@Binding)
            }
        }
        private var attached = false

        fun dispose() {
            ProcessAppLifecycleChannel.unbind(this)
        }

        internal fun attach() {
            if (attached) return
            channel.setStreamHandler(streamHandler)
            attached = true
        }

        internal fun detach() {
            if (!attached) return
            channel.setStreamHandler(null)
            attached = false
        }
    }
}
