import 'dart:async';

import 'package:alibabacloud_rum_flutter_plugin/alibabacloud_rum_flutter_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../platform/app/app_metadata_service.dart';
import '../../platform/device/device_id_service.dart';
import '../config/app_config.dart';
import '../debug_page_tracker.dart';

class GenesisSentryConfig {
  const GenesisSentryConfig({
    this.dsn = AppConfig.defaultSentryDsn,
    this.environment = 'production',
    this.tracesSampleRate = '0.1',
    this.debug = false,
  });

  factory GenesisSentryConfig.fromAppConfig(AppConfig config) {
    return GenesisSentryConfig(
      dsn: config.sentryDsn,
      environment: config.sentryEnvironment,
      tracesSampleRate: config.sentryTracesSampleRate,
      debug: config.sentryDebug,
    );
  }

  final String dsn;
  final String environment;
  final String tracesSampleRate;
  final bool debug;

  bool get isEnabled => dsn.trim().isNotEmpty;
  double get parsedTracesSampleRate =>
      double.tryParse(tracesSampleRate.trim()) ?? 0.1;
}

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
    this.level = SentryLevel.info,
    this.capture = true,
  });

  final String name;
  final String category;
  final Map<String, Object?> data;
  final GenesisTelemetryContext context;
  final SentryLevel level;
  final bool capture;

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

class SentryGenesisTelemetrySink implements GenesisTelemetrySink {
  const SentryGenesisTelemetrySink();

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    final data = _compact(event.fullData);
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: event.name,
        category: event.category,
        level: event.level,
        data: data,
      ),
    );
    if (!event.capture) return;
    await Sentry.captureMessage(
      'genesis.${event.name}',
      level: event.level,
      withScope: (scope) {
        for (final entry in _tagValues(data).entries) {
          scope.setTag(entry.key, entry.value);
        }
        scope.setContexts('genesis_event', data);
      },
    );
    await _recordAlibabaEvent(event, data);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {
    final data = _compact(context.toMap());
    await Sentry.configureScope((scope) {
      for (final entry in _tagValues(data).entries) {
        scope.setTag(entry.key, entry.value);
      }
      scope.setContexts('genesis_app', data);
    });
    await _safeAlibabaCall(() => AlibabaCloudRUM().setExtraInfo(data));
  }

  @override
  Future<void> setUserId(String? uid) async {
    final value = uid?.trim();
    await Sentry.configureScope((scope) {
      scope.setUser(
        value == null || value.isEmpty ? null : SentryUser(id: value),
      );
    });
    await _safeAlibabaCall(() => AlibabaCloudRUM().setUserName(value ?? ''));
  }

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {
    await Sentry.captureException(error, stackTrace: stackTrace);
    await _safeAlibabaCall(
      () => AlibabaCloudRUM().setCustomException(
        error.runtimeType.toString(),
        error.toString(),
        stackTrace.toString(),
      ),
    );
  }

  Map<String, dynamic> _compact(Map<String, Object?> data) {
    return <String, dynamic>{
      for (final entry in data.entries)
        if (entry.value != null && entry.value.toString().trim().isNotEmpty)
          entry.key: _safeValue(entry.value),
    };
  }

  Map<String, String> _tagValues(Map<String, dynamic> data) {
    return <String, String>{
      for (final key in const [
        'app_version',
        'app_build',
        'device_id',
        'platform',
        'environment',
        'current_page',
        'event_name',
        'request_family',
        'gateway_phase',
      ])
        if (data[key] != null) key: data[key].toString(),
    };
  }

  Object _safeValue(Object? value) {
    final safe = value;
    if (safe is num) return safe;
    if (safe is bool) return safe;
    if (safe is String) return safe;
    return safe?.toString() ?? '';
  }

  Future<void> _recordAlibabaEvent(
    GenesisTelemetryEvent event,
    Map<String, dynamic> data,
  ) {
    return _safeAlibabaCall(
      () => AlibabaCloudRUM().setCustomEvent(
        event.name,
        group: event.category,
        attributes: _stringAttributes(data),
      ),
    );
  }

  Map<String, String> _stringAttributes(Map<String, dynamic> data) {
    return <String, String>{
      for (final entry in data.entries) entry.key: entry.value.toString(),
    };
  }

  Future<void> _safeAlibabaCall(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Telemetry must not affect app behavior.
    }
  }
}

class GenesisTelemetry {
  GenesisTelemetry._();

  static GenesisTelemetrySink _sink = const SentryGenesisTelemetrySink();
  static GenesisTelemetryContext _context = const GenesisTelemetryContext();
  static bool _enabled = true;

  @visibleForTesting
  static GenesisTelemetryContext get contextForTesting => _context;

  @visibleForTesting
  static void setSinkForTesting(GenesisTelemetrySink sink) {
    _sink = sink;
    _enabled = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _sink = const SentryGenesisTelemetrySink();
    _context = const GenesisTelemetryContext();
    _enabled = true;
  }

  static Future<void> initialize({
    required GenesisSentryConfig config,
    required DeviceIdService deviceIdService,
    AppVersionInfo? appVersion,
  }) async {
    final version = appVersion ?? await AppMetadataService.appVersion();
    final deviceId = await _safeDeviceId(deviceIdService);
    _context = _context.copyWith(
      appVersion: version.versionName.trim().isEmpty
          ? 'unknown'
          : version.versionName.trim(),
      appBuild: version.versionCode.trim(),
      deviceId: deviceId,
      platform: defaultTargetPlatform.name,
      environment: config.environment.trim().isEmpty
          ? 'production'
          : config.environment.trim(),
      currentPage: genesisCurrentPageClassName.value,
    );
    _enabled = true;
    await _sink.setContext(_context);
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
    SentryLevel level = SentryLevel.info,
    bool capture = true,
  }) {
    if (!_enabled) return;
    unawaited(
      _sink.record(
        GenesisTelemetryEvent(
          name: name,
          category: category,
          data: <String, Object?>{'event_name': name, ...data},
          context: _context,
          level: level,
          capture: capture,
        ),
      ),
    );
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

  static void setUserId(String? uid) {
    unawaited(_sink.setUserId(uid));
  }

  static void clearUser() {
    setUserId(null);
  }

  static void captureException(Object error, StackTrace stackTrace) {
    unawaited(_sink.captureException(error, stackTrace));
  }

  static Future<String> _safeDeviceId(DeviceIdService deviceIdService) async {
    try {
      return (await deviceIdService.getDeviceId()).trim();
    } catch (_) {
      return '';
    }
  }
}

class GenesisTelemetryLifecycleObserver extends WidgetsBindingObserver {
  GenesisTelemetryLifecycleObserver({DateTime? startedAt})
    : _startedAt = startedAt ?? DateTime.now() {
    GenesisTelemetry.event(
      'app_start',
      category: 'app.lifecycle',
      data: <String, Object?>{
        'startup_duration_ms': DateTime.now()
            .difference(_startedAt)
            .inMilliseconds,
        'start_type': 'cold',
      },
    );
  }

  final DateTime _startedAt;
  DateTime? _backgroundedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        GenesisTelemetry.event(
          'app_background',
          category: 'app.lifecycle',
          data: <String, Object?>{'state': state.name},
        );
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        GenesisTelemetry.event(
          'app_foreground',
          category: 'app.lifecycle',
          data: <String, Object?>{
            'state': state.name,
            if (backgroundedAt != null)
              'background_duration_ms': DateTime.now()
                  .difference(backgroundedAt)
                  .inMilliseconds,
            'start_type': backgroundedAt == null ? 'cold' : 'warm',
          },
        );
    }
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
