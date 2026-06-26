import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:genesis_flutter_android/platform/privacy/app_tracking_transparency_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test-app-tracking-transparency');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('non iOS platforms do not request tracking authorization', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return 'authorized';
        });

    final status = await AppTrackingTransparencyService.requestAuthorization(
      channel: channel,
      platform: TargetPlatform.android,
    );

    expect(status, AppTrackingAuthorizationStatus.notSupported);
    expect(calls, isEmpty);
  });

  test('iOS request maps native authorization status', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return 'authorized';
        });

    final status = await AppTrackingTransparencyService.requestAuthorization(
      channel: channel,
      platform: TargetPlatform.iOS,
    );

    expect(status, AppTrackingAuthorizationStatus.authorized);
    expect(calls, [GenesisMethodChannels.requestTrackingAuthorization]);
    expect(status.allowsTracking, true);
  });

  test('denied native authorization does not allow tracking', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'denied');

    final status = await AppTrackingTransparencyService.requestAuthorization(
      channel: channel,
      platform: TargetPlatform.iOS,
    );

    expect(status, AppTrackingAuthorizationStatus.denied);
    expect(status.allowsTracking, false);
  });
}
