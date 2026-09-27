import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/app_endpoint_overrides.dart';
import 'package:genesis_flutter_android/app/startup/startup_endpoint_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'QA real-data build uses its configured domain over saved developer overrides',
    () async {
      const expectedApi = String.fromEnvironment('GENESIS_QA_API_BASE_URL');
      if (expectedApi.isEmpty) return;
      SharedPreferences.setMockInitialValues({
        'developer_api_base_url_override_v1': 'https://other.example.com/api/',
      });
      const config = AppConfig();
      expect(config.apiBaseUrl, expectedApi);
      expect(
        config.gatewayApiBaseUrl,
        const String.fromEnvironment('GENESIS_QA_GATEWAY_API_BASE_URL'),
      );
      expect(
        config.chatroomHttpBaseUrl,
        const String.fromEnvironment('GENESIS_QA_CHATROOM_HTTP_BASE_URL'),
      );
      expect(
        config.chatroomWsBaseUrl,
        const String.fromEnvironment('GENESIS_QA_CHATROOM_WS_URL'),
      );
      expect(
        (await AppEndpointOverrideStore.loadConfig()).apiBaseUrl,
        expectedApi,
      );
    },
  );
  test('keeps successfully loaded endpoint config', () async {
    const config = AppConfig(apiBaseUrl: 'https://example.test/api/');
    expect(
      await loadStartupEndpointConfig(load: () async => config),
      same(config),
    );
  });
  test('storage error falls back without aborting startup', () async {
    final config = await loadStartupEndpointConfig(
      load: () => throw StateError('storage'),
    );
    expect(config.apiBaseUrl, const AppConfig().apiBaseUrl);
  });
  test('timeout falls back and ignores a late error', () async {
    final pending = Completer<AppConfig>();
    final config = await loadStartupEndpointConfig(
      load: () => pending.future,
      timeout: const Duration(milliseconds: 1),
    );
    expect(config.apiBaseUrl, const AppConfig().apiBaseUrl);
    pending.completeError(StateError('late'));
    await Future<void>.delayed(Duration.zero);
  });
}
