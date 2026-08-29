import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../platform/app/app_metadata_service.dart';
import '../../platform/device/device_id_service.dart';
import '../config/app_config.dart';
import '../debug_page_tracker.dart';
import 'collect_telemetry.dart';
import 'firebase_crash_reporting.dart';
import 'telemetry_upload_policy.dart';

export 'collect_telemetry.dart';

enum GenesisTelemetryLevel { debug, info, warning, error, fatal }

class GenesisTelemetryContext {
  const GenesisTelemetryContext({
    this.appVersion = 'unknown',
    this.appBuild = '',
    this.deviceId = '',
    this.platform = '',
    this.environment = 'production',
    this.currentPage = '',
  });

  final String appVersion;
  final String appBuild;
  final String deviceId;
  final String platform;
  final String environment;
  final String currentPage;

  GenesisTelemetryContext copyWith({
    String? appVersion,
    String? appBuild,
    String? deviceId,
    String? platform,
    String? environment,
    String? currentPage,
  }) {
    return GenesisTelemetryContext(
      appVersion: appVersion ?? this.appVersion,
      appBuild: appBuild ?? this.appBuild,
      deviceId: deviceId ?? this.deviceId,
      platform: platform ?? this.platform,
      environment: environment ?? this.environment,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'app_version': appVersion,
      if (appBuild.isNotEmpty) 'app_build': appBuild,
      if (deviceId.isNotEmpty) 'device_id': deviceId,
      if (platform.isNotEmpty) 'platform': platform,
      'environment': environment,
      if (currentPage.isNotEmpty) 'current_page': currentPage,
    };
  }
}

class GenesisTelemetryEvent {
  const GenesisTelemetryEvent({
    required this.name,
    required this.category,
    required this.data,
    required this.context,
    this.level = GenesisTelemetryLevel.info,
    this.capture = true,
    this.collectPayload,
    this.includeCollectIdentityHeaders = true,
  });

  final String name;
  final String category;
  final Map<String, Object?> data;
  final GenesisTelemetryContext context;
  final GenesisTelemetryLevel level;
  final bool capture;
  final Map<String, Object?>? collectPayload;
  final bool includeCollectIdentityHeaders;

  Map<String, Object?> get fullData => <String, Object?>{
    ...context.toMap(),
    ...data,
  };
}

abstract interface class GenesisTelemetrySink {
  Future<void> record(GenesisTelemetryEvent event);
  Future<void> setContext(GenesisTelemetryContext context);
  Future<void> setUserId(String? uid);
  Future<void> captureException(Object error, StackTrace stackTrace);
}

class NoopGenesisTelemetrySink implements GenesisTelemetrySink {
  const NoopGenesisTelemetrySink();

  @override
  Future<void> record(GenesisTelemetryEvent event) async {}

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}

  @override
  Future<void> setUserId(String? uid) async {}

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}
}

class GenesisTelemetry {
  GenesisTelemetry._();

  static GenesisTelemetrySink _sink = const NoopGenesisTelemetrySink();
  static CollectTelemetryUploader _collectUploader = CollectTelemetryUploader(
    store: SqfliteCollectEventStore(),
  );
  static GenesisTelemetryContext _context = const GenesisTelemetryContext();
  static bool _enabled = true;
  static bool _sinkOverriddenForTesting = false;
  static bool _collectPrepared = false;
  static bool _collectStartRequested = false;

  @visibleForTesting
  static GenesisTelemetryContext get contextForTesting => _context;

  static bool get hasCompleteContextMetadata =>
      _hasKnownAppVersion(_context.appVersion) &&
      _hasKnownDeviceId(_context.deviceId);

  static CollectTelemetryHealth get collectHealth => _collectUploader.health;

  @visibleForTesting
  static void setSinkForTesting(GenesisTelemetrySink sink) {
    _sink = sink;
    _enabled = true;
    _sinkOverriddenForTesting = true;
  }

  @visibleForTesting
  static void setCollectUploaderForTesting(
    CollectTelemetryUploader uploader, {
    bool prepared = true,
  }) {
    _collectUploader.dispose();
    _collectUploader = uploader;
    _collectPrepared = prepared;
  }

