import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/telemetry/telemetry_upload_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const productionConfig = AppConfig(
    apiBaseUrl: 'https://api.worldo.ai/api/',
    gatewayApiBaseUrl: 'https://api.worldo.ai/apix/',
    chatroomHttpBaseUrl: 'https://api.worldo.ai/',
    chatroomWsBaseUrl: 'wss://api.worldo.ai/aitown-chat/ws',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TelemetryUploadPolicy.resetForTesting();
  });

  tearDown(TelemetryUploadPolicy.resetForTesting);

  test('production release with official endpoints uploads automatically', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig,
      isReleaseBuild: true,
      isProductionFlavor: true,
      debugOverrides: const TelemetryDebugOverrides.none(),
    );

    expect(state.automaticEnabled, isTrue);
    expect(state.collectEnabled, isTrue);
    expect(state.analyticsEnabled, isTrue);
    expect(state.performanceEnabled, isTrue);
    expect(state.crashlyticsEnabled, isTrue);
    expect(state.appEnvironment, 'production');
    expect(state.blockReason, TelemetryUploadBlockReason.none);
  });

  test('debug build is blocked by default', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig,
      isReleaseBuild: false,
      isProductionFlavor: true,
      debugOverrides: const TelemetryDebugOverrides.none(),
    );

    expect(state.collectEnabled, isFalse);
    expect(state.appEnvironment, 'test');
    expect(state.blockReason, TelemetryUploadBlockReason.nonReleaseBuild);
  });

  test('internal release is blocked by default', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig,
      isReleaseBuild: true,
      isProductionFlavor: false,
      debugOverrides: const TelemetryDebugOverrides.none(),
    );

    expect(state.analyticsEnabled, isFalse);
    expect(state.blockReason, TelemetryUploadBlockReason.internalFlavor);
  });

  test('production release keeps Performance on after switching endpoints', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig.copyWith(
        chatroomWsBaseUrl: 'wss://dev.hushie.ai/aitown-chat/ws',
      ),
      isReleaseBuild: true,
      isProductionFlavor: true,
      debugOverrides: const TelemetryDebugOverrides.none(),
    );

    expect(state.usesOfficialEndpoints, isFalse);
    expect(state.automaticEnabled, isFalse);
    expect(state.collectEnabled, isFalse);
    expect(state.analyticsEnabled, isFalse);
    expect(state.performanceEnabled, isTrue);
    expect(state.crashlyticsEnabled, isFalse);
    expect(state.blockReason, TelemetryUploadBlockReason.nonProductionEndpoint);
  });

  test('custom port is not treated as an official endpoint', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig.copyWith(
        apiBaseUrl: 'https://api.worldo.ai:8443/api/',
      ),
      isReleaseBuild: true,
      isProductionFlavor: true,
      debugOverrides: const TelemetryDebugOverrides.none(),
    );

    expect(state.usesOfficialEndpoints, isFalse);
    expect(state.crashlyticsEnabled, isFalse);
  });

  test('one debug override enables only that channel and marks test', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig,
      isReleaseBuild: false,
      isProductionFlavor: true,
      debugOverrides: const TelemetryDebugOverrides(collect: true),
    );

    expect(state.automaticEnabled, isFalse);
    expect(state.collectEnabled, isTrue);
    expect(state.analyticsEnabled, isFalse);
    expect(state.performanceEnabled, isFalse);
    expect(state.crashlyticsEnabled, isFalse);
    expect(state.appEnvironment, 'test');
  });

  test('debug override marks internal release data as test', () {
    final state = evaluateTelemetryUploadPolicy(
      config: productionConfig,
      isReleaseBuild: true,
      isProductionFlavor: false,
      debugOverrides: const TelemetryDebugOverrides(analytics: true),
    );

    expect(state.analyticsEnabled, isTrue);
    expect(state.collectEnabled, isFalse);
    expect(state.appEnvironment, 'test');
  });

  test('persisted debug override defaults off and saves changes', () async {
    final initial = await TelemetryUploadPolicy.initialize(productionConfig);
    expect(initial.debugOverrides.anyEnabled, isFalse);

    final updated = await TelemetryUploadPolicy.setDebugOverrideEnabled(
      TelemetryChannel.analytics,
      enabled: true,
    );
    final preferences = await SharedPreferences.getInstance();

    expect(updated.debugOverrides.analytics, isTrue);
    expect(updated.debugOverrides.collect, isFalse);
    expect(
      preferences.getBool(
        SharedPreferencesTelemetryDebugOverrideStore.analyticsStorageKey,
      ),
      isTrue,
    );
  });
}
