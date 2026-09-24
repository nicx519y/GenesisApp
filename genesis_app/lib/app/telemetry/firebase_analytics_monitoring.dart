import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/device/method_channel_device_id_service.dart';
import '../../utils/server_clock.dart';
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
typedef FirebaseAnalyticsServerEventReporter =
    Future<void> Function({
      required String event,
      required int occurredAtSeconds,
      required Map<String, Object> parameters,
      String? transactionId,
    });

enum FirebaseAnalyticsPurchaseKind { gems, subscription }

abstract interface class FirebaseAnalyticsDay0AnchorStore {
  Future<DateTime?> read();

  Future<void> write(DateTime serverUtc);
}

class SharedPreferencesFirebaseAnalyticsDay0AnchorStore
    implements FirebaseAnalyticsDay0AnchorStore {
  const SharedPreferencesFirebaseAnalyticsDay0AnchorStore();

  static const String storageKey =
      'firebase_analytics_purchase_day0_anchor_utc_ms_v1';

  @override
  Future<DateTime?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final millis = preferences.getInt(storageKey);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<void> write(DateTime serverUtc) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(
      storageKey,
      serverUtc.toUtc().millisecondsSinceEpoch,
    );
    if (!saved) {
      throw StateError('Failed to persist Firebase Analytics Day0 anchor');
    }
  }
}

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
  static FirebaseAnalyticsDay0AnchorStore _day0AnchorStore =
      const SharedPreferencesFirebaseAnalyticsDay0AnchorStore();
  static var _messageSentCountIncrementer =
      const SharedPreferencesFirebaseAnalyticsMessageSentCounter().increment;
  static Future<String> Function() _deviceIdReader = _readNativeDeviceId;
  static final Map<String, Future<void>> _onceEventRecordings =
      <String, Future<void>>{};
  static final Map<String, Future<void>> _purchaseEligibilityWrites = {};
  static ServerClock _purchaseServerClock = ServerClock();
  static DateTime? Function() _purchaseServerNow = () =>
      _purchaseServerClock.now;
  static DateTime? _day0AnchorUtc;
  static Future<void>? _day0AnchorInitialization;
  static Future<void> _messageSentCountQueue = Future<void>.value();
  static bool? _enabledOverride;
  static FirebaseAnalyticsCollectionConfigurator _collectionConfigurator =
      _configureFirebaseAnalyticsCollection;
  static FirebaseAnalyticsServerEventReporter? _serverEventReporter;
  static int Function() _occurredAtSecondsReader = () =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/
      Duration.millisecondsPerSecond;

  static Future<void> configureCollection({
    required bool enabled,
    required String appEnvironment,
  }) {
    return _collectionConfigurator(enabled, appEnvironment);
  }

  static void configureServerEventReporter(
    FirebaseAnalyticsServerEventReporter? reporter,
  ) {
    _serverEventReporter = reporter;
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
    final occurredAtSeconds = _occurredAtSecondsReader();
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
        _recordEvent(
          'message_sent',
          parameters,
          occurredAtSeconds: occurredAtSeconds,
        ),
        _recordEventOnce(
          'message_sent_first',
          parameters,
          occurredAtSeconds: occurredAtSeconds,
        ),
        if (messageSentCount != null && messageSentCount >= 10)
          _recordEventOnce(
            'message_sent_10_first',
            parameters,
            occurredAtSeconds: occurredAtSeconds,
          ),
        if (messageSentCount != null && messageSentCount >= 20)
          _recordEventOnce(
            'message_sent_20_first',
            parameters,
            occurredAtSeconds: occurredAtSeconds,
          ),
      ]);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] message_sent failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<void> recordLogin({required String method}) {
    return _recordEventWithFirst('login', <String, Object>{'method': method});
  }

  // An Analytics-only marker: an existing checkout matched this receipt. It
  // never creates a payment/recovery record or changes purchase processing.
  static Future<void> markPurchaseEligible({
    required String provider,
    required FirebaseAnalyticsPurchaseKind kind,
    required String purchaseIdentity,
  }) {
    if (!_isEnabled || purchaseIdentity.trim().isEmpty) return Future.value();
    final key = _purchaseEligibilityKey(provider, kind, purchaseIdentity);
    final existing = _purchaseEligibilityWrites[key];
    if (existing != null) return existing;
    late final Future<void> task;
    task =
        (() async {
          try {
            await _onceEventStore.markSent(key);
          } catch (_) {
            debugPrint(
              '[Telemetry][FirebaseAnalytics] purchase eligibility save failed',
            );
          }
        })().whenComplete(() {
          if (identical(_purchaseEligibilityWrites[key], task)) {
            _purchaseEligibilityWrites.remove(key);
          }
        });
    _purchaseEligibilityWrites[key] = task;
    return task;
  }

  /// Records the first successful Gateway server-time synchronization as the
  /// Day0 anchor. Later synchronizations refresh the monotonic server clock but
  /// never move the persisted anchor.
  static Future<void> recordServerTimeSynchronized(DateTime serverUtc) {
    final normalized = serverUtc.toUtc();
    _purchaseServerClock.synchronize(normalized);
    if (_day0AnchorUtc != null) return Future<void>.value();
    final pending = _day0AnchorInitialization;
    if (pending != null) return pending;

    late final Future<void> task;
    task =
        (() async {
          try {
            final stored = await _day0AnchorStore.read();
            if (stored != null) {
              _day0AnchorUtc = stored.toUtc();
              return;
            }
            await _day0AnchorStore.write(normalized);
            _day0AnchorUtc = normalized;
          } catch (e, st) {
            debugPrint(
              '[Telemetry][FirebaseAnalytics] Day0 anchor initialization failed: '
              '$e',
            );
            debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
          }
        })().whenComplete(() {
          if (identical(_day0AnchorInitialization, task)) {
            _day0AnchorInitialization = null;
          }
        });
    _day0AnchorInitialization = task;
    return task;
  }

  static String _purchaseIdentityDigest(
    String provider,
    FirebaseAnalyticsPurchaseKind kind,
    String purchaseIdentity,
  ) => sha256
      .convert(
        utf8.encode(jsonEncode([provider, kind.name, purchaseIdentity.trim()])),
      )
      .toString();

  static String _purchaseEligibilityKey(
    String provider,
    FirebaseAnalyticsPurchaseKind kind,
    String purchaseIdentity,
  ) =>
      'purchase_eligible_v1.${_purchaseIdentityDigest(provider, kind, purchaseIdentity)}';

  /// Called only after backend completion. The optional eligibility marker
  /// distinguishes Gems checkout receipts from arbitrary recovered history.
  static Future<void> recordPurchase({
    required String provider,
    required String productId,
    required FirebaseAnalyticsPurchaseKind kind,
    required String purchaseIdentity,
    String? transactionIdentity,
    bool requireEligibility = false,
    int? priceAmountMicros,
    String priceCurrencyCode = '',
  }) async {
    if (!_isEnabled || purchaseIdentity.trim().isEmpty) return;
    final occurredAtSeconds = _occurredAtSecondsReader();
    if (requireEligibility) {
      final key = _purchaseEligibilityKey(provider, kind, purchaseIdentity);
      try {
        await _purchaseEligibilityWrites[key];
        if (!await _onceEventStore.wasSent(key)) return;
      } catch (_) {
        debugPrint(
          '[Telemetry][FirebaseAnalytics] purchase eligibility read failed',
        );
        return;
      }
    }
    final kindFirstEvent = switch (kind) {
      FirebaseAnalyticsPurchaseKind.gems => 'gems_first',
      FirebaseAnalyticsPurchaseKind.subscription => 'subscription_first',
    };
    // Google new purchases/upgrades use their token; Apple uses the current
    // transaction ID, never the original subscription chain. Persist only a
    // digest, and keep this identity out of the Analytics parameters/logs.
    final identity = _purchaseIdentityDigest(provider, kind, purchaseIdentity);
    final transactionId = (transactionIdentity ?? purchaseIdentity).trim();
    var deviceId = 'unknown';
    try {
      final value = (await _deviceIdReader()).trim();
      if (value.isNotEmpty) deviceId = value;
    } catch (_) {
      // Optional device metadata must not discard a completed purchase.
    }
    final parameters = <String, Object>{
      'provider': provider,
      'product_id': productId,
      'device_id': deviceId,
      ..._purchasePriceParameters(
        priceAmountMicros: priceAmountMicros,
        priceCurrencyCode: priceCurrencyCode,
      ),
    };
    final day0 = await _isPurchaseDay0();
    final kindName = kind.name;
    await Future.wait<void>([
      _recordEventOnce(
        'purchase',
        parameters,
        storageKey: 'purchase_transaction_v1.$identity',
        transactionId: transactionId,
        occurredAtSeconds: occurredAtSeconds,
      ),
      _recordEventOnce(
        kindName,
        parameters,
        storageKey: '${kindName}_transaction_v1.$identity',
        transactionId: transactionId,
        occurredAtSeconds: occurredAtSeconds,
      ),
      _recordEventOnce(
        'purchase_first',
        parameters,
        transactionId: transactionId,
        occurredAtSeconds: occurredAtSeconds,
      ),
      _recordEventOnce(
        kindFirstEvent,
        parameters,
        transactionId: transactionId,
        occurredAtSeconds: occurredAtSeconds,
      ),
      if (day0) ...[
        _recordEventOnce(
          'purchase_day0',
          parameters,
          storageKey: 'purchase_day0_transaction_v1.$identity',
          transactionId: transactionId,
          occurredAtSeconds: occurredAtSeconds,
        ),
        _recordEventOnce(
          '${kindName}_day0',
          parameters,
          storageKey: '${kindName}_day0_transaction_v1.$identity',
          transactionId: transactionId,
          occurredAtSeconds: occurredAtSeconds,
        ),
        _recordEventOnce(
          'purchase_first_day0',
          parameters,
          transactionId: transactionId,
          occurredAtSeconds: occurredAtSeconds,
        ),
        _recordEventOnce(
          '${kindName}_first_day0',
          parameters,
          transactionId: transactionId,
          occurredAtSeconds: occurredAtSeconds,
        ),
      ],
    ]);
  }

  static Map<String, Object> _purchasePriceParameters({
    required int? priceAmountMicros,
    required String priceCurrencyCode,
  }) {
    final currency = priceCurrencyCode.trim().toUpperCase();
    if (priceAmountMicros == null ||
        priceAmountMicros < 0 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      return const <String, Object>{};
    }
    return <String, Object>{
      'value': priceAmountMicros / 1000000,
      'currency': currency,
    };
  }

  static Future<bool> _isPurchaseDay0() async {
    final pending = _day0AnchorInitialization;
    if (pending != null) await pending;
    final anchor = _day0AnchorUtc;
    final now = _purchaseServerNow()?.toUtc();
    if (anchor == null || now == null || now.isBefore(anchor)) return false;
    const chinaOffset = Duration(hours: 8);
    final anchorChina = anchor.add(chinaOffset);
    final nowChina = now.add(chinaOffset);
    return anchorChina.year == nowChina.year &&
        anchorChina.month == nowChina.month &&
        anchorChina.day == nowChina.day;
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
    }, occurredAtSeconds: _occurredAtSecondsReader());
  }

  static Future<void> _recordEvent(
    String name,
    Map<String, Object> parameters, {
    required int occurredAtSeconds,
  }) async {
    if (!_isEnabled) return;
    final serverReport = _reportServerEvent(
      name,
      parameters,
      occurredAtSeconds: occurredAtSeconds,
    );
    try {
      await _readiness();
      await _client.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] $name failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
    await serverReport;
  }

  static Future<void> _recordEventWithFirst(
    String name,
    Map<String, Object> parameters, {
    List<String> additionalOnceEventNames = const <String>[],
  }) async {
    if (!_isEnabled) return;
    final occurredAtSeconds = _occurredAtSecondsReader();
    try {
      final deviceId = (await _deviceIdReader()).trim();
      final parametersWithDeviceId = <String, Object>{
        ...parameters,
        'device_id': deviceId.isEmpty ? 'unknown' : deviceId,
      };
      await Future.wait<void>(<Future<void>>[
        _recordEvent(
          name,
          parametersWithDeviceId,
          occurredAtSeconds: occurredAtSeconds,
        ),
        _recordEventOnce(
          '${name}_first',
          parametersWithDeviceId,
          occurredAtSeconds: occurredAtSeconds,
        ),
        for (final eventName in additionalOnceEventNames)
          _recordEventOnce(
            eventName,
            parametersWithDeviceId,
            occurredAtSeconds: occurredAtSeconds,
          ),
      ]);
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] $name failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<void> _recordEventOnce(
    String name,
    Map<String, Object> parameters, {
    required int occurredAtSeconds,
    String? storageKey,
    String? transactionId,
  }) {
    if (!_isEnabled) return Future<void>.value();
    final key = storageKey ?? name;
    final existing = _onceEventRecordings[key];
    if (existing != null) return existing;

    late final Future<void> recording;
    recording =
        _recordEventOnceUnlocked(
          name,
          parameters,
          key,
          occurredAtSeconds: occurredAtSeconds,
          transactionId: transactionId,
        ).whenComplete(() {
          if (identical(_onceEventRecordings[key], recording)) {
            _onceEventRecordings.remove(key);
          }
        });
    _onceEventRecordings[key] = recording;
    return recording;
  }

  static Future<void> _recordEventOnceUnlocked(
    String name,
    Map<String, Object> parameters,
    String storageKey, {
    required int occurredAtSeconds,
    String? transactionId,
  }) async {
    try {
      if (await _onceEventStore.wasSent(storageKey)) return;
      final serverReport = _reportServerEvent(
        name,
        parameters,
        occurredAtSeconds: occurredAtSeconds,
        transactionId: transactionId,
      );
      try {
        await _readiness();
        // Firebase exposes SDK acceptance, not a server-delivery
        // acknowledgement. Persist only after the platform SDK accepts the
        // event call.
        await _client.logEvent(name: name, parameters: parameters);
        await _onceEventStore.markSent(storageKey);
      } finally {
        await serverReport;
      }
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseAnalytics] $name failed: $e');
      debugPrint('[Telemetry][FirebaseAnalytics] stacktrace:\n$st');
    }
  }

  static Future<void> _reportServerEvent(
    String name,
    Map<String, Object> parameters, {
    required int occurredAtSeconds,
    String? transactionId,
  }) async {
    final reporter = _serverEventReporter;
    if (reporter == null) return;
    try {
      await reporter(
        event: name,
        occurredAtSeconds: occurredAtSeconds,
        parameters: parameters,
        transactionId: transactionId,
      );
    } catch (e, st) {
      debugPrint('[Telemetry][EventReport] $name enqueue failed: $e');
      debugPrint('[Telemetry][EventReport] stacktrace:\n$st');
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
  static void setDay0AnchorStoreForTesting(
    FirebaseAnalyticsDay0AnchorStore value,
  ) {
    _day0AnchorStore = value;
    _day0AnchorUtc = null;
    _day0AnchorInitialization = null;
  }

  @visibleForTesting
  static void setPurchaseServerNowForTesting(DateTime? Function() value) {
    _purchaseServerNow = value;
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
  static void setOccurredAtSecondsReaderForTesting(int Function() value) {
    _occurredAtSecondsReader = value;
  }

  @visibleForTesting
  static void resetForTesting() {
    _client = const _FirebaseAppAnalyticsClient();
    _readiness = FirebaseRuntime.ensureInitialized;
    _onceEventStore = const SharedPreferencesFirebaseAnalyticsOnceEventStore();
    _day0AnchorStore =
        const SharedPreferencesFirebaseAnalyticsDay0AnchorStore();
    _messageSentCountIncrementer =
        const SharedPreferencesFirebaseAnalyticsMessageSentCounter().increment;
    _deviceIdReader = _readNativeDeviceId;
    _onceEventRecordings.clear();
    _purchaseEligibilityWrites.clear();
    _purchaseServerClock = ServerClock();
    _purchaseServerNow = () => _purchaseServerClock.now;
    _day0AnchorUtc = null;
    _day0AnchorInitialization = null;
    _messageSentCountQueue = Future<void>.value();
    _enabledOverride = null;
    _collectionConfigurator = _configureFirebaseAnalyticsCollection;
    _serverEventReporter = null;
    _occurredAtSecondsReader = () =>
        DateTime.now().toUtc().millisecondsSinceEpoch ~/
        Duration.millisecondsPerSecond;
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
