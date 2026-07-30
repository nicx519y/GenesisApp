import 'dio_http_transport.dart';
import 'http_transport.dart';
import 'websocket_transport.dart';

const kGenesisHttpEngine = String.fromEnvironment(
  'GENESIS_HTTP_ENGINE',
  defaultValue: 'http2',
);

class NetworkRuntimeFactory {
  const NetworkRuntimeFactory();

  HttpTransport? buildHttpTransport({
    required String debugProxy,
    required bool useMock,
    String httpEngine = kGenesisHttpEngine,
  }) {
    if (useMock) return null;
    final proxy = _normalizedProxy(debugProxy);
    switch (httpEngine.trim().toLowerCase()) {
      case 'http2':
      case 'dio':
      case 'io':
      default:
        return DioHttpTransport(proxy: proxy);
    }
  }

  NetworkWebSocketTransport? buildWebSocketTransport({
    required String debugProxy,
    required bool debugLogFrames,
    String logName = 'NetworkWebSocket',
    String frameLogName = 'NetworkWebSocketFrame',
  }) {
    final proxy = _normalizedProxy(debugProxy);
    final logFrames =
        debugLogFrames || !const bool.fromEnvironment('dart.vm.product');
    if (proxy == null && !debugLogFrames) return null;
    return IoWebSocketTransport(
      proxy: proxy,
      logFrames: logFrames,
      logName: logName,
      frameLogName: frameLogName,
    );
  }

  String? _normalizedProxy(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