  @visibleForTesting
  static void resetForTesting() {
    _collectUploader.dispose();
    _sink = const NoopGenesisTelemetrySink();
    _collectUploader = CollectTelemetryUploader(
      store: MemoryCollectEventStore(),
    );
    _context = const GenesisTelemetryContext();
    _enabled = true;
    _sinkOverriddenForTesting = false;
    _collectPrepared = false;
    _collectStartRequested = false;
  }

  static void prepareCollect(AppConfig config) {
    if (_collectPrepared) return;
    reconfigureCollect(config);
  }

  static void reconfigureCollect(AppConfig config) {
    _collectPrepared = true;
    final endpoint = config.collectEndpoint.trim();
    final enabled =
        TelemetryUploadPolicy.state.value.collectEnabled &&
        config.collectEnabled &&
        config.useMock != true &&
        endpoint.isNotEmpty;
    CollectTelemetryClient? client;
    if (enabled) {
      try {
        client = SdkCollectTelemetryClient(
          endpoint: endpoint,
          debugProxy: config.debugProxy,
        );
      } catch (_) {
        client = null;
      }
    }
    _collectUploader.configure(
      enabled: enabled && client != null,
      client: client,
    );
    _collectUploader.setAppEnvironment(
      TelemetryUploadPolicy.state.value.appEnvironment,
    );
    if (_collectStartRequested) _collectUploader.start();
  }

  static Future<void> initialize({
    required AppConfig config,
    required DeviceIdService deviceIdService,
    AppVersionInfo? appVersion,
    Future<AppVersionInfo> Function()? appVersionReader,
    Duration appVersionTimeout = const Duration(seconds: 1),
    Duration deviceIdTimeout = const Duration(seconds: 2),
    bool trackingEnabled = true,
  }) async {
    if (!_collectPrepared && !_sinkOverriddenForTesting) {
      prepareCollect(config);
    }
    final version =
        appVersion ??
        await _safeAppVersion(
          appVersionReader ?? AppMetadataService.appVersion,
          appVersionTimeout,
        );
    final deviceId = await _safeDeviceId(deviceIdService, deviceIdTimeout);
    _context = _context.copyWith(
      appVersion: version.versionName.trim().isEmpty
          ? 'unknown'
          : version.versionName.trim(),
      appBuild: version.versionCode.trim(),
      deviceId: deviceId,
      platform: defaultTargetPlatform.name,
      environment: config.effectiveApiEnvironment.isEmpty
          ? 'production'
          : config.effectiveApiEnvironment,
      currentPage: genesisCurrentPageClassName.value,
    );
    if (!_sinkOverriddenForTesting) {
      _sink = const NoopGenesisTelemetrySink();
    }
    _enabled = trackingEnabled;
    await _sink.setContext(_context);
    _collectUploader.setContext(
      CollectUploadContext(
        platform: _context.platform,
        appVersion: _context.appVersion,
        appEnvironment: TelemetryUploadPolicy.state.value.appEnvironment,
        deviceId: _context.deviceId,
      ),
    );
  }

  static Future<void> refreshContextMetadata({
    required DeviceIdService deviceIdService,
    Future<AppVersionInfo> Function()? appVersionReader,
    Duration appVersionTimeout = const Duration(seconds: 1),
    Duration deviceIdTimeout = const Duration(seconds: 2),
  }) async {
    var appVersion = _context.appVersion;
    var appBuild = _context.appBuild;
    if (!_hasKnownAppVersion(appVersion)) {
      final version = await _safeAppVersion(
        appVersionReader ?? AppMetadataService.appVersion,
        appVersionTimeout,
      );
      final versionName = version.versionName.trim();
      if (versionName.isNotEmpty) {
        appVersion = versionName;
        appBuild = version.versionCode.trim();
      }
    }

    var deviceId = _context.deviceId;
    if (!_hasKnownDeviceId(deviceId)) {
      deviceId = await _safeDeviceId(deviceIdService, deviceIdTimeout);
    }

    _context = _context.copyWith(
      appVersion: appVersion,
      appBuild: appBuild,
      deviceId: deviceId,
    );
    await _sink.setContext(_context);
    _collectUploader.updateMetadataContext(
      platform: _context.platform,
      appVersion: _context.appVersion,
      deviceId: _context.deviceId,
    );
  }

