import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../platform/app/app_metadata_service.dart';

typedef AppVersionInfoLoader = Future<AppVersionInfo> Function();
typedef AppPlatformResolver = String? Function();

class AppRequestHeaderProvider {
  AppRequestHeaderProvider({
    AppVersionInfoLoader? appVersionLoader,
    AppPlatformResolver? platformResolver,
    String hmacKey = const String.fromEnvironment(
      'GENESIS_APP_ID_HMAC_KEY',
      defaultValue: 'genesis-app-id-v1',
    ),
  }) : _appVersionLoader = appVersionLoader ?? AppMetadataService.appVersion,
       _platformResolver = platformResolver ?? resolveCurrentPlatform,
       _hmacKey = hmacKey;

  final AppVersionInfoLoader _appVersionLoader;
  final AppPlatformResolver _platformResolver;
  final String _hmacKey;

  Future<Map<String, String>> headers() async {
    final versionInfo = await _appVersionLoader();
    final packageName = versionInfo.packageName.trim();
    final versionName = versionInfo.versionName.trim();
    final platform = _platformResolver()?.trim();

    return <String, String>{
      if (packageName.isNotEmpty) 'app-id': _encryptPackageName(packageName),
      if (versionName.isNotEmpty) 'app-version': versionName,
      if (platform != null && platform.isNotEmpty) 'app-platform': platform,
    };
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
}
