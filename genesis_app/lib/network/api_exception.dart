enum ApiExceptionKind {
  unknown,
  transport,
  timeout,
  httpStatus,
  response,
  business,
  gatewayAuth,
  cancelled,
}

enum TransportErrorKind {
  unknown,
  timeout,
  connection,
  badCertificate,
  cancelled,
}

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.error,
    this.responseBody,
    this.responseHeaders,
    this.uri,
    this.kind = ApiExceptionKind.unknown,
    this.transportErrorKind,
    this.retryable = false,
  });

  final String message;
  final int? code;
  final int? statusCode;
  final Object? error;
  final String? responseBody;
  final Map<String, String>? responseHeaders;
  final Uri? uri;
  final ApiExceptionKind kind;
  final TransportErrorKind? transportErrorKind;
  final bool retryable;

  @override
  String toString() {
    final c = code == null ? '' : ' (code=$code)';
    final sc = statusCode == null ? '' : ' (statusCode=$statusCode)';
    final k = kind == ApiExceptionKind.unknown ? '' : ' (kind=${kind.name})';
    final u = uri == null ? '' : ' (uri=$uri)';
    return 'ApiException$message$c$sc$k$u';
  }
}
