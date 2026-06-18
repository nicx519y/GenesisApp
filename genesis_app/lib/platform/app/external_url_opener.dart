import '../channels/genesis_method_channels.dart';

abstract interface class ExternalUrlOpener {
  Future<bool> open(String url);
}

class NativeExternalUrlOpener implements ExternalUrlOpener {
  const NativeExternalUrlOpener();

  @override
  Future<bool> open(String url) async {
    final value = url.trim();
    if (value.isEmpty) return false;
    try {
      return await GenesisMethodChannels.device.invokeMethod<bool>(
            GenesisMethodChannels.openExternalUrl,
            {'url': value},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
