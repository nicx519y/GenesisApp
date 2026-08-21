import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/device/method_channel_device_id_service.dart';
import 'firebase_runtime.dart';
import 'telemetry_upload_policy.dart';

abstract interface class AppAnalyticsClient {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });
}

typedef FirebaseReadiness = Future<void> Function();
typedef FirebaseAnalyticsMessageSentCountIncrementer = Future<int> Function();
typedef FirebaseAnalyticsCollectionConfigurator =
    Future<void> Function(bool enabled, String appEnvironment);

abstract interface class FirebaseAnalyticsOnceEventStore {
  Future<bool> wasSent(String eventName);

  Future<void> markSent(String eventName);
}

class SharedPreferencesFirebaseAnalyticsOnceEventStore
    implements FirebaseAnalyticsOnceEventStore {
  const SharedPreferencesFirebaseAnalyticsOnceEventStore();

  static const String storageKeyPrefix = 'firebase_analytics_once_event_v1.';

  @override
  Future<bool> wasSent(String eventName) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_storageKey(eventName)) == 1;
  }

  @override
  Future<void> markSent(String eventName) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(_storageKey(eventName), 1);
    if (!saved) {
      throw StateError('Failed to persist Firebase Analytics once event');
    }
  }

  static String _storageKey(String eventName) => '$storageKeyPrefix$eventName';
}

class SharedPreferencesFirebaseAnalyticsMessageSentCounter {
  const SharedPreferencesFirebaseAnalyticsMessageSentCounter();

  static const String storageKey = 'firebase_analytics_message_sent_count_v1';

  Future<int> increment() async {
    final preferences = await SharedPreferences.getInstance();
    final storedCount = preferences.getInt(storageKey) ?? 0;
    final nextCount = (storedCount < 0 ? 0 : storedCount) + 1;
    final saved = await preferences.setInt(storageKey, nextCount);
    if (!saved) {
      throw StateError(
        'Failed to persist Firebase Analytics message sent count',
      );
    }
    return nextCount;
  }
}

/// Best-effort Firebase Analytics events owned by the app.
///
/// Native collection starts disabled. The runtime telemetry policy enables or
/// disables automatic collection and this class gates app-owned custom events.
class FirebaseAnalyticsMonitoring {
  const FirebaseAnalyticsMonitoring._();

  static AppAnalyticsClient _client = const _FirebaseAppAnalyticsClient();
  static FirebaseReadiness _readiness = FirebaseRuntime.ensureInitialized;
  static FirebaseAnalyticsOnceEventStore _onceEventStore =
      const SharedPreferencesFirebaseAnalyticsOnceEventStore();
  static var _messageSentCountIncrementer =
      const SharedPreferencesFirebaseAnalyticsMessageSentCounter().increment;
  static Future<String> Function() _deviceIdReader = _readNativeDeviceId;
  static final Map<String, Future<void>> _onceEventRecordings =
      <String, Future<void>>{};
  static Future<void> _messageSentCountQueue = Future<void>.value();
  static bool? _enabledOverride;
  static FirebaseAnalyticsCollectionConfigurator _collectionConfigurator =
      _configureFirebaseAnalyticsCollection;

  static Future<void> configureCollection({
    required bool enabled,
    required String appEnvironment,
  }) {
    return _collectionConfigurator(enabled, appEnvironment);
  }

  static Future<void> recordLaunch({
    required String originId,
    required String roleType,
  }) {
    return _recordEventWithFirst('launch', <String, Object>{
      'origin_id': originId,
      'role_type': roleType,
    });
  }

  static Future<void> recordLaunchSuccess({
    required String originId,
    required String roleType,
    required String worldId,
  }) {
    return _recordEventWithFirst('launch_success', <String, Object>{
      'origin_id': originId,
      'role_type': roleType,
      'world_id': worldId,
    });
  }

