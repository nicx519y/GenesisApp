package com.worldo.ai

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Emits changes to the process's active network; the request itself proves reachability. */
internal class NetworkAvailabilityChannel(
    context: Context,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val channel = EventChannel(messenger, "com.worldo.ai/network_availability")
    private var sink: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var lastAvailable: Boolean? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stopObserving()
        sink = events
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = publishCurrentState()
            override fun onLost(network: Network) = publishCurrentState()
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = publishCurrentState()
        }
        callback = networkCallback
        try {
            connectivity.registerDefaultNetworkCallback(networkCallback)
            publishCurrentState()
        } catch (error: Exception) {
            callback = null
            events?.error("network_monitor_unavailable", error.message, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        stopObserving()
    }

    fun dispose() {
        stopObserving()
        channel.setStreamHandler(null)
    }

    private fun stopObserving() {
        callback?.let {
            try {
                connectivity.unregisterNetworkCallback(it)
            } catch (_: Exception) {
                // The callback may already have been removed with its engine.
            }
        }
        callback = null
        sink = null
        lastAvailable = null
    }

    private fun publishCurrentState() {
        mainHandler.post {
            if (sink == null || callback == null) return@post
            val active = connectivity.activeNetwork
            val capabilities = active?.let(connectivity::getNetworkCapabilities)
            val available = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
            if (lastAvailable != available) {
                lastAvailable = available
                sink?.success(available)
            }
        }
    }
}
