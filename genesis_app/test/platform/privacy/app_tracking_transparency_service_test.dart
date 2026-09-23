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
    var requested = false;

    final status = await AppTrackingTransparencyService.requestAuthorization(
      platform: TargetPlatform.android,
      request: () async {
        requested = true;
        return 3;
      },
    );

    expect(status, AppTrackingAuthorizationStatus.notSupported);
    expect(requested, false);
  });

  test('iOS request maps Adjust authorization status', () async {
    var requested = false;

    final status = await AppTrackingTransparencyService.requestAuthorization(
      platform: TargetPlatform.iOS,
      request: () async {
        requested = true;
        return 3;
      },
    );

    expect(status, AppTrackingAuthorizationStatus.authorized);
    expect(requested, true);
    expect(status.allowsTracking, true);
  });

  test(
    'iOS status maps native authorization status without requesting',
    () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return 'notDetermined';
          });

      final status = await AppTrackingTransparencyService.authorizationStatus(
        channel: channel,
        platform: TargetPlatform.iOS,
      );

      expect(status, AppTrackingAuthorizationStatus.notDetermined);
      expect(calls, [GenesisMethodChannels.trackingAuthorizationStatus]);
    },
  );

  test('denied Adjust authorization does not allow tracking', () async {
    final status = await AppTrackingTransparencyService.requestAuthorization(
      platform: TargetPlatform.iOS,
      request: () async => 2,
    );

    expect(status, AppTrackingAuthorizationStatus.denied);
    expect(status.allowsTracking, false);
  });

  test('unknown Adjust authorization values remain unknown', () async {
    final status = await AppTrackingTransparencyService.requestAuthorization(
      platform: TargetPlatform.iOS,
      request: () async => -1,
    );

    expect(status, AppTrackingAuthorizationStatus.unknown);
  });

  test('missing Adjust plugin returns unknown', () async {
    final status = await AppTrackingTransparencyService.requestAuthorization(
      platform: TargetPlatform.iOS,
      request: () async => throw MissingPluginException(),
    );

    expect(status, AppTrackingAuthorizationStatus.unknown);
  });
}
