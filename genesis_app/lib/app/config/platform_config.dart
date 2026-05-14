import 'dart:io';

import 'app_config.dart';

abstract interface class PlatformConfig {
  String get platformHeader;
  String get apiBaseUrl;
  String get assetBaseUrl;
}

class DefaultPlatformConfig implements PlatformConfig {
  const DefaultPlatformConfig({this.appConfig = const AppConfig()});

  final AppConfig appConfig;

  @override
  String get platformHeader {
    if (Platform.isIOS) {
      const allowIosHeader = bool.fromEnvironment(
        'GENESIS_ALLOW_IOS_PLATFORM_HEADER',
        defaultValue: false,
      );
      return allowIosHeader ? 'ios' : 'android';
    }
    return 'android';
  }

  @override
  String get apiBaseUrl => appConfig.apiBaseUrl;

  @override
  String get assetBaseUrl => appConfig.assetBaseUrl;
}
