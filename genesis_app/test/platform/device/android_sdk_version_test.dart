import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:genesis_flutter_android/platform/device/android_sdk_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    resetAndroidSdkIntForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GenesisMethodChannels.device, null);
  });

  test(
    'loads and caches the Android SDK level from the device channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GenesisMethodChannels.device, (call) async {
            expect(call.method, GenesisMethodChannels.getAndroidSdkInt);
            calls += 1;
            return 30;
          });

      expect(await loadAndroidSdkInt(), 30);
      expect(await loadAndroidSdkInt(), 30);
      expect(cachedAndroidSdkInt, 30);
      expect(calls, 1);
    },
  );

  test('does not query the device channel outside Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await loadAndroidSdkInt(), isNull);
    expect(cachedAndroidSdkInt, isNull);
  });
}
