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

/// Stable client-side technical failure categories used by API monitoring.
///
/// These values are part of the telemetry contract. Do not reuse an existing
/// code for a different failure type.
enum ApiClientFailureCode {
  connectTimeout(1001),
  sendTimeout(1002),
  receiveTimeout(1003),
  timeoutUnknownPhase(1004),
  dnsLookup(1010),
  networkUnavailable(1011),
  connectionRefused(1012),
  connectionReset(1013),
  connectionClosed(1014),
  protocolNegotiation(1015),
  connectionOther(1019),
  tlsHandshake(1020),
  certificateInvalid(1021),
  cancelled(1030),
  invalidUri(1101),
  requestHeaders(1102),
  requestBodySerialization(1103),
  multipartFileRead(1104),
  gatewayIdentity(1301),
  gatewayLocalKey(1302),
  gatewaySigning(1303),
  gatewayRegistration(1304),
  gatewayTimeSync(1305),
  gatewayOther(1399),
  unknown(1999);

  const ApiClientFailureCode(this.value);

  final int value;
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
    this.clientFailureCode,
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
  final ApiClientFailureCode? clientFailureCode;
  final bool retryable;

  @override
  String toString() {
    final c = code == null ? '' : ' (code=$code)';
    final sc = statusCode == null ? '' : ' (statusCode=$statusCode)';
    final k = kind == ApiExceptionKind.unknown ? '' : ' (kind=${kind.name})';
    final tk = transportErrorKind == null
        ? ''
        : ' (transportErrorKind=${transportErrorKind!.name})';
    final cc = clientFailureCode == null
        ? ''
        : ' (clientFailureCode=${clientFailureCode!.value})';
    final cause = error == null ? '' : ' (cause=${error.runtimeType})';
    final u = uri == null ? '' : ' (uri=${_diagnosticUri(uri!)})';
    return 'ApiException$message$c$sc$k$tk$cc$cause$u';
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
