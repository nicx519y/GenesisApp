abstract class HttpTransport {
  Future<TransportResponse> send(TransportRequest request);
}

class TransportRequest {
  const TransportRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.bodyBytes,
    required this.timeoutMs,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? bodyBytes;
  final int timeoutMs;
}

class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

