import 'genesis_http_transport_pool.dart';
import 'http_transport.dart';
import 'websocket_transport.dart';

const kGenesisHttpEngine = String.fromEnvironment(
  'GENESIS_HTTP_ENGINE',
  defaultValue: 'http3',
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
      case 'http3':
      case 'quic':
      case 'auto':
        return GenesisHttpTransportRegistry.configure(
          httpEngine: httpEngine,
          debugProxy: proxy,
        );
      case 'http2':
      case 'dio':
      case 'io':
        return GenesisHttpTransportRegistry.configure(
          httpEngine: 'http2',
          debugProxy: proxy,
        );
      default:
        return GenesisHttpTransportRegistry.configure(
          httpEngine: 'http3',
          debugProxy: proxy,
        );
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
    return normalizeHttpProxyAddress(value);
  }
}
