import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/app_request_headers.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';

void main() {
  test('builds system user agent header', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(
        packageName: 'com.worldo.ai',
        versionName: '0.1.0',
        versionCode: '1',
      ),
      platformResolver: () => 'android',
      systemUserAgentLoader: () async => 'Android 15',
      systemLanguageLoader: () async => 'zh-CN',
    );

    expect(await provider.headers(), {
      'user-agent': 'Android 15',
      'x-system-language': 'zh-CN',
    });
  });

  test('omits blank or unavailable system header values', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(
        packageName: 'com.worldo.ai',
        versionName: '0.1.0',
        versionCode: '1',
      ),
      platformResolver: () => 'android',
      systemUserAgentLoader: () async => ' ',
      systemLanguageLoader: () async => throw StateError('unavailable'),
    );

    expect(await provider.headers(), isEmpty);
  });

  test('builds encrypted Gateway identity for Android metadata', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(
        packageName: 'com.worldo.ai',
        versionName: '0.1.0',
        versionCode: '1',
      ),
      platformResolver: () => 'android',
    );

    final identity = await provider.gatewayIdentity();

    expect(
      identity.appId,
      'e9f755211fb782263f711c55de8f82f53a64c71fbdb6fd7e133754ee66cace03',
    );
    expect(identity.appVersion, '0.1.0');
    expect(identity.platform, 'android');
  });

  test('builds iOS Gateway identity from bundle metadata', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(
        packageName: 'com.worldo.ai',
        versionName: '0.1.0',
      ),
      platformResolver: () => 'ios',
    );

    final identity = await provider.gatewayIdentity();

    expect(identity.platform, 'ios');
    expect(identity.appVersion, '0.1.0');
    expect(identity.appId, isNotEmpty);
  });

  test('omits app id and version when metadata is unavailable', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(),
      platformResolver: () => null,
    );

    final identity = await provider.gatewayIdentity();

    expect(identity.appId, isEmpty);
    expect(identity.appVersion, isEmpty);
    expect(identity.platform, isEmpty);
  });
}
