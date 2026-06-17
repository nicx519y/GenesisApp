import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/app_request_headers.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';

void main() {
  test('builds encrypted app headers for Android metadata', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(
        packageName: 'com.worldo.ai',
        versionName: '0.1.0',
        versionCode: '1',
      ),
      platformResolver: () => 'android',
    );

    expect(await provider.headers(), {
      'app-id':
          'e9f755211fb782263f711c55de8f82f53a64c71fbdb6fd7e133754ee66cace03',
      'app-version': '0.1.0',
      'app-platform': 'android',
    });
  });

  test('builds iOS platform header from bundle metadata', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(
        packageName: 'com.worldo.ai',
        versionName: '0.1.0',
      ),
      platformResolver: () => 'ios',
    );

    final headers = await provider.headers();

    expect(headers['app-platform'], 'ios');
    expect(headers['app-version'], '0.1.0');
    expect(headers['app-id'], isNotEmpty);
  });

  test('omits app id and version when metadata is unavailable', () async {
    final provider = AppRequestHeaderProvider(
      appVersionLoader: () async => const AppVersionInfo(),
      platformResolver: () => null,
    );

    expect(await provider.headers(), isEmpty);
  });
}
