import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/app_event_reporting.dart';
import 'package:genesis_flutter_android/app/telemetry/purchase_event_reporting.dart';
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

  test('sqflite upgrade retains a queued purchase report', () async {
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

  test('sqflite v4 upgrade retains supported purchase rows', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'genesis-event-report-purchase-removal-',
    );
    final databasePath = '${directory.path}/reports.db';
    addTearDown(() async {
      await databaseFactoryFfiNoIsolate.deleteDatabase(databasePath);
      await directory.delete(recursive: true);
    });
    final oldDatabase = await databaseFactoryFfiNoIsolate.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (database, _) => database.execute('''
CREATE TABLE app_event_reports (
  sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_key TEXT NOT NULL UNIQUE,
  event_name TEXT NOT NULL,
  environment TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  transaction_id TEXT,
  params_json TEXT NOT NULL,
  delivered INTEGER NOT NULL DEFAULT 0
)
'''),
      ),
    );
    for (final event in [
      'purchase',
      'gems_first',
      'subscription_day0',
      'login_first',
    ]) {
      await oldDatabase.insert('app_event_reports', <String, Object?>{
        'report_key': event,
        'event_name': event,
        'environment': 'sandbox',
        'occurred_at': 1767225600,
        'transaction_id': event == 'login_first' ? null : 'old-order',
        'params_json': '{}',
        'delivered': 0,
      });
    }
    await oldDatabase.close();

    final store = SqfliteAppEventReportStore(
      databaseFactoryOverride: databaseFactoryFfiNoIsolate,
      databasePath: databasePath,
    );
    expect((await store.pending(limit: 20)).map((report) => report.event), [
      'purchase',
      'gems_first',
      'subscription_day0',
      'login_first',
    ]);
    await store.close();
  });

  test('purchase events require transaction_id and reach the sender', () async {
    const purchaseEvents = <String>[
      'purchase',
      'purchase_first',
      'purchase_day0',
      'purchase_first_day0',
      'gems',
      'gems_first',
      'gems_day0',
      'gems_first_day0',
      'subscription',
      'subscription_first',
      'subscription_day0',
      'subscription_first_day0',
    ];
    final store = _MemoryAppEventReportStore();
    final sent = <AppEventReport>[];
    final reporting = AppEventReporting(
      environmentProvider: () => 'sandbox',
      store: store,
      sender: (report) async => sent.add(report),
    );
    for (final event in purchaseEvents) {
      await reporting.report(
        event: event,
        occurredAtSeconds: 1767225600,
        parameters: const <String, Object>{'device_id': 'device-1'},
      );
    }
    expect(store.reports, isEmpty);

    for (final event in purchaseEvents) {
      await reporting.report(
        event: event,
        occurredAtSeconds: 1767225600,
        parameters: const <String, Object>{'device_id': 'device-1'},
        transactionId: 'store-transaction-1',
      );
    }
    await reporting.flush();

    expect(sent.map((report) => report.event), purchaseEvents);
    expect(
      sent.every((report) => report.transactionId == 'store-transaction-1'),
      isTrue,
    );
    expect(store.pendingReports, isEmpty);
    await reporting.dispose();
  });

  test(
    'first events remain device-once while other purchase events use receipt',
    () async {
      final store = _MemoryAppEventReportStore();
      final sent = <AppEventReport>[];
      final reporting = AppEventReporting(
        environmentProvider: () => 'production',
        store: store,
        sender: (report) async => sent.add(report),
      );
      for (final transactionId in ['receipt-1', 'receipt-2']) {
        for (final event in [
          'purchase',
          'purchase_first',
          'gems',
          'gems_first',
        ]) {
          await reporting.report(
            event: event,
            occurredAtSeconds: 1767225600,
            parameters: const <String, Object>{'device_id': 'device-1'},
            transactionId: transactionId,
          );
        }
      }
      await reporting.flush();
      expect(sent.where((report) => report.event == 'purchase'), hasLength(2));
      expect(sent.where((report) => report.event == 'gems'), hasLength(2));
      expect(
        sent.where((report) => report.event == 'purchase_first'),
        hasLength(1),
      );
      expect(
        sent.where((report) => report.event == 'gems_first'),
        hasLength(1),
      );
      await reporting.dispose();
    },
  );

  test(
    'store success sends server-only purchase events with Day0 and price',
    () async {
      final store = _MemoryAppEventReportStore();
      final sent = <AppEventReport>[];
      final reporting = AppEventReporting(
        environmentProvider: () => 'production',
        store: store,
        sender: (report) async => sent.add(report),
      );
      final purchaseEvents = PurchaseEventReporting(
        eventReporting: reporting,
        deviceIdReader: () async => 'device-1',
        day0AnchorStore: _MemoryPurchaseDay0AnchorStore(),
        legacyEventMarkerReader: (_) async => false,
        enabled: () => true,
      );
      await purchaseEvents.recordServerTimeSynchronized(
        DateTime.utc(2026, 10, 10, 12),
      );
      await purchaseEvents.recordPurchase(
        provider: 'google',
        productId: 'gem_pack',
        kind: PurchaseEventKind.gems,
        purchaseIdentity: 'token-1',
        priceAmountMicros: 5000000,
        priceCurrencyCode: 'usd',
      );
      await reporting.flush();
      expect(sent.map((report) => report.event), [
        'purchase',
        'gems',
        'purchase_first',
        'gems_first',
        'purchase_day0',
        'gems_day0',
        'purchase_first_day0',
        'gems_first_day0',
      ]);
      expect(sent.every((report) => report.transactionId == 'token-1'), isTrue);
      expect(sent.first.params, <String, String>{
        'provider': 'google',
        'product_id': 'gem_pack',
        'device_id': 'device-1',
        'value': '5.0',
        'currency': 'USD',
      });

      await purchaseEvents.recordPurchase(
        provider: 'google',
        productId: 'gem_pack',
        kind: PurchaseEventKind.gems,
        purchaseIdentity: 'token-1',
        transactionIdentity: 'new-transaction-for-same-token',
      );
      await reporting.flush();
      expect(sent, hasLength(8));

      await purchaseEvents.recordServerTimeSynchronized(
        DateTime.utc(2026, 10, 11, 12),
      );
      await purchaseEvents.recordPurchase(
        provider: 'apple',
        productId: 'subscription_product',
        kind: PurchaseEventKind.subscription,
        purchaseIdentity: 'transaction-2',
      );
      await reporting.flush();
      expect(
        sent
            .where((report) => report.transactionId == 'transaction-2')
            .map((report) => report.event),
        ['purchase', 'subscription', 'subscription_first'],
      );
      await reporting.dispose();
    },
  );

  test(
    'Google subscription renewal with the same token is not a new purchase',
    () async {
      final sent = <AppEventReport>[];
      final reporting = AppEventReporting(
        environmentProvider: () => 'production',
        store: _MemoryAppEventReportStore(),
        sender: (report) async => sent.add(report),
      );
      final purchaseEvents = PurchaseEventReporting(
        eventReporting: reporting,
        deviceIdReader: () async => 'device-1',
        legacyEventMarkerReader: (_) async => false,
        enabled: () => true,
      );
      for (final transactionId in ['order-1', 'order-2']) {
        await purchaseEvents.recordPurchase(
          provider: 'google',
          productId: 'monthly',
          kind: PurchaseEventKind.subscription,
          purchaseIdentity: 'same-purchase-token',
          transactionIdentity: transactionId,
        );
      }
      await reporting.flush();
      expect(sent.map((report) => report.event), [
        'purchase',
        'subscription',
        'purchase_first',
        'subscription_first',
      ]);
      expect(sent.every((report) => report.transactionId == 'order-1'), isTrue);
      await reporting.dispose();
    },
  );

  test(
    'legacy Firebase markers prevent duplicate server purchase events',
    () async {
      final sent = <AppEventReport>[];
      final checkedKeys = <String>[];
      final reporting = AppEventReporting(
        environmentProvider: () => 'production',
        store: _MemoryAppEventReportStore(),
        sender: (report) async => sent.add(report),
      );
      final purchaseEvents = PurchaseEventReporting(
        eventReporting: reporting,
        deviceIdReader: () async => 'device-1',
        legacyEventMarkerReader: (key) async {
          checkedKeys.add(key);
          return true;
        },
        enabled: () => true,
      );
      await purchaseEvents.recordPurchase(
        provider: 'google',
        productId: 'monthly',
        kind: PurchaseEventKind.subscription,
        purchaseIdentity: 'old-token',
        transactionIdentity: 'old-order',
      );
      await reporting.flush();
      expect(sent, isEmpty);
      expect(checkedKeys, contains('purchase_first'));
      expect(checkedKeys, contains('subscription_first'));
      expect(
        checkedKeys.any((key) => key.startsWith('purchase_transaction_v1.')),
        isTrue,
      );
      expect(
        checkedKeys.any(
          (key) => key.startsWith('subscription_transaction_v1.'),
        ),
        isTrue,
      );
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

  test('permanent rejection does not block a later queued event', () async {
    final store = _MemoryAppEventReportStore();
    final sent = <String>[];
    final reporting = AppEventReporting(
      environmentProvider: () => 'sandbox',
      store: store,
      sender: (report) async {
        if (report.event == 'login_first') {
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
      event: 'login_first',
      occurredAtSeconds: 1767225600,
      parameters: const <String, Object>{'device_id': 'device-1'},
    );
    await reporting.report(
      event: 'message_sent_first',
      occurredAtSeconds: 1767225600,
      parameters: const <String, Object>{
        'world_id': 'world-1',
        'device_id': 'device-1',
      },
    );
    await reporting.flush();

    expect(sent, ['message_sent_first']);
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

class _MemoryPurchaseDay0AnchorStore implements PurchaseDay0AnchorStore {
  DateTime? anchor;

  @override
  Future<DateTime?> read() async => anchor;

  @override
  Future<void> write(DateTime serverUtc) async => anchor = serverUtc;
}
