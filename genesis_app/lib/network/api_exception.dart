class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.error,
    this.responseBody,
    this.responseHeaders,
    this.uri,
  });

  final String message;
  final int? code;
  final int? statusCode;
  final Object? error;
  final String? responseBody;
  final Map<String, String>? responseHeaders;
  final Uri? uri;

  @override
  String toString() {
    final c = code == null ? '' : ' (code=$code)';
    final sc = statusCode == null ? '' : ' (statusCode=$statusCode)';
    final u = uri == null ? '' : ' (uri=$uri)';
    return 'ApiException$message$c$sc$u';
  }
}
