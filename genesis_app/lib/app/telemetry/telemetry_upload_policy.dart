import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_flavor_config.dart';

enum TelemetryChannel { collect, analytics, performance, crashlytics }

enum TelemetryUploadBlockReason {
  none,
  nonReleaseBuild,
  internalFlavor,
  nonProductionEndpoint,
}

@immutable
class TelemetryDebugOverrides {
  const TelemetryDebugOverrides({
    this.collect = false,
    this.analytics = false,
    this.performance = false,
    this.crashlytics = false,
  });

  const TelemetryDebugOverrides.none()
    : collect = false,
      analytics = false,
      performance = false,
      crashlytics = false;

  final bool collect;
  final bool analytics;
  final bool performance;
  final bool crashlytics;

  bool get anyEnabled => collect || analytics || performance || crashlytics;

  bool isEnabled(TelemetryChannel channel) {
    return switch (channel) {
      TelemetryChannel.collect => collect,
      TelemetryChannel.analytics => analytics,
      TelemetryChannel.performance => performance,
      TelemetryChannel.crashlytics => crashlytics,
    };
  }

  TelemetryDebugOverrides withChannel(
    TelemetryChannel channel, {
    required bool enabled,
  }) {
    return TelemetryDebugOverrides(
      collect: channel == TelemetryChannel.collect ? enabled : collect,
      analytics: channel == TelemetryChannel.analytics ? enabled : analytics,
      performance: channel == TelemetryChannel.performance
          ? enabled
          : performance,
      crashlytics: channel == TelemetryChannel.crashlytics
          ? enabled
          : crashlytics,
    );
  }
}

@immutable
class TelemetryUploadState {
  const TelemetryUploadState({
    required this.isReleaseBuild,
    required this.isProductionFlavor,
    required this.usesOfficialEndpoints,
    required this.automaticEnabled,
    required this.debugOverrides,
    required this.appEnvironment,
    required this.blockReason,
  });

  const TelemetryUploadState.disabled()
    : isReleaseBuild = false,
      isProductionFlavor = true,
      usesOfficialEndpoints = false,
      automaticEnabled = false,
      debugOverrides = const TelemetryDebugOverrides.none(),
      appEnvironment = 'test',
      blockReason = TelemetryUploadBlockReason.nonReleaseBuild;

  final bool isReleaseBuild;
  final bool isProductionFlavor;
  final bool usesOfficialEndpoints;
  final bool automaticEnabled;
  final TelemetryDebugOverrides debugOverrides;
  final String appEnvironment;
  final TelemetryUploadBlockReason blockReason;

  bool isChannelEnabled(TelemetryChannel channel) {
    return automaticEnabled || debugOverrides.isEnabled(channel);
  }

  bool get collectEnabled => isChannelEnabled(TelemetryChannel.collect);
  bool get analyticsEnabled => isChannelEnabled(TelemetryChannel.analytics);
  bool get performanceEnabled => isChannelEnabled(TelemetryChannel.performance);
  bool get crashlyticsEnabled => isChannelEnabled(TelemetryChannel.crashlytics);
}

TelemetryUploadState evaluateTelemetryUploadPolicy({
  required AppConfig config,
  required bool isReleaseBuild,
  required bool isProductionFlavor,
  required TelemetryDebugOverrides debugOverrides,
}) {
  final usesOfficialEndpoints = _usesOfficialEndpoints(config);
  final automaticEnabled =
      isReleaseBuild && isProductionFlavor && usesOfficialEndpoints;
  final blockReason = !isReleaseBuild
      ? TelemetryUploadBlockReason.nonReleaseBuild
      : !isProductionFlavor
      ? TelemetryUploadBlockReason.internalFlavor
      : !usesOfficialEndpoints
      ? TelemetryUploadBlockReason.nonProductionEndpoint
      : TelemetryUploadBlockReason.none;
  return TelemetryUploadState(
    isReleaseBuild: isReleaseBuild,
    isProductionFlavor: isProductionFlavor,
    usesOfficialEndpoints: usesOfficialEndpoints,
    automaticEnabled: automaticEnabled,
    debugOverrides: debugOverrides,
    // Every debug-forced channel must remain distinguishable from production.
    appEnvironment: automaticEnabled ? 'production' : 'test',
    blockReason: blockReason,
  );
}

abstract interface class TelemetryDebugOverrideStore {
  Future<TelemetryDebugOverrides> load();

  Future<void> save(TelemetryChannel channel, bool enabled);
}

