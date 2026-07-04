abstract class HttpTransport {
  Future<TransportResponse> send(TransportRequest request);
}

typedef NetworkProgressCallback = void Function(int sentBytes, int totalBytes);

class NetworkCancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const NetworkRequestCancelledException();
  }

  void Function() addCancelListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () {
      _listeners.remove(listener);
    };
  }
}

class NetworkRequestCancelledException implements Exception {
  const NetworkRequestCancelledException();

  @override
  String toString() => 'NetworkRequestCancelledException';
}

class TransportRequest {
  const TransportRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.bodyBytes,
    required this.timeoutMs,
    this.onSendProgress,
    this.onReceiveProgress,
    this.cancellationToken,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? bodyBytes;
  final int timeoutMs;
  final NetworkProgressCallback? onSendProgress;
  final NetworkProgressCallback? onReceiveProgress;
  final NetworkCancellationToken? cancellationToken;
}

class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.bodyBytes = const <int>[],
    this.responsePayloadSizeBytes,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final List<int> bodyBytes;
  final int? responsePayloadSizeBytes;
}