  static void startCollectUploader() {
    _collectStartRequested = true;
    _collectUploader.start();
  }

  static void handleAppResumed() {
    _collectUploader.handleAppResumed();
  }

  static void handleAppBackgrounded() {
    _collectUploader.handleAppBackgrounded();
  }

  @visibleForTesting
  static Future<void> waitForCollectWritesForTesting() {
    return _collectUploader.waitForPendingWrites();
  }

  static void updateCurrentPage(String pageClassName) {
    final page = pageClassName.trim();
    if (page.isEmpty || _context.currentPage == page) return;
    _context = _context.copyWith(currentPage: page);
    unawaited(_sink.setContext(_context));
  }

  static void event(
    String name, {
    String category = 'genesis',
    Map<String, Object?> data = const <String, Object?>{},
    GenesisTelemetryLevel level = GenesisTelemetryLevel.info,
    bool capture = true,
    Map<String, Object?>? collectPayload,
    bool includeCollectIdentityHeaders = true,
  }) {
    if (!_enabled) return;
    final event = GenesisTelemetryEvent(
      name: name,
      category: category,
      data: <String, Object?>{'event_name': name, ...data},
      context: _context,
      level: level,
      capture: capture,
      collectPayload: collectPayload,
      includeCollectIdentityHeaders: includeCollectIdentityHeaders,
    );
    if (capture && collectPayload != null && collectPayload.isNotEmpty) {
      unawaited(
        _collectUploader.enqueuePayload(
          collectPayload,
          includeIdentityHeaders: includeCollectIdentityHeaders,
        ),
      );
    }
    unawaited(_sink.record(event));
  }

  static void click({
    required String actionId,
    required String component,
    required bool enabled,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    event(
      'ui_click',
      category: 'ui.click',
      data: <String, Object?>{
        'action_id': actionId,
        'component': component,
        'enabled': enabled,
        ...data,
      },
    );
  }

  static void pageView({
    required String routeName,
    required String pageClassName,
    String? fromRouteName,
    String? fromPageClassName,
    required String navigationType,
  }) {
    updateCurrentPage(pageClassName);
    event(
      'page_view',
      category: 'navigation',
      data: <String, Object?>{
        'route_name': routeName,
        'page_class': pageClassName,
        'from_route_name': fromRouteName,
        'from_page_class': fromPageClassName,
        'navigation_type': navigationType,
      },
    );
  }

  static void collectLog({
    required String actionType,
    required String action,
    Object? object1,
    Object? object2,
    Object? object3,
    Object? object4,
    String extData = '',
  }) {
    unawaited(
      collectLogAndWait(
        actionType: actionType,
        action: action,
        object1: object1,
        object2: object2,
        object3: object3,
        object4: object4,
        extData: extData,
      ),
    );
  }

  static Future<bool> collectLogAndWait({
    required String actionType,
    required String action,
    Object? object1,
    Object? object2,
    Object? object3,
    Object? object4,
    String extData = '',
  }) async {
    final normalizedActionType = actionType.trim();
    final normalizedAction = action.trim();
    if (!_enabled || normalizedActionType.isEmpty || normalizedAction.isEmpty) {
      return false;
    }
    final payload = <String, Object?>{
      'action_type': normalizedActionType,
      'action': normalizedAction,
      'object1': object1,
      'object2': object2,
      'object3': object3,
      'object4': object4,
      'ext_data': extData,
    };
    final enqueued = await _collectUploader.enqueuePayloadWithResult(payload);
    unawaited(
      _sink.record(
        GenesisTelemetryEvent(
          name: normalizedAction,
          category: 'collect.log',
          data: _compact(payload),
          context: _context,
        ),
      ),
    );
    return enqueued;
  }

  static void setUserId(String? uid) {
    _collectUploader.setUserId(uid);
    unawaited(_sink.setUserId(uid));
  }

  static void clearUser() {
    setUserId(null);
  }

  static void captureException(Object error, StackTrace stackTrace) {
    FirebaseCrashReporting.recordNonFatal(error, stackTrace);
    unawaited(_sink.captureException(error, stackTrace));
  }

  static Future<AppVersionInfo> _safeAppVersion(
    Future<AppVersionInfo> Function() reader,
    Duration timeout,
  ) async {
    try {
      return await reader().timeout(timeout);
    } catch (error) {
      debugPrint('[Telemetry] app version unavailable: $error');
      return const AppVersionInfo();
    }
  }

  static Future<String> _safeDeviceId(
    DeviceIdService deviceIdService,
    Duration timeout,
  ) async {
    try {
      final value = (await deviceIdService.getDeviceId().timeout(
        timeout,
      )).trim();
      return _hasKnownDeviceId(value) ? value : '';
    } catch (error) {
      debugPrint('[Telemetry] device id unavailable: $error');
      return '';
    }
  }

  static bool _hasKnownAppVersion(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'unknown';
  }

  static bool _hasKnownDeviceId(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'unknown';
  }
}

Map<String, Object> _compact(Map<String, Object?> data) {
  return <String, Object>{
    for (final entry in data.entries)
      if (entry.value != null && entry.value.toString().trim().isNotEmpty)
        entry.key: _safeTelemetryValue(entry.value),
  };
}

Object _safeTelemetryValue(Object? value) {
  final safe = value;
  if (safe is num) return safe;
  if (safe is bool) return safe;
  if (safe is String) return safe;
  return safe?.toString() ?? '';
}

class GenesisTelemetryLifecycleObserver extends WidgetsBindingObserver {
  GenesisTelemetryLifecycleObserver({AppLifecycleState? initialState}) {
    if ((initialState ?? WidgetsBinding.instance.lifecycleState) ==
        AppLifecycleState.resumed) {
      _reportForeground();
    }
  }

