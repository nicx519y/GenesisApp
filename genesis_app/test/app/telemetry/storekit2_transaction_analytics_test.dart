import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/storekit2_transaction_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test-storekit2-analytics');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('waits for Firebase and sends the StoreKit transaction ID', () async {
    final calls = <MethodCall>[];
    var ready = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(ready, isTrue);
          calls.add(call);
          return true;
        });
    final analytics = StoreKit2TransactionAnalytics(
      channel: channel,
      readiness: () async => ready = true,
      enabled: true,
    );

    expect(
      await analytics.logVerifiedTransaction(' 2000000123456789 '),
      isTrue,
    );
    expect(calls, hasLength(1));
    expect(calls.single.method, 'logStoreKit2Transaction');
    expect(calls.single.arguments, {'transactionId': '2000000123456789'});
  });

  test('does not call native code when collection is disabled', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    final analytics = StoreKit2TransactionAnalytics(
      channel: channel,
      readiness: () async {},
      enabled: false,
    );

    expect(await analytics.logVerifiedTransaction('2000000123456789'), isFalse);
    expect(calls, isEmpty);
  });

  test('rejects an empty ID without initializing Firebase', () async {
    var readinessCalls = 0;
    final analytics = StoreKit2TransactionAnalytics(
      channel: channel,
      readiness: () async => readinessCalls += 1,
      enabled: true,
    );

    expect(await analytics.logVerifiedTransaction('  '), isFalse);
    expect(readinessCalls, 0);
  });

  test('native failures remain best-effort', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'not_verified'),
        );
    final analytics = StoreKit2TransactionAnalytics(
      channel: channel,
      readiness: () async {},
      enabled: true,
    );

    expect(await analytics.logVerifiedTransaction('2000000123456789'), isFalse);
  });
}