class SharedPreferencesTelemetryDebugOverrideStore
    implements TelemetryDebugOverrideStore {
  const SharedPreferencesTelemetryDebugOverrideStore();

  static const String collectStorageKey =
      'developer_telemetry_collect_upload_override_v1';
  static const String analyticsStorageKey =
      'developer_telemetry_analytics_upload_override_v1';
  static const String performanceStorageKey =
      'developer_telemetry_performance_upload_override_v1';
  static const String crashlyticsStorageKey =
      'developer_telemetry_crashlytics_upload_override_v1';

  @override
  Future<TelemetryDebugOverrides> load() async {
    final preferences = await SharedPreferences.getInstance();
    return TelemetryDebugOverrides(
      collect: preferences.getBool(collectStorageKey) ?? false,
      analytics: preferences.getBool(analyticsStorageKey) ?? false,
      performance: preferences.getBool(performanceStorageKey) ?? false,
      crashlytics: preferences.getBool(crashlyticsStorageKey) ?? false,
    );
  }

  @override
  Future<void> save(TelemetryChannel channel, bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(storageKeyFor(channel), enabled);
    if (!saved) {
      throw StateError('Failed to persist telemetry upload override');
    }
  }

  static String storageKeyFor(TelemetryChannel channel) {
    return switch (channel) {
      TelemetryChannel.collect => collectStorageKey,
      TelemetryChannel.analytics => analyticsStorageKey,
      TelemetryChannel.performance => performanceStorageKey,
      TelemetryChannel.crashlytics => crashlyticsStorageKey,
    };
  }
}

class TelemetryUploadPolicy {
  const TelemetryUploadPolicy._();

  static final ValueNotifier<TelemetryUploadState> state =
      ValueNotifier<TelemetryUploadState>(
        const TelemetryUploadState.disabled(),
      );
  static TelemetryDebugOverrideStore _store =
      const SharedPreferencesTelemetryDebugOverrideStore();
  static AppConfig _config = const AppConfig();
  static TelemetryDebugOverrides _debugOverrides =
      const TelemetryDebugOverrides.none();

  static Future<TelemetryUploadState> initialize(AppConfig config) async {
    _config = config;
    try {
      _debugOverrides = await _store.load();
    } catch (error, stackTrace) {
      _debugOverrides = const TelemetryDebugOverrides.none();
      debugPrint('[Telemetry] debug override load failed: $error');
      debugPrint('[Telemetry] stacktrace:\n$stackTrace');
    }
    return _evaluate();
  }

  static TelemetryUploadState updateConfig(AppConfig config) {
    _config = config;
    return _evaluate();
  }

  static Future<TelemetryUploadState> setDebugOverrideEnabled(
    TelemetryChannel channel, {
    required bool enabled,
  }) async {
    await _store.save(channel, enabled);
    _debugOverrides = _debugOverrides.withChannel(channel, enabled: enabled);
    return _evaluate();
  }

  static TelemetryUploadState _evaluate() {
    final next = evaluateTelemetryUploadPolicy(
      config: _config,
      isReleaseBuild: kReleaseMode,
      isProductionFlavor: !AppFlavorConfig.currentIsInternal,
      debugOverrides: _debugOverrides,
    );
    state.value = next;
    return next;
  }

  @visibleForTesting
  static void setStoreForTesting(TelemetryDebugOverrideStore store) {
    _store = store;
  }

  @visibleForTesting
  static void setStateForTesting(TelemetryUploadState value) {
    state.value = value;
    _debugOverrides = value.debugOverrides;
  }

  @visibleForTesting
  static void resetForTesting() {
    _store = const SharedPreferencesTelemetryDebugOverrideStore();
    _config = const AppConfig();
    _debugOverrides = const TelemetryDebugOverrides.none();
    state.value = const TelemetryUploadState.disabled();
  }
}

bool _usesOfficialEndpoints(AppConfig config) {
  if (config.useMock == true) return false;
  return _isOfficialEndpoint(config.apiBaseUrl, scheme: 'https') &&
      _isOfficialEndpoint(config.gatewayApiBaseUrl, scheme: 'https') &&
      _isOfficialEndpoint(config.chatroomHttpBaseUrl, scheme: 'https') &&
      _isOfficialEndpoint(config.chatroomWsBaseUrl, scheme: 'wss');
}

bool _isOfficialEndpoint(String value, {required String scheme}) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.scheme.toLowerCase() == scheme &&
      uri.host.toLowerCase() == 'api.worldo.ai' &&
      !uri.hasPort;
}
