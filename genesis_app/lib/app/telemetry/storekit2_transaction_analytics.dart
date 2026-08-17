import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'firebase_runtime.dart';

typedef StoreKit2AnalyticsReadiness = Future<void> Function();

/// Bridges verified StoreKit 2 transactions to Firebase Analytics on iOS.
///
/// Firebase's native `Analytics.logTransaction` API needs the original
/// StoreKit transaction, so Dart passes the transaction ID to the native side
/// where the signed transaction is looked up and verified again.
class StoreKit2TransactionAnalytics {
  StoreKit2TransactionAnalytics({
    MethodChannel channel = const MethodChannel(
      'com.worldo.ai/firebase_analytics',
    ),
    StoreKit2AnalyticsReadiness? readiness,
    bool? enabled,
  }) : _channel = channel,
       _readiness = readiness ?? FirebaseRuntime.ensureInitialized,
       _enabled = enabled ?? kReleaseMode;

  final MethodChannel _channel;
  final StoreKit2AnalyticsReadiness _readiness;
  final bool _enabled;

  Future<bool> logVerifiedTransaction(String transactionId) async {
    final normalizedId = transactionId.trim();
    if (!_enabled ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        normalizedId.isEmpty) {
      return false;
    }
    try {
      await _readiness();
      return await _channel.invokeMethod<bool>('logStoreKit2Transaction', {
            'transactionId': normalizedId,
          }) ??
          false;
    } catch (error, stackTrace) {
      debugPrint(
        '[Telemetry][FirebaseAnalytics] StoreKit 2 transaction failed: '
        '$error',
      );
      debugPrint(
        '[Telemetry][FirebaseAnalytics] StoreKit 2 stacktrace:\n$stackTrace',
      );
      return false;
    }
  }
}
