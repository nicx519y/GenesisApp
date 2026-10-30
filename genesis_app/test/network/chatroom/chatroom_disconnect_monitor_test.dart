import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_disconnect_monitor.dart';
import 'package:genesis_flutter_android/platform/network/network_type_snapshot.dart';

void main() {
  late List<Map<String, Object>> reports;
  late List<Map<String, Object>> successes;
  ChatroomDisconnectMonitor monitor({
    Future<String> Function()? network,
    DateTime Function()? now,
  }) {
    final value = ChatroomDisconnectMonitor(
      now: now,
      readNetworkType: network ?? () async => 'none',
      reportSuccess:
          ({
            required worldId,
            required phase,
            required recoveryId,
            required retryCount,
            required durationMs,
            required connectAttempts,
          }) {
            successes.add({
              'recovery_id': recoveryId,
              'phase': phase,
              'retry_count': retryCount,
              'duration_ms': durationMs,
              'attempts': connectAttempts,
            });
          },
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

  setUp(() {
    reports = [];
    successes = [];
  });

  testWidgets('quick initial and reconnect successes do not report', (
    tester,
  ) async {
    final m = monitor();
    m.connectFailed(m.beginAttempt());
    await tester.pump(const Duration(seconds: 5));
    m.succeeded(m.beginAttempt());
    m.lost('socket_closed');
    await tester.pump(const Duration(seconds: 5));
    m.succeeded(m.beginAttempt());
    await tester.pump(const Duration(seconds: 20));
    expect(reports, isEmpty);
    expect(successes, isEmpty);
  });

  testWidgets('each reported round pairs once and uses a distinct ID', (
    tester,
  ) async {
    final m = monitor();
    final first = m.beginAttempt();
    m.connectFailed(first);
    await tester.pump(const Duration(seconds: 15));
    final firstId = (reports.single['ext'] as Map)['recovery_id'];
    expect(firstId, isA<String>());
    expect(firstId, isNotEmpty);
    // Recovery only pairs with the anomaly from this failed round.
    m.succeeded(first);
    m.succeeded(first);
    expect(successes, hasLength(1));
    expect(successes.single['recovery_id'], firstId);
    expect(successes.single['phase'], 'initial_connect');
    m.lost('socket_closed');
    await tester.pump(const Duration(seconds: 15));
    final secondId = (reports.last['ext'] as Map)['recovery_id'];
    expect(secondId, isNot(firstId));
    m.succeeded(first - 1);
    expect(successes, hasLength(1));
    m.succeeded(m.beginAttempt());
    expect(successes, hasLength(2));
    expect(successes.last['recovery_id'], secondId);
    expect(successes.last['phase'], 'reconnect');
    // Prior reported rounds cannot authorize a later quick success.
    m.lost('socket_closed');
    m.succeeded(m.beginAttempt());
    expect(successes, hasLength(2));
  });

  testWidgets('reported round survives background without duplicate reports', (
    tester,
  ) async {
    final m = monitor();
    m.connectFailed(m.beginAttempt());
    await tester.pump(const Duration(seconds: 15));
    final id = (reports.single['ext'] as Map)['recovery_id'];
    m.didChangeAppLifecycleState(AppLifecycleState.paused);
    m.connectFailed(m.beginAttempt());
    await tester.pump(const Duration(minutes: 1));
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 30));
    expect(reports, hasLength(1));
    m.succeeded(m.beginAttempt());
    expect(successes.single['recovery_id'], id);
    m.lost('socket_closed');
    await tester.pump(const Duration(seconds: 15));
    m.cancel();
    m.activate('other', 'other');
    m.succeeded(m.beginAttempt());
    expect(successes, hasLength(1));
  });

  testWidgets(
    'paired success retains counts and excludes background duration',
    (tester) async {
      var now = DateTime.utc(2026);
      final m = monitor(now: () => now);
      m.connectFailed(m.beginAttempt());
      now = now.add(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      m.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 100));
      m.connectFailed(m.beginAttempt());
      m.didChangeAppLifecycleState(AppLifecycleState.resumed);
      now = now.add(const Duration(seconds: 3));
      m.succeeded(m.beginAttempt());
      expect(successes.single['duration_ms'], 18000);
      expect(successes.single['attempts'], 3);
      expect(successes.single['retry_count'], 2);
      expect(
        successes.single['recovery_id'],
        (reports.single['ext'] as Map)['recovery_id'],
      );
    },
  );

  testWidgets(
    'raw errors retained but failures after threshold do not repeat',
    (tester) async {
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
      expect(reports, hasLength(1));
      expect(
        ((reports.last['ext'] as Map)['attempt_details'] as List)
            .last['error_type'],
        'SocketException',
      );
      m.succeeded(m.beginAttempt());
      await tester.pump(const Duration(seconds: 30));
      expect(reports, hasLength(1));
    },
  );

  testWidgets(
    '15 second threshold starts at failure rather than initial attempt',
    (tester) async {
      final m = monitor();
      final a = m.beginAttempt();
      await tester.pump(const Duration(seconds: 14));
      expect(reports, isEmpty);
      m.connectFailed(a);
      m.beginAttempt();
      await tester.pump(const Duration(seconds: 1));
      expect(reports, isEmpty);
      await tester.pump(const Duration(seconds: 14));
      expect(reports.single, containsPair('phase', 'initial_connect'));
      expect(reports.single, containsPair('cause', 'connect_error'));
      expect(reports.single, containsPair('network', 'none'));
      expect(reports.single['ext'], {
        'recovery_id': isA<String>(),
        'connect_attempts': 2,
        'cause': 'connect_error',
        'attempt_details': anything,
        'last_error_code': 'connect_failed',
      });
      m.beginAttempt();
      await tester.pump(const Duration(minutes: 1));
      expect(reports, hasLength(1));
    },
  );

  testWidgets('initial hang without failure does not start observation', (
    tester,
  ) async {
    final m = monitor();
    final attempt = m.beginAttempt();
    await tester.pump(const Duration(minutes: 1));
    expect(reports, isEmpty);
    m.succeeded(attempt);
    expect(successes, isEmpty);
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
        'recovery_id': isA<String>(),
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
    m.connectFailed(m.beginAttempt());
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
      m.connectFailed(old);
      await tester.pump(const Duration(seconds: 14));
      m.cancel();
      await tester.pump(const Duration(seconds: 20));
      expect(reports, isEmpty);
      m.activate('world-2', 'user-2');
      m.connectFailed(m.beginAttempt());
      m.succeeded(old);
      m.connectFailed(old);
      m.lost('socket_closed', attempt: old);
      await tester.pump(const Duration(seconds: 15));
      expect(reports.single['world'], 'world-2');
      expect(reports.single['cause'], 'connect_error');
    },
  );

  testWidgets('pending network snapshot cannot suppress threshold pair', (
    tester,
  ) async {
    final pending = Completer<String>();
    final m = monitor(network: () => pending.future);
    final a = m.beginAttempt();
    m.connectFailed(a);
    await tester.pump(const Duration(seconds: 15));
    expect(reports, hasLength(1));
    expect(reports.single['network'], 'unknown');
    m.succeeded(a);
    pending.complete('none');
    await tester.pump();
    expect(
      successes.single['recovery_id'],
      (reports.single['ext'] as Map)['recovery_id'],
    );
    expect(reports, hasLength(1));
  });

  testWidgets('network query failure cannot block report', (tester) async {
    final m = monitor(
      network: () async => throw StateError('native unavailable'),
    );
    m.connectFailed(m.beginAttempt());
    await tester.pump(const Duration(seconds: 15));
    expect(reports.single['network'], 'unknown');
  });

  testWidgets('hung native query times out without blocking diagnostics', (
    tester,
  ) async {
    final m = monitor(network: () => Completer<String>().future);
    m.connectFailed(m.beginAttempt());
    await tester.pump(const Duration(seconds: 15));
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
