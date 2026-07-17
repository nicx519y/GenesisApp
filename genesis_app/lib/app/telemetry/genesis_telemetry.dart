import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../../network/http_transport.dart';
import '../../network/io_http_transport.dart';
import '../../platform/app/app_metadata_service.dart';
import '../../platform/device/device_id_service.dart';
import '../config/app_config.dart';
import '../debug_page_tracker.dart';
import 'firebase_crash_reporting.dart';

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

class CompositeGenesisTelemetrySink implements GenesisTelemetrySink {
  const CompositeGenesisTelemetrySink(this.sinks);

  final List<GenesisTelemetrySink> sinks;

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    await Future.wait(sinks.map((sink) => sink.record(event)));
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {
    await Future.wait(sinks.map((sink) => sink.setContext(context)));
  }

  @override
  Future<void> setUserId(String? uid) async {
    await Future.wait(sinks.map((sink) => sink.setUserId(uid)));
  }

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {
    await Future.wait(
      sinks.map((sink) => sink.captureException(error, stackTrace)),
    );
  }
}

@visibleForTesting
abstract interface class PostHogTelemetryClient {
  Future<void> setup(PostHogConfig config);
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
  });
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
  });
  Future<void> reset();
  Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  });
}

class SdkPostHogTelemetryClient implements PostHogTelemetryClient {
  const SdkPostHogTelemetryClient();

  @override
  Future<void> setup(PostHogConfig config) => Posthog().setup(config);

  @override
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
  }) {
    return Posthog().capture(eventName: eventName, properties: properties);
  }

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
  }) {
    return Posthog().identify(userId: userId, userProperties: userProperties);
  }

  @override
  Future<void> reset() => Posthog().reset();

  @override
  Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) {
    return Posthog().captureException(
      error: error,
      stackTrace: stackTrace,
      properties: properties,
    );
  }
}

class PostHogGenesisTelemetrySink implements GenesisTelemetrySink {
  PostHogGenesisTelemetrySink({required PostHogTelemetryClient client})
    : _client = client;

  final PostHogTelemetryClient _client;
  GenesisTelemetryContext _context = const GenesisTelemetryContext();

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    if (!event.capture) return;
    if (event.category == 'collect.log') return;
    await _safePostHogCall(
      () => _client.capture(
        eventName: event.name,
        properties: _compact(<String, Object?>{
          ...event.fullData,
          'category': event.category,
          'level': event.level.name,
        }),
      ),
    );
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {
    _context = context;
  }

  @override
  Future<void> setUserId(String? uid) async {
    final userId = uid?.trim() ?? '';
    await _safePostHogCall(() {
      if (userId.isEmpty) return _client.reset();
      return _client.identify(
        userId: userId,
        userProperties: _compact(_context.toMap()),
      );
    });
  }

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {
    await _safePostHogCall(
      () => _client.captureException(
        error: error,
        stackTrace: stackTrace,
        properties: _compact(<String, Object?>{
          ..._context.toMap(),
          'error_type': error.runtimeType.toString(),
          'handled': true,
        }),
      ),
    );
  }
}

@visibleForTesting
abstract interface class CollectTelemetryClient {
  Future<void> collect(
    Map<String, Object> payload, {
    Map<String, String> headers = const <String, String>{},
  });
}

class SdkCollectTelemetryClient implements CollectTelemetryClient {
  SdkCollectTelemetryClient({
    required String endpoint,
    HttpTransport? transport,
    this.timeoutMs = 5000,
  }) : _endpoint = Uri.parse(endpoint),
       _transport = transport ?? IoHttpTransport();

  final Uri _endpoint;
  final HttpTransport _transport;
  final int timeoutMs;

  @override
  Future<void> collect(
    Map<String, Object> payload, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await _transport.send(
      TransportRequest(
        method: 'POST',
        uri: _endpoint,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
          ...headers,
        },
        bodyBytes: utf8.encode(jsonEncode(payload)),
        timeoutMs: timeoutMs,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Collect request failed: ${response.statusCode}');
    }
  }
}

class CollectGenesisTelemetrySink implements GenesisTelemetrySink {
  CollectGenesisTelemetrySink({required CollectTelemetryClient client})
    : _client = client;

  final CollectTelemetryClient _client;
  GenesisTelemetryContext _context = const GenesisTelemetryContext();
  String? _userId;

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    if (!event.capture) return;
    final payload = event.category == 'collect.log'
        ? _collectLogPayload(event.data)
        : _collectLogPayload(event.collectPayload ?? const {});
    if (payload.isEmpty) return;
    await _safeCollectCall(
      () => _client.collect(
        payload,
        headers: _collectHeaders(
          includeIdentity: event.includeCollectIdentityHeaders,
        ),
      ),
    );
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {
    _context = context;
  }

  @override
  Future<void> setUserId(String? uid) async {
    final normalized = uid?.trim() ?? '';
    _userId = normalized.isEmpty ? null : normalized;
  }

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {
    // Collect is reserved for product behavior logs.
  }

  Map<String, String> _collectHeaders({required bool includeIdentity}) {
    return <String, String>{
      for (final entry in <String, String?>{
        'X-Platform': _collectPlatformHeaderValue(_context.platform),
        'X-App-Version': _context.appVersion,
        if (includeIdentity) 'X-Device-ID': _context.deviceId,
        if (includeIdentity) 'X-UID': _userId,
      }.entries)
        if ((entry.value ?? '').trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };
  }
}

class GenesisTelemetry {
  GenesisTelemetry._();

  static GenesisTelemetrySink _sink = const NoopGenesisTelemetrySink();
  static GenesisTelemetryContext _context = const GenesisTelemetryContext();
  static bool _enabled = true;
  static bool _sinkOverriddenForTesting = false;

