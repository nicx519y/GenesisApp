import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/app_event_reporting.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('sqflite outbox persists pending and delivered state', () async {
    sqfliteFfiInit();
    final store = SqfliteAppEventReportStore(
      databaseFactoryOverride: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    const report = AppEventReport(
      event: 'login_first',
      environment: 'sandbox',
      occurredAtSeconds: 1767225600,
      params: <String, String>{'method': 'google', 'device_id': 'device-1'},
      reportKey: 'report-1',
    );

    await store.enqueue(report);
    await store.enqueue(report);
    expect(await store.pending(limit: 20), hasLength(1));
    await store.markDelivered(report.reportKey);
    expect(await store.pending(limit: 20), isEmpty);
    await store.close();
  });

  test('sqflite v1 outbox migrates pending rows with occurred_at', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'genesis-event-report-migration-',
    );
    final databasePath = '${directory.path}/reports.db';
    addTearDown(() async {
      await databaseFactoryFfiNoIsolate.deleteDatabase(databasePath);
      await directory.delete(recursive: true);
    });
    final legacyDatabase = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => database.execute('''
CREATE TABLE app_event_reports (
  sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_key TEXT NOT NULL UNIQUE,
  event_name TEXT NOT NULL,
  environment TEXT NOT NULL,
  business_id TEXT,
  params_json TEXT NOT NULL,
  delivered INTEGER NOT NULL DEFAULT 0
)
'''),
      ),
    );
    await legacyDatabase.insert('app_event_reports', <String, Object?>{
      'report_key': 'legacy-report',
      'event_name': 'login_first',
      'environment': 'sandbox',
      'params_json': '{"method":"google"}',
      'delivered': 0,
    });
    await legacyDatabase.close();

    final store = SqfliteAppEventReportStore(
      databaseFactoryOverride: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    final pending = await store.pending(limit: 20);

    expect(pending, hasLength(1));
    expect(pending.single.reportKey, 'legacy-report');
    expect(pending.single.occurredAtSeconds, greaterThan(0));
    await store.close();
  });

  test('sqflite v2 outbox converts occurred_at micros to seconds', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'genesis-event-report-micros-migration-',
    );
    final databasePath = '${directory.path}/reports.db';
    addTearDown(() async {
      await databaseFactoryFfiNoIsolate.deleteDatabase(databasePath);
      await directory.delete(recursive: true);
    });
    final legacyDatabase = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, _) => database.execute('''
CREATE TABLE app_event_reports (
  sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_key TEXT NOT NULL UNIQUE,
  event_name TEXT NOT NULL,
  environment TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  business_id TEXT,
  params_json TEXT NOT NULL,
  delivered INTEGER NOT NULL DEFAULT 0
)
'''),
      ),
    );
    await legacyDatabase.insert('app_event_reports', <String, Object?>{
      'report_key': 'legacy-micros-report',
      'event_name': 'login_first',
      'environment': 'sandbox',
      'occurred_at': 1767225600123456,
      'params_json': '{"method":"google"}',
      'delivered': 0,
    });
    await legacyDatabase.close();

    final store = SqfliteAppEventReportStore(
      databaseFactoryOverride: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    final pending = await store.pending(limit: 20);

    expect(pending, hasLength(1));
    expect(pending.single.occurredAtSeconds, 1767225600);
    await store.close();
  });

  test('sqflite v3 outbox migrates prefixed business id', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'genesis-event-report-transaction-migration-',
    );
    final databasePath = '${directory.path}/reports.db';
    addTearDown(() async {
      await databaseFactoryFfiNoIsolate.deleteDatabase(databasePath);
      await directory.delete(recursive: true);
    });
    final legacyDatabase = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (database, _) => database.execute('''
CREATE TABLE app_event_reports (
  sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_key TEXT NOT NULL UNIQUE,
  event_name TEXT NOT NULL,
  environment TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  business_id TEXT,
  params_json TEXT NOT NULL,
  delivered INTEGER NOT NULL DEFAULT 0
)
'''),
      ),
    );
    await legacyDatabase.insert('app_event_reports', <String, Object?>{
      'report_key': 'legacy-business-id-report',
      'event_name': 'subscription_first_day0',
      'environment': 'sandbox',
      'occurred_at': 1767225600,
      'business_id': 'subscription:2000000123456789',
      'params_json': '{"device_id":"device-1"}',
      'delivered': 0,
    });
    await legacyDatabase.close();

    final store = SqfliteAppEventReportStore(
      databaseFactoryOverride: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    final pending = await store.pending(limit: 20);

    expect(pending, hasLength(1));
    expect(pending.single.transactionId, '2000000123456789');
    await store.close();
  });

  test(
    'reports only the selected events with Firebase-equivalent params',
    () async {
      final store = _MemoryAppEventReportStore();
      final sent = <AppEventReport>[];
      final reporting = AppEventReporting(
        environmentProvider: () => 'sandbox',
        store: store,
        sender: (report) async => sent.add(report),
        initialRetryDelay: const Duration(hours: 1),
        maximumRetryDelay: const Duration(hours: 1),
      );

      await reporting.report(
        event: 'gems',
        occurredAtSeconds: 1767225600,
        transactionId: 'order-1',
        parameters: const <String, Object>{
          'provider': 'google',
          'product_id': 'gems-500',
          'device_id': 'device-1',
          'value': 4.99,
          'currency': 'USD',
        },
      );
      await reporting.report(
        event: 'login_first',
        occurredAtSeconds: 1767225600,
        transactionId: 'must-be-ignored',
        parameters: const <String, Object>{
          'method': 'google',
          'device_id': 'device-1',
        },
      );
      await reporting.report(
        event: 'subscription_renew',
        occurredAtSeconds: 1767225600,
        transactionId: 'renewal-1',
        parameters: const <String, Object>{'device_id': 'device-1'},
      );
      await reporting.flush();

      expect(sent.map((report) => report.event), ['gems', 'login_first']);
      expect(sent.first.transactionId, 'order-1');
      expect(sent.first.occurredAtSeconds, 1767225600);
      expect(sent.first.params, const <String, String>{
        'provider': 'google',
        'product_id': 'gems-500',
        'device_id': 'device-1',
        'value': '4.99',
        'currency': 'USD',
      });
      expect(sent.last.transactionId, isNull);
      expect(sent.last.params, const <String, String>{
        'method': 'google',
        'device_id': 'device-1',
      });
      await reporting.dispose();
    },
  );

  test('failed reports stay queued and later flush exactly once', () async {
    final store = _MemoryAppEventReportStore();
    var attempts = 0;
    final sent = <AppEventReport>[];
    final reporting = AppEventReporting(
      environmentProvider: () => 'production',
      store: store,
      sender: (report) async {
        attempts += 1;
        if (attempts == 1) throw StateError('offline');
        sent.add(report);
      },
      initialRetryDelay: const Duration(hours: 1),
      maximumRetryDelay: const Duration(hours: 1),
    );

    await reporting.report(
      event: 'message_sent_first',
      occurredAtSeconds: 1767225600,
      parameters: const <String, Object>{
        'world_id': 'world-1',
        'location_id': 'location-1',
        'device_id': 'device-1',
      },
    );
    await reporting.flush();
    expect(store.pendingReports, hasLength(1));

    await reporting.flush();
    expect(attempts, 2);
    expect(sent, hasLength(1));
    expect(store.pendingReports, isEmpty);

    await reporting.report(
      event: 'message_sent_first',
      occurredAtSeconds: 1767225600,
      parameters: const <String, Object>{
        'world_id': 'different',
        'location_id': 'different',
        'device_id': 'device-1',
      },
    );
    await reporting.flush();
    expect(attempts, 2);
    await reporting.dispose();
  });

  test(
    'transaction events without a transaction id are not enqueued',
    () async {
      final store = _MemoryAppEventReportStore();
      final reporting = AppEventReporting(
        environmentProvider: () => 'sandbox',
        store: store,
        sender: (_) async {},
      );

      for (final event in AppEventReporting.transactionEvents) {
        await reporting.report(
          event: event,
          occurredAtSeconds: 1767225600,
          parameters: const <String, Object>{'device_id': 'device-1'},
        );
      }

      expect(store.reports, isEmpty);
      await reporting.dispose();
    },
  );

  test('transaction-derived events preserve their transaction id', () async {
    final store = _MemoryAppEventReportStore();
    final sent = <AppEventReport>[];
    final reporting = AppEventReporting(
      environmentProvider: () => 'sandbox',
      store: store,
      sender: (report) async => sent.add(report),
    );

    await reporting.report(
      event: 'gems_first_day0',
      occurredAtSeconds: 1767225600,
      transactionId: 'order-1',
      parameters: const <String, Object>{'device_id': 'device-1'},
    );
    await reporting.flush();

    expect(sent, hasLength(1));
    expect(sent.single.transactionId, 'order-1');
    await reporting.dispose();
  });

  test('permanent rejection does not block a later queued event', () async {
    final store = _MemoryAppEventReportStore();
    final sent = <String>[];
    final reporting = AppEventReporting(
      environmentProvider: () => 'sandbox',
      store: store,
      sender: (report) async {
        if (report.event == 'gems_first_day0') {
          throw ApiException(
            message: 'invalid event',
            code: 4004,
            kind: ApiExceptionKind.business,
          );
        }
        sent.add(report.event);
      },
    );

    await reporting.report(
      event: 'gems_first_day0',
      occurredAtSeconds: 1767225600,
      transactionId: 'order-1',
      parameters: const <String, Object>{'device_id': 'device-1'},
    );
    await reporting.report(
      event: 'login_first',
      occurredAtSeconds: 1767225600,
      parameters: const <String, Object>{
        'method': 'google',
        'device_id': 'device-1',
      },
    );
    await reporting.flush();

    expect(sent, ['login_first']);
    expect(store.pendingReports, isEmpty);
    await reporting.dispose();
  });

  test('event environment follows the current Firebase environment', () async {
    var firebaseEnvironment = 'test';
    final sent = <AppEventReport>[];
    final reporting = AppEventReporting(
      environmentProvider: () =>
          eventReportEnvironmentForFirebase(firebaseEnvironment),
      store: _MemoryAppEventReportStore(),
      sender: (report) async => sent.add(report),
    );

    await reporting.report(
      event: 'login_first',
      occurredAtSeconds: 1767225600,
      parameters: const <String, Object>{'device_id': 'device-1'},
    );
    firebaseEnvironment = 'production';
    await reporting.report(
      event: 'message_sent_first',
      occurredAtSeconds: 1767225601,
      parameters: const <String, Object>{'device_id': 'device-1'},
    );
    await reporting.flush();

    expect(sent.map((report) => report.environment), <String>[
      'sandbox',
      'production',
    ]);
    await reporting.dispose();
  });
}

class _MemoryAppEventReportStore implements AppEventReportStore {
  final Map<String, AppEventReport> reports = <String, AppEventReport>{};
  final Set<String> delivered = <String>{};

  List<AppEventReport> get pendingReports => reports.values
      .where((report) => !delivered.contains(report.reportKey))
      .toList(growable: false);

  @override
  Future<void> enqueue(AppEventReport report) async {
    reports.putIfAbsent(report.reportKey, () => report);
  }

  @override
  Future<List<AppEventReport>> pending({required int limit}) async {
    return pendingReports.take(limit).toList(growable: false);
  }

  @override
  Future<void> markDelivered(String reportKey) async {
    delivered.add(reportKey);
  }

  @override
  Future<void> close() async {}
}
