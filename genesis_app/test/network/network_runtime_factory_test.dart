import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_http_transport_pool.dart';
import 'package:genesis_flutter_android/network/network_runtime_factory.dart';
import 'package:genesis_flutter_android/network/websocket_transport.dart';

void main() {
  const factory = NetworkRuntimeFactory();

  setUp(GenesisHttpTransportRegistry.reset);
  tearDown(GenesisHttpTransportRegistry.reset);

  test('mock environment leaves ApiClient on mock/default transport path', () {
    final transport = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: true,
      httpEngine: 'dio',
    );

    expect(transport, isNull);
  });

  test('default engine creates and shares the global HTTP/3 pool', () {
    final first = factory.buildHttpTransport(debugProxy: '', useMock: false);
    final second = factory.buildHttpTransport(debugProxy: '', useMock: false);

    expect(first, isA<GenesisHttpTransportPool>());
    expect(identical(first, second), true);
    expect(
      (first! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );
  });

  test('http3 aliases select the global native pool', () {
    for (final engine in <String>['http3', 'quic', 'auto']) {
      GenesisHttpTransportRegistry.reset();
      expect(
        factory.buildHttpTransport(
          debugProxy: '',
          useMock: false,
          httpEngine: engine,
        ),
        isA<GenesisHttpTransportPool>(),
      );
    }
  });

  test('explicit proxy forces the three-connection HTTP/2 pool', () {
    final transport = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: false,
      httpEngine: 'http3',
    );

    expect(transport, isA<GenesisHttpTransportPool>());
    expect(
      (transport! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );
  });

  test('legacy io engine name still resolves to HTTP/2 Dio transport', () {
    final direct = factory.buildHttpTransport(
      debugProxy: '',
      useMock: false,
      httpEngine: 'io',
    );
    expect(direct, isA<GenesisHttpTransportPool>());
    expect(
      (direct! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );

    GenesisHttpTransportRegistry.reset();
    final proxied = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: false,
      httpEngine: 'io',
    );
    expect(proxied, isA<GenesisHttpTransportPool>());
    expect(
      (proxied! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );
  });

  test('dio engine creates Dio transport with or without proxy', () {
    final direct = factory.buildHttpTransport(
      debugProxy: '',
      useMock: false,
      httpEngine: 'dio',
    );
    expect(direct, isA<GenesisHttpTransportPool>());
    expect(
      (direct! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );

    GenesisHttpTransportRegistry.reset();
    final proxied = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: false,
      httpEngine: 'DIO',
    );
    expect(proxied, isA<GenesisHttpTransportPool>());
    expect(
      (proxied! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );
  });

  test('http2 engine creates Dio HTTP/2 transport with or without proxy', () {
    final direct = factory.buildHttpTransport(
      debugProxy: '',
      useMock: false,
      httpEngine: 'http2',
    );
    expect(direct, isA<GenesisHttpTransportPool>());
    expect(
      (direct! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );

    GenesisHttpTransportRegistry.reset();
    final proxied = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: false,
      httpEngine: 'HTTP2',
    );
    expect(proxied, isA<GenesisHttpTransportPool>());
    expect(
      (proxied! as GenesisHttpTransportPool).connectionCount,
      genesisHttp2ConnectionCount,
    );
  });

  test(
    'websocket transport is only explicit when proxy or frame log is needed',
    () {
      expect(
        factory.buildWebSocketTransport(debugProxy: '', debugLogFrames: false),
        isNull,
      );

      expect(
        factory.buildWebSocketTransport(
          debugProxy: '127.0.0.1:9090',
          debugLogFrames: false,
        ),
        isA<NetworkWebSocketTransport>(),
      );

      expect(
        factory.buildWebSocketTransport(debugProxy: '', debugLogFrames: true),
        isA<NetworkWebSocketTransport>(),
      );
    },
  );
}
