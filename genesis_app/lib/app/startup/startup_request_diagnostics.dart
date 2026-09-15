import 'dart:async';

import '../../network/api_exception.dart';
import '../../network/http_transport.dart';

/// One logical first-page load, including API handling and page-data parsing.
/// This is not a wire-level HTTP request or an internal transport retry.
class StartupRequestDiagnostics {
  StartupRequestDiagnostics({
    required this.requestId,
    required this.attempt,
    required void Function(Map<String, Object>) emit,
  }) : _emit = emit {
    _record('request_started');
  }

  final String requestId;
  final int attempt;
  final void Function(Map<String, Object>) _emit;
  final Stopwatch _clock = Stopwatch()..start();
  String? _result;

  void succeed() => _finish('success');

  void cancel(String reason) => _finish('cancelled', {'reason': reason});

  void fail(Object error) {
    if (_result == 'success') {
      _record('post_request_error', startupErrorDiagnostics(error));
      return;
    }
    final cancelled =
        error is NetworkRequestCancelledException ||
        (error is ApiException &&
            (error.kind == ApiExceptionKind.cancelled ||
                error.transportErrorKind == TransportErrorKind.cancelled));
    _finish(cancelled ? 'cancelled' : 'failure', {
      ...startupErrorDiagnostics(error),
      if (cancelled) 'reason': 'transport_cancelled',
    });
  }

  void _finish(String result, [Map<String, Object> fields = const {}]) {
    if (_result != null) return;
    _result = result;
    _clock.stop();
    _record('request_ended', {
      'result': result,
      'duration_ms': _clock.elapsedMilliseconds,
      ...fields,
    });
  }

  void _record(String stage, [Map<String, Object> fields = const {}]) {
    try {
      _emit({
        'stage': stage,
        'request_id': requestId,
        'attempt': attempt,
        'retry_count': attempt - 1,
        ...fields,
      });
    } catch (_) {
      // Diagnostics must never affect request execution or page delivery.
    }
  }
}

Map<String, Object> startupErrorDiagnostics(Object error) {
  return {
    'error_type': error.runtimeType.toString(),
    if (error is ApiException) ...{
      'error_kind': error.kind.name,
      if (error.transportErrorKind != null)
        'transport_error_kind': error.transportErrorKind!.name,
      if (error.clientFailureCode != null)
        'client_failure_code': error.clientFailureCode!.value,
      if (error.statusCode != null) 'http_status': error.statusCode!,
      if (error.code != null) 'business_code': error.code!,
    } else
      'error_kind': error is TimeoutException
          ? 'timeout'
          : error is FormatException || error is TypeError
          ? 'data_parse'
          : error is NetworkRequestCancelledException
          ? 'cancelled'
          : 'unknown',
  };
}
