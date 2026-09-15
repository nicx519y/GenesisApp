import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/startup/startup_request_diagnostics.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';

void main() {
  test(
    'logical cancellation is terminal even when an async result arrives',
    () {
      final events = <Map<String, Object>>[];
      final request = StartupRequestDiagnostics(
        requestId: 's:home:1',
        attempt: 1,
        emit: events.add,
      );
      request.cancel('page_disposed');
      request.succeed();
      request.fail(TimeoutException('sensitive detail'));
      expect(events.map((e) => e['stage']), [
        'request_started',
        'request_ended',
      ]);
      expect(events.last['result'], 'cancelled');
      expect(events.last['reason'], 'page_disposed');
      expect(events.last['retry_count'], 0);
    },
  );

  test(
    'failure classification uses structured codes without response or identity',
    () {
      final events = <Map<String, Object>>[];
      final request = StartupRequestDiagnostics(
        requestId: 's:worldo:2',
        attempt: 2,
        emit: events.add,
      );
      request.fail(
        ApiException(
          message: 'secret-token',
          kind: ApiExceptionKind.timeout,
          transportErrorKind: TransportErrorKind.timeout,
          clientFailureCode: ApiClientFailureCode.receiveTimeout,
          uri: Uri.parse('https://example.com/?uid=secret'),
          responseBody: 'private response',
        ),
      );
      expect(events.last['error_kind'], 'timeout');
      expect(events.last['client_failure_code'], 1003);
      expect(events.last['retry_count'], 1);
      expect(events.toString(), isNot(contains('secret')));
      expect(events.toString(), isNot(contains('private response')));
      expect(
        startupErrorDiagnostics(const FormatException('private'))['error_kind'],
        'data_parse',
      );
    },
  );

  test(
    'post-request preparation failure does not rewrite successful request',
    () {
      final events = <Map<String, Object>>[];
      final request = StartupRequestDiagnostics(
        requestId: 's:worldo:1',
        attempt: 1,
        emit: events.add,
      );
      request.succeed();
      request.fail(StateError('preparation'));
      expect(events[1]['result'], 'success');
      expect(events[2]['stage'], 'post_request_error');
      expect(events.where((e) => e['stage'] == 'request_ended'), hasLength(1));
    },
  );

  test('diagnostic sink failures do not interrupt a request', () {
    final request = StartupRequestDiagnostics(
      requestId: 's:home:1',
      attempt: 1,
      emit: (_) => throw StateError('queue unavailable'),
    );
    expect(() => request.fail(TimeoutException('timeout')), returnsNormally);
  });
}
