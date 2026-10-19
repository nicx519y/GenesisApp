import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:genesis_flutter_android/platform/device/android_advertising_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GenesisMethodChannels.device, null);
  });

  test(
    'reads the current advertising ID through the Android device channel',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GenesisMethodChannels.device, (call) async {
            expect(call.method, GenesisMethodChannels.getGoogleAdvertisingId);
            return 'current-gaid';
          });

      expect(await readGoogleAdvertisingIdFromPlatform(), 'current-gaid');
    },
  );
}
