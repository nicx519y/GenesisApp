import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/startup/app_startup_coordinator.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

class _TestDeviceIdService implements DeviceIdService {
  const _TestDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'device-test-1';
}

class _FakeCollectClient implements CollectTelemetryClient {
  final List<Map<String, String>> headers = <Map<String, String>>[];

  @override
  Future<void> collectBatch(
    List<CollectEvent> events, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    this.headers.add(Map<String, String>.of(headers));
  }
}

class _ThrowingUidSessionStore extends MemoryUserSessionStore {
  @override
  Future<String?> readUid() async {
    throw StateError('UID read failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CollectTelemetryUploader uploader;
  late AppServices services;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    AppStartupCoordinator.configure(
      startedAt: DateTime.fromMillisecondsSinceEpoch(1),
      appVersion: const AppVersionInfo(versionName: '1.2.3'),
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    services.dispose();
    uploader.dispose();
    AppStartupCoordinator.resetForTesting();
    GenesisTelemetry.resetForTesting();
  });

  Future<_FakeCollectClient> initializeWith(
    MemoryUserSessionStore sessionStore,
  ) async {
    final client = _FakeCollectClient();
    uploader = CollectTelemetryUploader(
      store: MemoryCollectEventStore(),
      interval: const Duration(hours: 1),
    )..configure(enabled: true, client: client);
    GenesisTelemetry.setCollectUploaderForTesting(uploader);
    services = ServiceRegistry.build(
      config: const AppConfig(apiEnvironment: 'test', useMock: true),
      deviceIdOverride: const _TestDeviceIdService(),
      sessionStoreOverride: sessionStore,
    );
    AppStartupCoordinator.recordStartupFirstReport();

    await AppStartupCoordinator.initializeTelemetry(services: services);
    await _waitUntil(() => uploader.hasTimerForTesting);
    return client;
  }

  test('does not wait for the persisted UID before the first upload', () async {
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('user-123');

    final client = await initializeWith(sessionStore);

    expect(client.headers.single, isNot(contains('X-UID')));
  });

  test('starts Collect anonymously when there is no persisted UID', () async {
    final client = await initializeWith(MemoryUserSessionStore());

    expect(client.headers.single, isNot(contains('X-UID')));
  });

  test(
    'starts Collect without reading UID in telemetry initialization',
    () async {
      final client = await initializeWith(_ThrowingUidSessionStore());

      expect(client.headers.single, isNot(contains('X-UID')));
    },
  );
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      throw TimeoutException('Condition was not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}
