import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_disconnect_monitor.dart';
import 'package:genesis_flutter_android/platform/network/network_type_snapshot.dart';

void main() {
  late List<Map<String, Object>> reports;
  ChatroomDisconnectMonitor monitor({Future<String> Function()? network}) {
    final value = ChatroomDisconnectMonitor(
      readNetworkType: network ?? () async => 'none',
      report:
          ({
            required worldId,
            required phase,
            required cause,
            required networkType,
            required extData,
          }) {
            reports.add({
              'world': worldId,
              'phase': phase,
              'cause': cause,
              'network': networkType,
              'ext': jsonDecode(extData),
            });
          },
    );
    value.didChangeAppLifecycleState(AppLifecycleState.resumed);
    value.activate('world-1', 'user-1');
    addTearDown(value.dispose);
    return value;
  }

  setUp(() => reports = []);

  test('retry success counts retries and excludes background duration', () {
    var now = DateTime.utc(2026);
    final success = <Map<String, Object>>[];
    final m = ChatroomDisconnectMonitor(
      now: () => now,
      reportSuccess:
          ({
            required worldId,
            required phase,
            required retryCount,
            required durationMs,
            required connectAttempts,
          }) {
            success.add({
              'phase': phase,
              'retry_count': retryCount,
              'duration_ms': durationMs,
              'attempts': connectAttempts,
            });
          },
    );
    addTearDown(m.dispose);
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    m.activate('w', 'u');
    m.succeeded(m.beginAttempt());
    expect(success, isEmpty);
    m.lost('socket_closed');
    now = now.add(const Duration(seconds: 2));
    m.connectFailed(m.beginAttempt());
    m.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 100));
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    now = now.add(const Duration(seconds: 3));
    final attempt = m.beginAttempt();
    m.succeeded(attempt - 1);
    expect(success, isEmpty);
    m.succeeded(attempt);
    m.succeeded(attempt);
    expect(success.single, {
      'phase': 'reconnect',
      'retry_count': 2,
      'duration_ms': 5000,
      'attempts': 2,
    });
  });

  test(
    'initial failed connection reports recovery but cancellation clears it',
    () {
      final success = <int>[];
      final m = ChatroomDisconnectMonitor(
        reportSuccess:
            ({
              required worldId,
              required phase,
              required retryCount,
              required durationMs,
              required connectAttempts,
            }) {
              expect(phase, 'initial_connect');
              success.add(retryCount);
            },
      );
      addTearDown(m.dispose);
      m.didChangeAppLifecycleState(AppLifecycleState.resumed);
      m.activate('w', 'u');
      m.connectFailed(m.beginAttempt());
      m.connectFailed(m.beginAttempt());
      m.succeeded(m.beginAttempt());
      expect(success, [2]);
      m.lost('socket_closed');
      m.cancel();
      m.activate('other', 'other');
      m.succeeded(m.beginAttempt());
      expect(success, [2]);
    },
  );

  testWidgets('raw errors retained and failures after threshold reported', (
    tester,
  ) async {
    final m = monitor();
    final a = m.beginAttempt();
    m.connectFailed(
      a,
      error: const SocketException(
        'lookup failed',
        osError: OSError('host missing', 8),
      ),
      stack: StackTrace.fromString('frame1\nframe2'),
    );
    await tester.pump(const Duration(seconds: 15));
    final ext = reports.single['ext'] as Map;
    final detail = (ext['attempt_details'] as List).single as Map;
    expect(detail['error_type'], 'SocketException');
    expect(detail['os_error_code'], 8);
    expect(detail['os_error_message'], 'host missing');
    expect(detail['stack_summary'], 'frame1\nframe2');
    for (final key in [
      'dns_duration_ms',
      'tcp_duration_ms',
      'tls_duration_ms',
      'timing_unavailable_reason',
    ]) {
      expect(detail.containsKey(key), isFalse);
    }
    m.connectFailed(m.beginAttempt(), error: StateError('retry failure'));
    await tester.pump();
    expect(reports, hasLength(2));
    expect(
      ((reports.last['ext'] as Map)['attempt_details'] as List)
          .last['error_type'],
      'StateError',
    );
    m.succeeded(m.beginAttempt());
    await tester.pump(const Duration(seconds: 30));
    expect(reports, hasLength(2));
  });

  testWidgets('initial hang reports at 15 seconds, not on first failure', (
    tester,
  ) async {
    final m = monitor();
    final a = m.beginAttempt();
    await tester.pump(const Duration(seconds: 14));
    expect(reports, isEmpty);
    m.connectFailed(a);
    m.beginAttempt();
    await tester.pump(const Duration(seconds: 1));
    expect(reports.single, containsPair('phase', 'initial_connect'));
    expect(reports.single, containsPair('cause', 'connect_error'));
    expect(reports.single, containsPair('network', 'none'));
    expect(reports.single['ext'], {
      'connect_attempts': 2,
      'cause': 'connect_error',
      'attempt_details': anything,
      'last_error_code': 'connect_failed',
    });
    m.beginAttempt();
    await tester.pump(const Duration(minutes: 1));
    expect(reports, hasLength(1));
  });

  testWidgets('hang with no failure callback still reports unknown', (
    tester,
  ) async {
    final m = monitor();
    m.beginAttempt();
    await tester.pump(const Duration(seconds: 15));
    expect(reports.single['cause'], 'unknown');
    expect(reports.single['ext'], {
      'connect_attempts': 1,
      'cause': 'unknown',
      'attempt_details': [],
    });
  });

  testWidgets('handshake before threshold cancels even while join is pending', (
    tester,
  ) async {
    final m = monitor();
    final a = m.beginAttempt();
    await tester.pump(const Duration(seconds: 14));
    m.succeeded(a);
    await tester.pump(const Duration(seconds: 30));
    expect(reports, isEmpty);
  });

  testWidgets(
    'reconnect deduplicates causes and allows a new outage after recovery',
    (tester) async {
      final m = monitor(network: () async => 'wifi,vpn');
      m.succeeded(m.beginAttempt());
      m.lost('socket_error', errorCode: 'socket_error');
      m.lost('socket_closed', closeCode: 1001);
      await tester.pump(const Duration(seconds: 15));
      expect(reports.single['cause'], 'socket_error');
      expect(reports.single['phase'], 'reconnect');
      expect(reports.single['network'], 'wifi,vpn');
      expect(reports.single['ext'], {
        'connect_attempts': 0,
        'cause': 'socket_error',
        'attempt_details': anything,
        'close_code': 1001,
        'last_error_code': 'socket_error',
      });
      m.succeeded(m.beginAttempt());
      m.lost('heartbeat_send_failed');
      await tester.pump(const Duration(seconds: 15));
      expect(reports, hasLength(2));
      expect(reports.last['cause'], 'heartbeat_send_failed');
    },
  );

  testWidgets('background time excluded and resume starts fresh observation', (
    tester,
  ) async {
    final m = monitor();
    m.beginAttempt();
    await tester.pump(const Duration(seconds: 14));
    m.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(reports, isEmpty);
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 14));
    expect(reports, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(reports, hasLength(1));
  });

  testWidgets(
    'exit cancels and stale callbacks do not close a new observation',
    (tester) async {
      final m = monitor();
      final old = m.beginAttempt();
      await tester.pump(const Duration(seconds: 14));
      m.cancel();
      await tester.pump(const Duration(seconds: 20));
      expect(reports, isEmpty);
      m.activate('world-2', 'user-2');
      m.beginAttempt();
      m.succeeded(old);
      m.connectFailed(old);
      m.lost('socket_closed', attempt: old);
      await tester.pump(const Duration(seconds: 15));
      expect(reports.single['world'], 'world-2');
      expect(reports.single['cause'], 'unknown');
    },
  );

  testWidgets('recovery during network snapshot suppresses stale event', (
    tester,
  ) async {
    final pending = Completer<String>();
    final m = monitor(network: () => pending.future);
    final a = m.beginAttempt();
    await tester.pump(const Duration(seconds: 15));
    m.succeeded(a);
    pending.complete('none');
    await tester.pump();
    expect(reports, isEmpty);
  });

  testWidgets('network query failure cannot block report', (tester) async {
    final m = monitor(
      network: () async => throw StateError('native unavailable'),
    );
    m.beginAttempt();
    await tester.pump(const Duration(seconds: 15));
    expect(reports.single['network'], 'unknown');
  });

  testWidgets('hung native query times out without blocking diagnostics', (
    tester,
  ) async {
    final m = monitor(network: () => Completer<String>().future);
    m.beginAttempt();
    await tester.pump(const Duration(seconds: 15));
    expect(reports, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(reports.single['network'], 'unknown');
  });

  testWidgets('dispose cancels an outstanding observation', (tester) async {
    final m = monitor();
    m.beginAttempt();
    m.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(reports, isEmpty);
  });

  test(
    'network types are concrete, stable, deduplicated and none is exclusive',
    () {
      expect(
        NetworkTypeSnapshot.normalize(['vpn', 'wifi', 'wifi', 'none']),
        'wifi,vpn',
      );
      expect(
        NetworkTypeSnapshot.normalize(['ethernet', 'bluetooth', 'satellite']),
        'ethernet,bluetooth,satellite',
      );
      expect(NetworkTypeSnapshot.normalize(['none']), 'none');
      expect(NetworkTypeSnapshot.normalize(['other']), 'unknown');
      expect(NetworkTypeSnapshot.normalize([]), 'unknown');
    },
  );
}
