import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/app_request_headers.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';
import 'package:genesis_flutter_android/platform/app/app_version_override_store.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GenesisMethodChannels.device, (call) async {
          if (call.method == GenesisMethodChannels.getAppVersion) {
            return <String, Object>{
              'versionName': '0.4.1',
              'versionCode': 5,
              'packageName': 'com.worldo.ai',
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GenesisMethodChannels.device, null);
  });

  test('uses persisted runtime version overrides', () async {
    await AppVersionOverrideStore.save(
      const AppVersionOverrides(versionName: '0.3.0', versionCode: '12'),
    );

    final version = await AppMetadataService.appVersion();

    expect(version.versionName, '0.3.0');
    expect(version.versionCode, '12');
    expect(version.packageName, 'com.worldo.ai');
  });

  test('clearing overrides restores build metadata', () async {
    await AppVersionOverrideStore.save(
      const AppVersionOverrides(versionName: '0.3.0', versionCode: '12'),
    );
    await AppVersionOverrideStore.clear();

    final version = await AppMetadataService.appVersion();

    expect(version.versionName, '0.4.1');
    expect(version.versionCode, '5');
  });

  test('new request metadata uses runtime overrides', () async {
    await AppVersionOverrideStore.save(
      const AppVersionOverrides(versionName: '0.3.0', versionCode: '12'),
    );
    final provider = AppRequestHeaderProvider(
      platformResolver: () => 'ios',
      systemUserAgentLoader: () async => '',
      systemLanguageLoader: () async => '',
      appTimeZoneLoader: () async => '',
    );

    expect(await provider.headers(), {'x-app-version-code': '12'});
    expect((await provider.gatewayIdentity()).appVersion, '0.3.0');
  });

  test('rejects a non-positive version code', () async {
    expect(
      () => AppVersionOverrideStore.save(
        const AppVersionOverrides(versionName: '0.3.0', versionCode: '0'),
      ),
      throwsFormatException,
    );
  });
}
