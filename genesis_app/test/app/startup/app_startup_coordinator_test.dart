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

class _NeverCompletingDeviceIdService implements DeviceIdService {
  _NeverCompletingDeviceIdService(this.calls);

  final List<String> calls;

  @override
  Future<String> getDeviceId() {
    calls.add('device_id');
    return Completer<String>().future;
  }
}

class _RetryingDeviceIdService implements DeviceIdService {
  int calls = 0;

  @override
  Future<String> getDeviceId() {
    calls += 1;
    if (calls == 1) return Completer<String>().future;
    return Future<String>.value('device-recovered');
  }
}

class _FakeCollectClient implements CollectTelemetryClient {
  _FakeCollectClient({this.onCollect});

  final VoidCallback? onCollect;
  final List<Map<String, String>> headers = <Map<String, String>>[];

  @override
  Future<void> collectBatch(
    List<CollectEvent> events, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    onCollect?.call();
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
    MemoryUserSessionStore sessionStore, {
    DeviceIdService deviceIdService = const _TestDeviceIdService(),
    Future<AppVersionInfo> Function()? appVersionReader,
    Duration appVersionTimeout = const Duration(seconds: 1),
    Duration deviceIdTimeout = const Duration(seconds: 2),
    List<Duration> metadataRetryDelays = const <Duration>[],
    VoidCallback? onCollect,
  }) async {
    final client = _FakeCollectClient(onCollect: onCollect);
    uploader = CollectTelemetryUploader(
      store: MemoryCollectEventStore(),
      interval: const Duration(hours: 1),
    )..configure(enabled: true, client: client);
    GenesisTelemetry.setCollectUploaderForTesting(uploader);
    services = ServiceRegistry.build(
      config: const AppConfig(apiEnvironment: 'test', useMock: true),
      deviceIdOverride: deviceIdService,
      sessionStoreOverride: sessionStore,
    );
    AppStartupCoordinator.recordStartupFirstReport();

    await AppStartupCoordinator.initializeTelemetry(
      services: services,
      appVersionReader: appVersionReader,
      appVersionTimeout: appVersionTimeout,
      deviceIdTimeout: deviceIdTimeout,
      metadataRetryDelays: metadataRetryDelays,
    );
    await _waitUntil(() => uploader.hasTimerForTesting);
    return client;
  }

  test('does not wait for the persisted UID before the first upload', () async {
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('user-123');

    final client = await initializeWith(sessionStore);

    expect(client.headers, isNotEmpty);
    expect(
      client.headers.every((headers) => !headers.containsKey('X-UID')),
      isTrue,
    );
  });

  test('starts Collect anonymously when there is no persisted UID', () async {
    final client = await initializeWith(MemoryUserSessionStore());

    expect(client.headers, isNotEmpty);
    expect(
      client.headers.every((headers) => !headers.containsKey('X-UID')),
      isTrue,
    );
  });

  test(
    'starts Collect without reading UID in telemetry initialization',
    () async {
      final client = await initializeWith(_ThrowingUidSessionStore());

      expect(client.headers, isNotEmpty);
      expect(
        client.headers.every((headers) => !headers.containsKey('X-UID')),
        isTrue,
      );
    },
  );

  test('metadata timeouts do not block Collect startup', () async {
    AppStartupCoordinator.configure();
    final calls = <String>[];

    final client = await initializeWith(
      MemoryUserSessionStore(),
      appVersionReader: () {
        calls.add('app_version');
        return Completer<AppVersionInfo>().future;
      },
      deviceIdService: _NeverCompletingDeviceIdService(calls),
      appVersionTimeout: const Duration(milliseconds: 5),
      deviceIdTimeout: const Duration(milliseconds: 5),
      onCollect: () => calls.add('collect'),
    );

    expect(calls, <String>['app_version', 'device_id', 'collect']);
    expect(uploader.isStartedForTesting, isTrue);
    expect(client.headers, isNotEmpty);
    expect(
      client.headers.every((headers) => !headers.containsKey('X-Device-ID')),
      isTrue,
    );
  });

  test('missing metadata is retried without clearing the user id', () async {
    final deviceIdService = _RetryingDeviceIdService();
    final client = await initializeWith(
      MemoryUserSessionStore(),
      deviceIdService: deviceIdService,
      deviceIdTimeout: const Duration(milliseconds: 5),
      metadataRetryDelays: const <Duration>[Duration(milliseconds: 20)],
    );
    GenesisTelemetry.setUserId('user-after-start');

    await _waitUntil(
      () => GenesisTelemetry.contextForTesting.deviceId == 'device-recovered',
    );
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'metadata_retry_test',
    );
    await GenesisTelemetry.waitForCollectWritesForTesting();
    await uploader.checkNow(force: true);

    expect(deviceIdService.calls, 2);
    expect(client.headers.last['X-Device-ID'], 'device-recovered');
    expect(client.headers.last['X-UID'], 'user-after-start');
  });
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
