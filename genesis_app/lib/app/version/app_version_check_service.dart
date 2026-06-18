import 'package:flutter/foundation.dart';

import '../../network/app_request_headers.dart';
import '../../network/genesis_api.dart';
import '../../network/models/app_version_check.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../platform/device/device_id_service.dart';
import '../../platform/session/user_session_store.dart';
import '../config/app_config.dart';

typedef VersionCheckInfoLoader = Future<AppVersionInfo> Function();
typedef VersionCheckPlatformResolver = String? Function();

abstract interface class AppVersionCheckService {
  Future<AppVersionCheckResult> check();
}

class AppVersionCheckResult {
  const AppVersionCheckResult._({
    required this.response,
    required this.skipped,
    required this.failed,
    this.error,
  });

  factory AppVersionCheckResult.fromResponse(AppVersionCheckResponse response) {
    return AppVersionCheckResult._(
      response: response,
      skipped: false,
      failed: false,
    );
  }

  const AppVersionCheckResult.noUpgrade()
    : this._(
        response: AppVersionCheckResponse.none,
        skipped: false,
        failed: false,
      );

  const AppVersionCheckResult.skipped()
    : this._(response: null, skipped: true, failed: false);

  const AppVersionCheckResult.failed(Object error)
    : this._(response: null, skipped: false, failed: true, error: error);

  final AppVersionCheckResponse? response;
  final bool skipped;
  final bool failed;
  final Object? error;

  bool get isForceUpgrade => response?.shouldForceUpgrade == true;
}

class GenesisAppVersionCheckService implements AppVersionCheckService {
  const GenesisAppVersionCheckService({
    required AppConfig config,
    required GenesisApi api,
    required DeviceIdService deviceIdService,
    required UserSessionStore sessionStore,
    VersionCheckInfoLoader? appVersionLoader,
    VersionCheckPlatformResolver? platformResolver,
  }) : _config = config,
       _api = api,
       _deviceIdService = deviceIdService,
       _sessionStore = sessionStore,
       _appVersionLoader = appVersionLoader ?? AppMetadataService.appVersion,
       _platformResolver =
           platformResolver ?? AppRequestHeaderProvider.resolveCurrentPlatform;

  final AppConfig _config;
  final GenesisApi _api;
  final DeviceIdService _deviceIdService;
  final UserSessionStore _sessionStore;
  final VersionCheckInfoLoader _appVersionLoader;
  final VersionCheckPlatformResolver _platformResolver;

  @override
  Future<AppVersionCheckResult> check() async {
    try {
      final platform = (_platformResolver() ?? '').trim();
      if (platform.isEmpty) return const AppVersionCheckResult.skipped();

      final version = await _appVersionLoader();
      final versionCode = int.tryParse(version.versionCode.trim());
      if (versionCode == null) return const AppVersionCheckResult.skipped();

      final response = await _api.v1.app.versionCheck(
        appId: _config.appId.trim().isEmpty ? 'aitown' : _config.appId.trim(),
        platform: platform,
        channel: _config.appChannel.trim().isEmpty
            ? 'default'
            : _config.appChannel.trim(),
        versionName: version.versionName.trim(),
        versionCode: versionCode,
        deviceId: await _safeRead(_deviceIdService.getDeviceId),
        uid: await _safeRead(_sessionStore.readUid),
      );
      return AppVersionCheckResult.fromResponse(response);
    } catch (error) {
      if (kDebugMode) debugPrint('[AppVersionCheck] failed: $error');
      return AppVersionCheckResult.failed(error);
    }
  }

  Future<String?> _safeRead(Future<String?> Function() read) async {
    try {
      final value = (await read())?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
