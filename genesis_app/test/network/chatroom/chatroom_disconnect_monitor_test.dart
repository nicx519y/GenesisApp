import 'package:genesis_flutter_android/network/chatroom/chatroom_connect_deadline.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_disconnect_monitor.dart';

void main() {
  late List<Map<String, dynamic>> failures;
  late List<Map<String, Object>> successes;
  ChatroomDisconnectMonitor monitor({
    DateTime Function()? now,
    Future<String> Function()? network,
  }) {
    final m = ChatroomDisconnectMonitor(
      now: now,
      readNetworkType: network ?? () async => 'wifi',
      report:
          ({
            required worldId,
            required phase,
            required cause,
            required networkType,
            required extData,
          }) {
            failures.add({
              ...jsonDecode(extData) as Map<String, dynamic>,
              'phase': phase,
            });
          },
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
              'id': recoveryId,
              'phase': phase,
              'retries': retryCount,
              'duration': durationMs,
              'attempts': connectAttempts,
            });
          },
    );
    m.didChangeAppLifecycleState(AppLifecycleState.resumed);
    m.activate('w', 'u');
    addTearDown(m.dispose);
    return m;
  }

  void fail(ChatroomDisconnectMonitor m, {bool timeout = false}) =>
      m.connectFailed(
        m.beginAttempt(),
        error: timeout
            ? const ChatroomConnectDeadlineExceeded(Duration(seconds: 5))
            : StateError('failed'),
      );
  setUp(() {
    failures = [];
    successes = [];
  });

  testWidgets(
    'initial failure plus five failed retries reports once, and pairs recovery',
    (tester) async {
      final m = monitor();
      fail(m);
      for (var i = 0; i < 4; i++) {
        fail(m);
      }
      expect(failures, isEmpty);
      fail(m);
      expect(failures.single['cause'], 'retry_exhausted');
      expect(failures.single['retry_failure_count'], 5);
      expect(failures.single['timeout_count'], 0);
      fail(m);
      fail(m, timeout: true);
      fail(m, timeout: true);
      expect(failures, hasLength(1));
      final a = m.beginAttempt();
      m.succeeded(a);
      m.succeeded(a);
      expect(successes, hasLength(1));
      expect(successes.single['id'], failures.single['recovery_id']);
    },
  );
  testWidgets('fifth retry success and fast reconnect produce no telemetry', (
    tester,
  ) async {
    final m = monitor();
    for (var i = 0; i < 5; i++) {
      fail(m);
    }
    m.succeeded(m.beginAttempt());
    m.lost('socket_closed');
    for (var i = 0; i < 4; i++) {
      fail(m);
    }
    m.succeeded(m.beginAttempt());
    expect(failures, isEmpty);
    expect(successes, isEmpty);
  });
  testWidgets(
    'two timeouts including initial attempt report stalled, never twice',
    (tester) async {
      final m = monitor();
      fail(m, timeout: true);
      expect(failures, isEmpty);
      fail(m, timeout: true);
      expect(failures.single['cause'], 'connect_stalled');
      expect(failures.single['timeout_count'], 2);
      expect(failures.single['retry_failure_count'], 0);
      for (var i = 0; i < 6; i++) {
        fail(m);
      }
      expect(failures, hasLength(1));
      m.succeeded(m.beginAttempt());
      expect(successes.single['id'], failures.single['recovery_id']);
    },
  );
  testWidgets(
    'lower-level timeout is an explicit retry failure, never a stall',
    (tester) async {
      final m = monitor();
      for (var i = 0; i < 6; i++) {
        m.connectFailed(
          m.beginAttempt(),
          error: TimeoutException('signing or socket returned timeout'),
        );
      }
      expect(failures.single['cause'], 'retry_exhausted');
      expect(failures.single['timeout_count'], 0);
      expect(failures.single['retry_failure_count'], 5);
      final detail = (failures.single['attempt_details'] as List).last as Map;
      expect(detail['error_type'], 'TimeoutException');
    },
  );

  testWidgets('mixed failures count separately and first threshold wins', (
    tester,
  ) async {
    final m = monitor();
    fail(m, timeout: true);
    for (var i = 0; i < 4; i++) {
      fail(m);
    }
    expect(failures, isEmpty);
    fail(m);
    expect(failures.single['cause'], 'retry_exhausted');
    expect(failures.single['timeout_count'], 1);
    fail(m, timeout: true);
    expect(failures, hasLength(1));
  });
  testWidgets('each new outage resets counters and recovery identity', (
    tester,
  ) async {
    final m = monitor();
    fail(m, timeout: true);
    fail(m, timeout: true);
    m.succeeded(m.beginAttempt());
    final first = failures.single['recovery_id'];
    m.lost('socket_closed');
    for (var i = 0; i < 4; i++) {
      fail(m);
    }
    expect(failures, hasLength(1));
    fail(m);
    expect(failures, hasLength(2));
    expect(failures.last['recovery_id'], isNot(first));
    expect(failures.last['phase'], 'reconnect');
    m.succeeded(m.beginAttempt());
    expect(successes, hasLength(2));
  });
  testWidgets(
    'background attempts and time never advance reporting thresholds',
    (tester) async {
      var now = DateTime.utc(2026);
      final m = monitor(now: () => now);
      fail(m, timeout: true);
      now = now.add(const Duration(seconds: 5));
      m.didChangeAppLifecycleState(AppLifecycleState.paused);
      for (var i = 0; i < 8; i++) {
        fail(m, timeout: true);
      }
      now = now.add(const Duration(minutes: 2));
      expect(failures, isEmpty);
      m.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fail(m, timeout: true);
      expect(failures.single['timeout_count'], 2);
      now = now.add(const Duration(seconds: 3));
      m.succeeded(m.beginAttempt());
      expect(successes.single['duration'], 8000);
      expect(successes.single['attempts'], 3);
      expect(successes.single['retries'], 2);
    },
  );
  testWidgets(
    'background recovery pairs but does not count its attempt or time',
    (tester) async {
      var now = DateTime.utc(2026);
      final m = monitor(now: () => now);
      fail(m, timeout: true);
      fail(m, timeout: true);
      now = now.add(const Duration(seconds: 10));
      m.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 2));
      m.succeeded(m.beginAttempt());
      expect(successes.single['attempts'], 2);
      expect(successes.single['duration'], 10000);
      expect(successes.single['id'], failures.single['recovery_id']);
    },
  );
  testWidgets('stale and duplicated failures do not advance thresholds', (
    tester,
  ) async {
    final m = monitor();
    final a = m.beginAttempt();
    m.connectFailed(
      a,
      error: const ChatroomConnectDeadlineExceeded(Duration(seconds: 5)),
    );
    m.connectFailed(
      a,
      error: const ChatroomConnectDeadlineExceeded(Duration(seconds: 5)),
    );
    expect(failures, isEmpty);
    m.cancel();
    m.activate('other', 'other');
    m.connectFailed(
      a,
      error: const ChatroomConnectDeadlineExceeded(Duration(seconds: 5)),
    );
    fail(m, timeout: true);
    expect(failures, isEmpty);
    m.succeeded(m.beginAttempt());
    expect(successes, isEmpty);
  });
  testWidgets('network query never delays count threshold or recovery', (
    tester,
  ) async {
    final pending = Completer<String>();
    final m = monitor(network: () => pending.future);
    fail(m, timeout: true);
    fail(m, timeout: true);
    expect(failures, hasLength(1));
    m.succeeded(m.beginAttempt());
    pending.complete('mobile');
    await tester.pump();
    expect(successes, hasLength(1));
    expect(failures, hasLength(1));
  });
  testWidgets('structured HTTP and TLS diagnostics survive threshold report', (
    tester,
  ) async {
    for (final error in <Object>[
      const WebSocketException('denied', 403),
      const HandshakeException('TLS', OSError('cert', 7)),
      SocketException(
        'refused',
        address: InternetAddress('127.0.0.1'),
        port: 443,
      ),
    ]) {
      final m = monitor();
      fail(m);
      for (var i = 0; i < 4; i++) {
        fail(m);
      }
      m.connectFailed(
        m.beginAttempt(),
        error: error,
        connectionDetails: {
          'failure_stage': 'websocket_connect',
          'target_host': 'example.test',
          'transport_duration_ms': 123,
        },
      );
      final detail = (failures.last['attempt_details'] as List).last as Map;
      expect(detail['failure_stage'], 'websocket_connect');
      if (error is WebSocketException) {
        expect(detail['http_status_code'], 403);
      }
      if (error is TlsException) {
        expect(detail['os_error_code'], 7);
      }
      if (error is SocketException) {
        expect(detail['socket_port'], 443);
      }
      expect(jsonEncode(failures.last).length, lessThan(4000));
      m.dispose();
    }
  });
}
