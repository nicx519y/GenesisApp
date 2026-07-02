abstract class HttpTransport {
  Future<TransportResponse> send(TransportRequest request);
}

typedef NetworkProgressCallback = void Function(int sentBytes, int totalBytes);

class TransportRequest {
  const TransportRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.bodyBytes,
    required this.timeoutMs,
    this.onSendProgress,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? bodyBytes;
  final int timeoutMs;
  final NetworkProgressCallback? onSendProgress;
}

class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.responsePayloadSizeBytes,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final int? responsePayloadSizeBytes;
}
