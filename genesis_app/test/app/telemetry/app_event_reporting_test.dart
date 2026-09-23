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

  test(
    'reports only the selected events with Firebase-equivalent params',
    () async {
      final store = _MemoryAppEventReportStore();
      final sent = <AppEventReport>[];
      final reporting = AppEventReporting(
        environment: 'sandbox',
        store: store,
        sender: (report) async => sent.add(report),
        initialRetryDelay: const Duration(hours: 1),
        maximumRetryDelay: const Duration(hours: 1),
      );

      await reporting.report(
        event: 'gems',
        businessId: 'gems:order-1',
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
        businessId: 'must-be-ignored',
        parameters: const <String, Object>{
          'method': 'google',
          'device_id': 'device-1',
        },
      );
      await reporting.report(
        event: 'subscription_renew',
        businessId: 'subscription:renewal-1',
        parameters: const <String, Object>{'device_id': 'device-1'},
      );
      await reporting.flush();

      expect(sent.map((report) => report.event), ['gems', 'login_first']);
      expect(sent.first.businessId, 'gems:order-1');
      expect(sent.first.params, const <String, String>{
        'provider': 'google',
        'product_id': 'gems-500',
        'device_id': 'device-1',
        'value': '4.99',
        'currency': 'USD',
      });
      expect(sent.last.businessId, isNull);
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
      environment: 'production',
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

  test('transaction events without a business id are not enqueued', () async {
    final store = _MemoryAppEventReportStore();
    final reporting = AppEventReporting(
      environment: 'sandbox',
      store: store,
      sender: (_) async {},
    );

    await reporting.report(
      event: 'purchase',
      parameters: const <String, Object>{'device_id': 'device-1'},
    );

    expect(store.reports, isEmpty);
    await reporting.dispose();
  });

  test('permanent rejection does not block a later queued event', () async {
    final store = _MemoryAppEventReportStore();
    final sent = <String>[];
    final reporting = AppEventReporting(
      environment: 'sandbox',
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
      parameters: const <String, Object>{'device_id': 'device-1'},
    );
    await reporting.report(
      event: 'login_first',
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
