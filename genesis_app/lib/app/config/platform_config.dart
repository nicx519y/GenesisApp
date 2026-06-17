import 'app_config.dart';

abstract interface class PlatformConfig {
  String get apiBaseUrl;
  String get assetBaseUrl;
}

class DefaultPlatformConfig implements PlatformConfig {
  const DefaultPlatformConfig({this.appConfig = const AppConfig()});

  final AppConfig appConfig;

  @override
  String get apiBaseUrl => appConfig.apiBaseUrl;

  @override
  String get assetBaseUrl => appConfig.assetBaseUrl;
}
