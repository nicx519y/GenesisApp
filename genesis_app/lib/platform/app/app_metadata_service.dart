import '../channels/genesis_method_channels.dart';

class AppMetadataService {
  const AppMetadataService._();

  static Future<String> appName({String fallback = 'App'}) async {
    try {
      final value = await GenesisMethodChannels.device.invokeMethod<String>(
        GenesisMethodChannels.getAppName,
      );
      final name = value?.trim() ?? '';
      return name.isEmpty ? fallback : name;
    } catch (_) {
      return fallback;
    }
  }
}
