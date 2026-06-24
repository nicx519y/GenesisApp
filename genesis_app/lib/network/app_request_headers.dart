import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../platform/app/app_metadata_service.dart';
import '../platform/channels/genesis_method_channels.dart';

typedef AppVersionInfoLoader = Future<AppVersionInfo> Function();
typedef AppPlatformResolver = String? Function();
typedef SystemUserAgentLoader = Future<String> Function();

const Set<String> legacyAppPublicHeaderNames = {
  'app-platform',
  'device-id',
  'app-id',
  'app-version',
};

Map<String, String> stripLegacyAppPublicHeaders(Map<String, String> headers) {
  return <String, String>{
    for (final entry in headers.entries)
      if (!legacyAppPublicHeaderNames.contains(entry.key.toLowerCase()))
        entry.key: entry.value,
  };
}

class AppRequestHeaderProvider {
  AppRequestHeaderProvider({
    AppVersionInfoLoader? appVersionLoader,
    AppPlatformResolver? platformResolver,
    SystemUserAgentLoader? systemUserAgentLoader,
    String hmacKey = const String.fromEnvironment(
      'GENESIS_APP_ID_HMAC_KEY',
      defaultValue: 'genesis-app-id-v1',
    ),
  }) : _appVersionLoader = appVersionLoader ?? AppMetadataService.appVersion,
       _platformResolver = platformResolver ?? resolveCurrentPlatform,
       _systemUserAgentLoader = systemUserAgentLoader ?? _loadSystemUserAgent,
       _hmacKey = hmacKey;

  final AppVersionInfoLoader _appVersionLoader;
  final AppPlatformResolver _platformResolver;
  final SystemUserAgentLoader _systemUserAgentLoader;
  final String _hmacKey;

  Future<Map<String, String>> headers() async {
    final userAgent = (await _systemUserAgentLoader()).trim();
    return <String, String>{if (userAgent.isNotEmpty) 'user-agent': userAgent};
  }

  Future<AppRequestIdentity> gatewayIdentity() async {
    final versionInfo = await _appVersionLoader();
    final packageName = versionInfo.packageName.trim();
    final versionName = versionInfo.versionName.trim();
    final platform = _platformResolver()?.trim() ?? '';

    return AppRequestIdentity(
      appId: packageName.isEmpty ? '' : _encryptPackageName(packageName),
      platform: platform,
      appVersion: versionName,
    );
  }

  String _encryptPackageName(String packageName) {
    final hmac = Hmac(sha256, utf8.encode(_hmacKey));
    return hmac.convert(utf8.encode(packageName)).toString();
  }

  static String? resolveCurrentPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  static Future<String> _loadSystemUserAgent() async {
    try {
      final value = await GenesisMethodChannels.device.invokeMethod<String>(
        GenesisMethodChannels.getSystemUserAgent,
      );
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    } catch (_) {
      // Fall through to the Dart VM system version for tests and unsupported hosts.
    }
    return _fallbackSystemUserAgent();
  }

  static String _fallbackSystemUserAgent() {
    final system = io.Platform.operatingSystem.trim();
    final version = io.Platform.operatingSystemVersion.trim();
    return [system, version].where((part) => part.isNotEmpty).join(' ');
  }
}

class AppRequestIdentity {
  const AppRequestIdentity({
    required this.appId,
    required this.platform,
    required this.appVersion,
  });

  final String appId;
  final String platform;
  final String appVersion;
}
