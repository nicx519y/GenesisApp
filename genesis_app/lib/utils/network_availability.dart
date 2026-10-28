import 'dart:io';

/// Checks local interfaces, not whether the chat server is reachable.
/// A platform probe failure stays unknown and allows the request to proceed.
Future<bool> hasDeviceNetworkConnection() async {
  try {
    final interfaces = await NetworkInterface.list(includeLoopback: false);
    return interfaces.any(
      (interface) => interface.addresses.any(
        (address) => !address.isLoopback && !address.isLinkLocal,
      ),
    );
  } catch (_) {
    return true;
  }
}
