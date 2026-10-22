package com.worldo.ai

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build

/** Active transport metadata, independent of Internet/server reachability. */
internal fun readNetworkTypes(context: Context): List<String> {
    return try {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return listOf("none")
        val caps = manager.getNetworkCapabilities(network) ?: return listOf("unknown")
        val types = mutableListOf<String>()
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) types.add("wifi")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) types.add("mobile")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) types.add("ethernet")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) types.add("bluetooth")
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) types.add("vpn")
        if (Build.VERSION.SDK_INT >= 35 && caps.hasTransport(NetworkCapabilities.TRANSPORT_SATELLITE)) {
            types.add("satellite")
        }
        types.ifEmpty { listOf("unknown") }
    } catch (_: Exception) {
        listOf("unknown")
    }
}