  static Future<void> recordMessageSent({
    required String worldId,
    required String locationId,
  }) async {
    if (!_isEnabled) return;
    try {
      final deviceId = (await _deviceIdReader()).trim();
      final parameters = <String, Object>{
        'world_id': worldId,
        'location_id': locationId,
        'device_id': deviceId.isEmpty ? 'unknown' : deviceId,
      };
      int? messageSentCount;
      try {
        messageSentCount = await _incrementMessageSentCount();
      } catch (e, st) {
        debugPrint(
          '[Telemetry][FirebaseAnalytics] message_sent count failed: $e',
        );
        debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
      }

      await Future.wait<void>(<Future<void>>[
        _recordEvent('message_sent', parameters),
        _recordEventOnce('message_sent_first', parameters),
        if (messageSentCount != null && messageSentCount >= 10)
          _recordEventOnce('message_sent_10_first', parameters),
        if (messageSentCount != null && messageSentCount >= 20)
          _recordEventOnce('message_sent_20_first', parameters),
      ]);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] message_sent failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<void> recordLogin({required String method}) {
    return _recordEventWithFirst('login', <String, Object>{'method': method});
  }

  static Future<void> recordPurchase({
    required String provider,
    required String productId,
  }) {
    return _recordEventWithFirst('purchase', <String, Object>{
      'provider': provider,
      'product_id': productId,
    });
  }

  static Future<void> recordPerformanceOperation({
    required String surface,
    required String phase,
    required String result,
    required int durationMs,
    required int attempt,
    required String dataSource,
    String? errorType,
  }) {
    return _recordEvent('perf_operation_complete', <String, Object>{
      'surface': surface,
      'phase': phase,
      'result': result,
      'duration_ms': durationMs,
      'attempt': attempt,
      'data_source': dataSource,
      if (errorType != null && errorType.trim().isNotEmpty)
        'error_type': errorType.trim(),
    });
  }

  static Future<void> _recordEvent(
    String name,
    Map<String, Object> parameters,
  ) async {
    if (!_isEnabled) return;
    try {
      await _readiness();
      await _client.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] $name failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<void> _recordEventWithFirst(
    String name,
    Map<String, Object> parameters,
  ) async {
    if (!_isEnabled) return;
    try {
      final deviceId = (await _deviceIdReader()).trim();
      final parametersWithDeviceId = <String, Object>{
        ...parameters,
        'device_id': deviceId.isEmpty ? 'unknown' : deviceId,
      };
      await Future.wait<void>(<Future<void>>[
        _recordEvent(name, parametersWithDeviceId),
        _recordEventOnce('${name}_first', parametersWithDeviceId),
      ]);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] $name failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<void> _recordEventOnce(
    String name,
    Map<String, Object> parameters,
  ) {
    if (!_isEnabled) return Future<void>.value();
    final existing = _onceEventRecordings[name];
    if (existing != null) return existing;

    late final Future<void> recording;
    recording = _recordEventOnceUnlocked(name, parameters).whenComplete(() {
      if (identical(_onceEventRecordings[name], recording)) {
        _onceEventRecordings.remove(name);
      }
    });
    _onceEventRecordings[name] = recording;
    return recording;
  }

  static Future<void> _recordEventOnceUnlocked(
    String name,
    Map<String, Object> parameters,
  ) async {
    try {
      if (await _onceEventStore.wasSent(name)) return;
      await _readiness();
      // Firebase exposes SDK acceptance, not a server-delivery acknowledgement.
      // Persist only after the platform SDK accepts the event call.
      await _client.logEvent(name: name, parameters: parameters);
      await _onceEventStore.markSent(name);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] $name failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<int> _incrementMessageSentCount() {
    final increment = _messageSentCountQueue.then(
      (_) => _messageSentCountIncrementer(),
    );
    _messageSentCountQueue = increment.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return increment;
  }

  static bool get _isEnabled =>
      _enabledOverride ?? TelemetryUploadPolicy.state.value.analyticsEnabled;

  @visibleForTesting
  static void setEnabledForTesting(bool? value) {
    _enabledOverride = value;
  }

  @visibleForTesting
  static void setCollectionConfiguratorForTesting(
    FirebaseAnalyticsCollectionConfigurator value,
  ) {
    _collectionConfigurator = value;
  }

  @visibleForTesting
  static void setClientForTesting(AppAnalyticsClient value) {
    _client = value;
  }

  @visibleForTesting
  static void setReadinessForTesting(Future<void> value) {
    _readiness = () => value;
  }

  @visibleForTesting
  static void setOnceEventStoreForTesting(
    FirebaseAnalyticsOnceEventStore value,
  ) {
    _onceEventStore = value;
    _onceEventRecordings.clear();
  }

  @visibleForTesting
  static void setDeviceIdReaderForTesting(Future<String> Function() value) {
    _deviceIdReader = value;
  }

  @visibleForTesting
  static void setMessageSentCountIncrementerForTesting(
    FirebaseAnalyticsMessageSentCountIncrementer value,
  ) {
    _messageSentCountIncrementer = value;
    _messageSentCountQueue = Future<void>.value();
  }

  @visibleForTesting
  static void resetForTesting() {
    _client = const _FirebaseAppAnalyticsClient();
    _readiness = FirebaseRuntime.ensureInitialized;
    _onceEventStore = const SharedPreferencesFirebaseAnalyticsOnceEventStore();
    _messageSentCountIncrementer =
        const SharedPreferencesFirebaseAnalyticsMessageSentCounter().increment;
    _deviceIdReader = _readNativeDeviceId;
    _onceEventRecordings.clear();
    _messageSentCountQueue = Future<void>.value();
    _enabledOverride = null;
    _collectionConfigurator = _configureFirebaseAnalyticsCollection;
  }

  static Future<String> _readNativeDeviceId() {
    return const NativeDeviceIdService().getDeviceId();
  }
}

Future<void> _configureFirebaseAnalyticsCollection(
  bool enabled,
  String appEnvironment,
) async {
  final analytics = FirebaseAnalytics.instance;
  if (enabled) {
    await analytics.setDefaultEventParameters(<String, Object?>{
      'app_environment': appEnvironment,
    });
    await analytics.setAnalyticsCollectionEnabled(true);
  } else {
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setDefaultEventParameters(null);
  }
}

class _FirebaseAppAnalyticsClient implements AppAnalyticsClient {
  const _FirebaseAppAnalyticsClient();

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}
