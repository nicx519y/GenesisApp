import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/startup/app_startup_coordinator.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/app/app_metadata_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeCollectClient implements CollectTelemetryClient {
  _FakeCollectClient({this.onCollect});

  final Future<void> Function(List<CollectEvent> events)? onCollect;
  final List<List<CollectEvent>> batches = <List<CollectEvent>>[];
  final List<Map<String, String>> headers = <Map<String, String>>[];

  @override
  Future<void> collectBatch(
    List<CollectEvent> events, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    batches.add(List<CollectEvent>.of(events));
    this.headers.add(Map<String, String>.of(headers));
    await onCollect?.call(events);
  }
}

class _FakeTransport implements HttpTransport {
  _FakeTransport(this.response);

  TransportResponse response;
  final List<TransportRequest> requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return response;
  }
}

class _TestDeviceIdService implements DeviceIdService {
  const _TestDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'device-test-1';
}

class _CapturingTelemetrySink implements GenesisTelemetrySink {
  final List<GenesisTelemetryEvent> events = <GenesisTelemetryEvent>[];

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}

void main() {
  final uploaders = <CollectTelemetryUploader>[];

  CollectTelemetryUploader uploader({
    required CollectEventStore store,
    required CollectTelemetryClient client,
    Duration interval = const Duration(hours: 1),
    int batchSize = defaultCollectUploadBatchSize,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) {
    final value = CollectTelemetryUploader(
      store: store,
      interval: interval,
      batchSize: batchSize,
      clock: clock,
      idGenerator: idGenerator,
    )..configure(enabled: true, client: client);
    uploaders.add(value);
    return value;
  }

  tearDown(() {
    for (final uploader in uploaders) {
      uploader.dispose();
    }
    uploaders.clear();
    AppStartupCoordinator.resetForTesting();
    GenesisTelemetry.resetForTesting();
  });

  test('event stores timestamp and stable wire fields before upload', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient();
    final value = uploader(
      store: store,
      client: client,
      clock: () => DateTime.fromMillisecondsSinceEpoch(1784692855123),
      idGenerator: () => 'event-1',
    );

    await value.enqueuePayload(const <String, Object?>{
      'action_type': 'pageview',
      'action': 'home_my_worlds',
      'object1': 'w_1',
    });

    final event = store.eventsForTesting.single;
    expect(event.toWireMap(), <String, Object>{
      'event_id': 'event-1',
      'action_type': 'pageview',
      'action': 'home_my_worlds',
      'app_timestamp': 1784692855123,
      'object1': 'w_1',
      'object2': '',
      'object3': '',
    });
    expect(client.batches, isEmpty);
  });

  test('disabled uploader neither persists nor uploads events', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient();
    final value = CollectTelemetryUploader(store: store)
      ..configure(enabled: false, client: client);
    uploaders.add(value);

    await value.enqueuePayload(const <String, Object?>{
      'action_type': 'pageview',
      'action': 'disabled',
    });
    value.start();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(store.eventsForTesting, isEmpty);
    expect(client.batches, isEmpty);
    expect(value.isStartedForTesting, isFalse);
  });

  for (final config in <AppConfig>[
    const AppConfig(
      collectEnabled: false,
      collectEndpoint: 'https://collect.worldo.ai/api/v1/collect',
    ),
    const AppConfig(
      collectEnabled: true,
      collectEndpoint: 'https://collect.worldo.ai/api/v1/collect',
      useMock: true,
    ),
  ]) {
    final mode = config.useMock == true ? 'mock' : 'disabled';
    test('$mode config does not record Collect events', () async {
      final store = MemoryCollectEventStore();
      final value = CollectTelemetryUploader(store: store);
      uploaders.add(value);
      GenesisTelemetry.setCollectUploaderForTesting(value, prepared: false);
      GenesisTelemetry.prepareCollect(config);

      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'must_not_persist',
      );
      await GenesisTelemetry.waitForCollectWritesForTesting();
      GenesisTelemetry.startCollectUploader();

      expect(store.eventsForTesting, isEmpty);
      expect(value.isStartedForTesting, isFalse);
    });
  }

  test('start performs first check then starts timer', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient();
    final value = uploader(store: store, client: client);
    await value.enqueuePayload(const <String, Object?>{
      'action_type': 'event',
      'action': 'startup_first_report',
    });

    value.start();
    await _waitUntil(() => value.hasTimerForTesting);

    expect(client.batches, hasLength(1));
    expect(client.batches.single.single.action, 'startup_first_report');
    expect(store.eventsForTesting, isEmpty);
  });

  test('one check claims only the oldest 500 events', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient();
    var nextId = 0;
    final value = uploader(
      store: store,
      client: client,
      idGenerator: () => 'event-${nextId++}',
    );
    for (var index = 0; index < 501; index += 1) {
      await value.enqueuePayload(<String, Object?>{
        'action_type': 'event',
        'action': 'event_$index',
      });
    }

    value.start();
    await _waitUntil(() => value.hasTimerForTesting);

    expect(client.batches.single, hasLength(500));
    expect(client.batches.single.first.action, 'event_0');
    expect(client.batches.single.last.action, 'event_499');
    expect(store.pendingCountForTesting, 1);
  });

  test('failed upload releases claimed events for retry', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient(
      onCollect: (_) async => throw StateError('network failed'),
    );
    final value = uploader(store: store, client: client);
    await value.enqueuePayload(const <String, Object?>{
      'action_type': 'event',
      'action': 'retry_me',
    });

    value.start();
    await _waitUntil(() => value.hasTimerForTesting);

    expect(store.pendingCountForTesting, 1);
    expect(store.inFlightCountForTesting, 0);
    expect(
      store.eventsForTesting.single.eventId,
      client.batches.single.single.eventId,
    );
  });

  test('timed out upload releases the whole batch for retry', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient(
      onCollect: (_) async => throw TimeoutException('collect timeout'),
    );
    final value = uploader(store: store, client: client);
    await value.enqueuePayload(const <String, Object?>{
      'action_type': 'event',
      'action': 'retry_after_timeout',
    });

    value.start();
    await _waitUntil(() => value.hasTimerForTesting);

    expect(store.pendingCountForTesting, 1);
    expect(store.inFlightCountForTesting, 0);
  });

  test(
    'startup recovers an in-flight batch from the previous process',
    () async {
      final store = MemoryCollectEventStore();
      await store.enqueue(
        const CollectEvent(
          eventId: 'persisted-event',
          actionType: 'event',
          action: 'persisted',
          appTimestamp: 1,
          object1: '',
          object2: '',
          object3: '',
        ),
      );
      await store.claimPending(limit: 500);
      expect(store.inFlightCountForTesting, 1);
      final client = _FakeCollectClient();
      final value = uploader(store: store, client: client);

      value.start();
      await _waitUntil(() => value.hasTimerForTesting);

      expect(client.batches.single.single.eventId, 'persisted-event');
      expect(store.eventsForTesting, isEmpty);
    },
  );

  test('SQLite queue survives reopen and recovers in-flight rows', () async {
    sqfliteFfiInit();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'genesis-collect-test-',
    );
    final databasePath = '${tempDirectory.path}/collect.db';
    final firstStore = SqfliteCollectEventStore(
      databaseFactoryOverride: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await firstStore.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    await firstStore.enqueue(
      const CollectEvent(
        eventId: 'sqlite-event',
        actionType: 'event',
        action: 'persisted',
        appTimestamp: 1,
        object1: '',
        object2: '',
        object3: '',
      ),
    );
    await firstStore.claimPending(limit: 500);
    await firstStore.close();

    final reopenedStore = SqfliteCollectEventStore(
      databaseFactoryOverride: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(reopenedStore.close);
    await reopenedStore.recoverInFlight();
    final recovered = await reopenedStore.claimPending(limit: 500);

    expect(recovered?.events.single.eventId, 'sqlite-event');
  });

  test('concurrent checks do not overlap an active request', () async {
    final response = Completer<void>();
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient(onCollect: (_) => response.future);
    final value = uploader(store: store, client: client);
    await value.enqueuePayload(const <String, Object?>{
      'action_type': 'event',
      'action': 'slow_event',
    });

    value.start();
    await _waitUntil(() => client.batches.isNotEmpty);
    await value.checkNow();
    expect(client.batches, hasLength(1));

    response.complete();
    await _waitUntil(() => value.hasTimerForTesting);
  });

  test(
    'app resume checks immediately and restarts the timer cadence',
    () async {
      final store = MemoryCollectEventStore();
      final client = _FakeCollectClient();
      final value = uploader(store: store, client: client);

      value.start();
      await _waitUntil(() => value.hasTimerForTesting);
      await value.enqueuePayload(const <String, Object?>{
        'action_type': 'event',
        'action': 'after_resume',
      });

      value.handleAppResumed();
      await _waitUntil(
        () => client.batches.length == 1 && value.hasTimerForTesting,
      );

      expect(client.batches.single.single.action, 'after_resume');
    },
  );

  test(
    'startup first report is queued before initialize without consumption',
    () async {
      final store = MemoryCollectEventStore();
      final client = _FakeCollectClient();
      final value = uploader(store: store, client: client);
      GenesisTelemetry.setCollectUploaderForTesting(value);
      GenesisTelemetry.prepareCollect(const AppConfig(apiEnvironment: 'test'));
      AppStartupCoordinator.recordStartupFirstReport();
      AppStartupCoordinator.recordStartupFirstReport();
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'home_my_worlds',
      );
      await GenesisTelemetry.waitForCollectWritesForTesting();

      await GenesisTelemetry.initialize(
        config: const AppConfig(apiEnvironment: 'test'),
        deviceIdService: const _TestDeviceIdService(),
        appVersion: const AppVersionInfo(versionName: '1.2.3'),
      );

      expect(client.batches, isEmpty);
      expect(value.isStartedForTesting, isFalse);
      GenesisTelemetry.startCollectUploader();
      await _waitUntil(() => value.hasTimerForTesting);
      expect(client.batches.single.map((event) => event.action), <String>[
        'startup_first_report',
        'home_my_worlds',
      ]);
    },
  );

  test('event collectPayload queues while sink remains immediate', () async {
    final store = MemoryCollectEventStore();
    final client = _FakeCollectClient();
    final value = uploader(store: store, client: client);
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setCollectUploaderForTesting(value);
    GenesisTelemetry.setSinkForTesting(sink);

    GenesisTelemetry.event(
      'billing_purchase_completed',
      category: 'billing',
      collectPayload: const <String, Object?>{
        'action_type': 'pay_event',
        'action': 'billing_purchase_completed',
        'object1': 'sku_1',
      },
    );
    await GenesisTelemetry.waitForCollectWritesForTesting();
    await _waitUntil(() => sink.events.isNotEmpty);

    expect(sink.events.single.name, 'billing_purchase_completed');
    expect(client.batches, isEmpty);
    expect(store.pendingCountForTesting, 1);

    GenesisTelemetry.startCollectUploader();
    await _waitUntil(() => value.hasTimerForTesting);
    expect(client.batches.single.single.actionType, 'pay_event');
    expect(client.batches.single.single.object1, 'sku_1');
  });

  test('Sdk client posts batch envelope and requires err_no zero', () async {
    final transport = _FakeTransport(
      const TransportResponse(
        statusCode: 200,
        headers: <String, String>{},
        body: '{"err_no":0,"err_msg":"succ"}',
      ),
    );
    final client = SdkCollectTelemetryClient(
      endpoint: 'https://collect.worldo.ai/api/v1/collect',
      transport: transport,
      timeoutMs: 1234,
    );
    const event = CollectEvent(
      eventId: 'event-1',
      actionType: 'event',
      action: 'world_progress_submit_success',
      appTimestamp: 123,
      object1: 'w_1',
      object2: '12',
      object3: '',
    );

    await client.collectBatch(
      const <CollectEvent>[event],
      headers: const <String, String>{'X-Platform': 'ios'},
    );

    final request = transport.requests.single;
    expect(request.timeoutMs, 1234);
    expect(request.headers['X-Platform'], 'ios');
    expect(jsonDecode(utf8.decode(request.bodyBytes!)), <String, Object?>{
      'events': <Object?>[event.toWireMap()],
    });

    transport.response = const TransportResponse(
      statusCode: 200,
      headers: <String, String>{},
      body: '{"err_no":"0"}',
    );
    await client.collectBatch(const <CollectEvent>[event]);

    transport.response = const TransportResponse(
      statusCode: 200,
      headers: <String, String>{},
      body: '{"err_no":1001}',
    );
    await expectLater(
      client.collectBatch(const <CollectEvent>[event]),
      throwsStateError,
    );
    transport.response = const TransportResponse(
      statusCode: 200,
      headers: <String, String>{},
      body: 'not-json',
    );
    await expectLater(
      client.collectBatch(const <CollectEvent>[event]),
      throwsFormatException,
    );
    transport.response = const TransportResponse(
      statusCode: 500,
      headers: <String, String>{},
      body: '{"err_no":0}',
    );
    await expectLater(
      client.collectBatch(const <CollectEvent>[event]),
      throwsStateError,
    );
  });

  test('generated event ids are RFC 4122 version 4 UUIDs', () {
    expect(
      newCollectEventId(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}
