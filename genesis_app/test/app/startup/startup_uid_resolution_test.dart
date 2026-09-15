import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/app/startup/startup_uid_resolution.dart';
import '../../../lib/app/startup/initial_landing_page_resolver.dart';

void main() {
  test('telemetry failure preserves UID and success for consumers', () async {
    final records = <Map<String, Object>>[];
    var reads = 0;
    final shared = resolveStartupUid(
      readUid: () async {
        reads++;
        return 'u_1';
      },
      setTelemetryUser: (_) => throw StateError('telemetry'),
      recordDiagnostics: records.add,
    );
    final page = await resolveInitialLandingPage(
      uidReadAlreadyBounded: true,
      loadUid: () async => (await shared).uid,
      loadHomeCache: (_) async => null,
      loadWorldoCache: (_) async => null,
    );
    expect((await shared).uid, 'u_1');
    expect((await shared).readFailed, false);
    expect(page.reason, 'session_all_cache_miss');
    expect(reads, 1);
    expect(records.single['telemetry_error_type'], 'StateError');
  });

  test('empty UID is signed out, not read error', () async {
    final result = await resolveStartupUid(
      readUid: () async => null,
      setTelemetryUser: (_) {},
      recordDiagnostics: (_) {},
    );
    expect(result.status, 'signed_out');
    expect(result.readFailed, false);
  });

  test(
    'timeout records late success without rewriting shared decision',
    () async {
      final completer = Completer<String?>();
      final records = <Map<String, Object>>[];
      var telemetryCalls = 0;
      final result = await resolveStartupUid(
        readUid: () => completer.future,
        timeout: const Duration(milliseconds: 1),
        setTelemetryUser: (_) {
          telemetryCalls++;
        },
        recordDiagnostics: records.add,
      );
      expect(result.status, 'timeout');
      completer.complete('u_late');
      await Future<void>.delayed(Duration.zero);
      expect(result.uid, null);
      expect(telemetryCalls, 0);
      expect(records.last['late_status'], 'signed_in');
      expect(records.last.containsKey('uid'), false);
    },
  );

  test(
    'read error differs from timeout; diagnostic failure is isolated',
    () async {
      final records = <Map<String, Object>>[];
      final result = await resolveStartupUid(
        readUid: () => throw PlatformException(code: 'startup_uid_read_error'),
        setTelemetryUser: (_) => fail('must not update identity'),
        recordDiagnostics: (data) {
          records.add(data);
          throw StateError('sink');
        },
      );
      expect(result.status, 'read_error');
      expect(
        records.single['error_type'],
        'platform_error:startup_uid_read_error',
      );
    },
  );

  test('bounded shared read is not timed out again by page resolver', () async {
    final decision = await resolveInitialLandingPage(
      uidReadAlreadyBounded: true,
      loadUid: () => Future<String?>.delayed(
        const Duration(milliseconds: 20),
        () => 'u_1',
      ),
      timeout: const Duration(milliseconds: 1),
      loadHomeCache: (_) async => null,
      loadWorldoCache: (_) async => null,
    );
    expect(decision.reason, 'session_all_cache_miss');
  });

  test('late error is consumed and reported', () async {
    final completer = Completer<String?>();
    final records = <Map<String, Object>>[];
    await resolveStartupUid(
      readUid: () => completer.future,
      timeout: const Duration(milliseconds: 1),
      setTelemetryUser: (_) {},
      recordDiagnostics: records.add,
    );
    completer.completeError(StateError('late'));
    await Future<void>.delayed(Duration.zero);
    expect(records.last['late_status'], 'read_error');
  });
}
