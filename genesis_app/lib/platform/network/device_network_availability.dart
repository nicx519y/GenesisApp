import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../channels/genesis_method_channels.dart';

/// Reads a fresh system network snapshot before inspecting chat connectivity.
/// A missing/failed probe cannot establish that the device has a network.
/// Availability is independent of whether the chat server can be reached.
Future<bool> hasDeviceNetworkConnection() async {
  try {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return await GenesisMethodChannels.device
              .invokeMethod<bool>(GenesisMethodChannels.getNetworkAvailability)
              .timeout(const Duration(seconds: 2)) ??
          false;
    }
    final interfaces = await NetworkInterface.list(includeLoopback: false);
    return interfaces.any(
      (interface) => interface.addresses.any(
        (address) => !address.isLoopback && !address.isLinkLocal,
      ),
    );
  } catch (_) {
    return false;
  }
}
