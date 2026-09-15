import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/startup/startup_endpoint_config.dart';

void main() {
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
