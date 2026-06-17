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

  static Future<AppVersionInfo> appVersion() async {
    try {
      final value = await GenesisMethodChannels.device
          .invokeMapMethod<String, Object?>(
            GenesisMethodChannels.getAppVersion,
          );
      return AppVersionInfo(
        versionName: '${value?['versionName'] ?? ''}'.trim(),
        versionCode: _intString(value?['versionCode']),
        packageName: '${value?['packageName'] ?? ''}'.trim(),
      );
    } catch (_) {
      return const AppVersionInfo();
    }
  }

  static String _intString(Object? value) {
    if (value is int) return '$value';
    if (value is num) return '${value.toInt()}';
    return '${value ?? ''}'.trim();
  }
}

class AppVersionInfo {
  const AppVersionInfo({
    this.versionName = '',
    this.versionCode = '',
    this.packageName = '',
  });

  final String versionName;
  final String versionCode;
  final String packageName;

  String get displayVersion {
    final name = versionName.trim();
    final code = versionCode.trim();
    if (name.isEmpty && code.isEmpty) return 'unknown';
    if (name.isEmpty) return code;
    if (code.isEmpty) return name;
    return '$name ($code)';
  }
}
