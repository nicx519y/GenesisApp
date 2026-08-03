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
    final tk = transportErrorKind == null
        ? ''
        : ' (transportErrorKind=${transportErrorKind!.name})';
    final cause = error == null ? '' : ' (cause=${error.runtimeType})';
    final u = uri == null ? '' : ' (uri=${_diagnosticUri(uri!)})';
    return 'ApiException$message$c$sc$k$tk$cause$u';
  }
}

String _diagnosticUri(Uri uri) {
  if (!uri.hasAuthority) return Uri(path: uri.path).toString();
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