  @visibleForTesting
  static GenesisTelemetryContext get contextForTesting => _context;

  @visibleForTesting
  static void setSinkForTesting(GenesisTelemetrySink sink) {
    _sink = sink;
    _enabled = true;
    _sinkOverriddenForTesting = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _sink = const NoopGenesisTelemetrySink();
    _context = const GenesisTelemetryContext();
    _enabled = true;
    _sinkOverriddenForTesting = false;
  }

  @visibleForTesting
  static Future<GenesisTelemetrySink> buildDefaultSinkForTesting({
    required AppConfig config,
    PostHogTelemetryClient? postHogClient,
    CollectTelemetryClient? collectClient,
  }) {
    return _buildDefaultSink(
      config: config,
      postHogClient: postHogClient,
      collectClient: collectClient,
    );
  }

  static Future<void> initialize({
    required AppConfig config,
    required DeviceIdService deviceIdService,
    AppVersionInfo? appVersion,
    bool trackingEnabled = true,
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
      environment: config.apiEnvironment.trim().isEmpty
          ? 'production'
          : config.apiEnvironment.trim(),
      currentPage: genesisCurrentPageClassName.value,
    );
    if (!_sinkOverriddenForTesting) {
      _sink = trackingEnabled
          ? await _buildDefaultSink(config: config)
          : const NoopGenesisTelemetrySink();
    }
    _enabled = trackingEnabled;
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
    GenesisTelemetryLevel level = GenesisTelemetryLevel.info,
    bool capture = true,
    Map<String, Object?>? collectPayload,
    bool includeCollectIdentityHeaders = true,
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
          collectPayload: collectPayload,
          includeCollectIdentityHeaders: includeCollectIdentityHeaders,
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

  static void collectLog({
    required String actionType,
    required String action,
    Object? object1,
    Object? object2,
    Object? object3,
  }) {
    final normalizedActionType = actionType.trim();
    final normalizedAction = action.trim();
    if (!_enabled || normalizedActionType.isEmpty || normalizedAction.isEmpty) {
      return;
    }
    unawaited(
      _sink.record(
        GenesisTelemetryEvent(
          name: normalizedAction,
          category: 'collect.log',
          data: _compact(<String, Object?>{
            'action_type': normalizedActionType,
            'action': normalizedAction,
            'object1': object1,
            'object2': object2,
            'object3': object3,
          }),
          context: _context,
        ),
      ),
    );
  }

  static void setUserId(String? uid) {
    unawaited(_sink.setUserId(uid));
  }

  static void clearUser() {
    setUserId(null);
  }

  static void captureException(Object error, StackTrace stackTrace) {
    FirebaseCrashReporting.recordNonFatal(error, stackTrace);
    unawaited(_sink.captureException(error, stackTrace));
  }

  static Future<String> _safeDeviceId(DeviceIdService deviceIdService) async {
    try {
      return (await deviceIdService.getDeviceId()).trim();
    } catch (_) {
      return '';
    }
  }

  static Future<GenesisTelemetrySink> _buildDefaultSink({
    required AppConfig config,
    PostHogTelemetryClient? postHogClient,
    CollectTelemetryClient? collectClient,
  }) async {
    final sinks = <GenesisTelemetrySink>[];
    final collectSink = _buildCollectSink(
      config: config,
      collectClient: collectClient,
    );
    if (collectSink != null) sinks.add(collectSink);

    final projectToken = config.postHogProjectToken.trim();
    if (projectToken.isNotEmpty) {
      final client = postHogClient ?? const SdkPostHogTelemetryClient();
      final postHogConfig = PostHogConfig(projectToken)
        ..host = config.postHogHost
        ..debug = config.postHogDebug
        ..captureApplicationLifecycleEvents = false
        ..sessionReplay = false
        ..surveys = false;
      await _safeStaticPostHogCall(() => client.setup(postHogConfig));
      sinks.add(PostHogGenesisTelemetrySink(client: client));
    }

    if (sinks.isEmpty) return const NoopGenesisTelemetrySink();
    if (sinks.length == 1) return sinks.single;
    return CompositeGenesisTelemetrySink(sinks);
  }
}

GenesisTelemetrySink? _buildCollectSink({
  required AppConfig config,
  CollectTelemetryClient? collectClient,
}) {
  if (!config.collectEnabled || config.useMock == true) return null;
  final endpoint = config.collectEndpoint.trim();
  if (endpoint.isEmpty) return null;
  try {
    final client =
        collectClient ??
        SdkCollectTelemetryClient(
          endpoint: endpoint,
          transport: IoHttpTransport(proxy: config.debugProxy),
        );
    return CollectGenesisTelemetrySink(client: client);
  } catch (_) {
    return null;
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

Map<String, Object> _collectLogPayload(Map<String, Object?> data) {
  return _compact(<String, Object?>{
    'action_type': data['action_type'],
    'action': data['action'],
    'object1': data['object1'],
    'object2': data['object2'],
    'object3': data['object3'],
  });
}

String _collectPlatformHeaderValue(String platform) {
  final normalized = platform.trim().toLowerCase();
  if (normalized == 'ios') return 'ios';
  if (normalized == 'android') return 'android';
  return platform.trim();
}

Future<void> _safePostHogCall(Future<void> Function() call) async {
  try {
    await call();
  } catch (_) {
    // Telemetry must not affect app behavior.
  }
}

Future<void> _safeCollectCall(Future<void> Function() call) async {
  try {
    await call();
  } catch (_) {
    // Telemetry must not affect app behavior.
  }
}

Future<void> _safeStaticPostHogCall(Future<void> Function() call) async {
  try {
    await call();
  } catch (_) {
    // Telemetry startup must not affect app behavior.
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