  bool _isForeground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!_isForeground) return;
        _isForeground = false;
        GenesisTelemetry.event(
          'app_background',
          category: 'app.lifecycle',
          data: <String, Object?>{'state': state.name},
          collectPayload: <String, Object?>{
            'action_type': 'event',
            'action': 'app_background',
          },
        );
        GenesisTelemetry.handleAppBackgrounded();
      case AppLifecycleState.resumed:
        GenesisTelemetry.handleAppResumed();
        _reportForeground();
    }
  }

  void _reportForeground() {
    if (_isForeground) return;
    _isForeground = true;
    GenesisTelemetry.event(
      'app_foreground',
      category: 'app.lifecycle',
      collectPayload: <String, Object?>{
        'action_type': 'event',
        'action': 'app_foreground',
      },
    );
  }
}

class GenesisTelemetryTapRegion extends StatefulWidget {
  const GenesisTelemetryTapRegion({super.key, required this.child});

  final Widget child;

  @override
  State<GenesisTelemetryTapRegion> createState() =>
      _GenesisTelemetryTapRegionState();
}

class _GenesisTelemetryTapRegionState extends State<GenesisTelemetryTapRegion> {
  DateTime? _lastTapAt;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) {
        final now = DateTime.now();
        final previous = _lastTapAt;
        if (previous != null &&
            now.difference(previous) < const Duration(milliseconds: 120)) {
          return;
        }
        _lastTapAt = now;
        GenesisTelemetry.click(
          actionId: 'global.pointer_up',
          component: 'global_pointer',
          enabled: true,
        );
      },
      child: widget.child,
    );
  }
}

class GenesisTelemetryTap extends StatelessWidget {
  const GenesisTelemetryTap({
    super.key,
    required this.actionId,
    required this.component,
    required this.child,
    this.enabled = true,
    this.data = const <String, Object?>{},
  });

  final String actionId;
  final String component;
  final bool enabled;
  final Map<String, Object?> data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) {
        GenesisTelemetry.click(
          actionId: actionId,
          component: component,
          enabled: enabled,
          data: data,
        );
      },
      child: child,
    );
  }
}
