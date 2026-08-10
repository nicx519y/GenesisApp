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

  test('explicit proxy forces the HTTP/1.1 transport', () {
    final transport = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: false,
      httpEngine: 'http3',
    );

    final pool = transport! as GenesisHttpTransportPool;
    expect(pool.connectionCount, genesisHttp1ConnectionCount);
    expect(pool.debugUsesHttp1, isTrue);
  });

  test('invalid proxies degrade to the same direct configuration', () {
    for (final invalidProxy in <String>[
      '[',
      '127.0.0.1:abc',
      'https://127.0.0.1:9090',
      '127.0.0.1:0',
      '127.0.0.1:65536',
    ]) {
      GenesisHttpTransportRegistry.reset();
      final invalid = factory.buildHttpTransport(
        debugProxy: invalidProxy,
        useMock: false,
        httpEngine: 'http3',
      );
      final direct = factory.buildHttpTransport(
        debugProxy: '',
        useMock: false,
        httpEngine: 'http3',
      );
      expect(identical(invalid, direct), true, reason: invalidProxy);

      GenesisHttpTransportRegistry.reset();
      final registryInvalid = GenesisHttpTransportRegistry.configure(
        httpEngine: 'http3',
        debugProxy: invalidProxy,
      );
      final registryDirect = GenesisHttpTransportRegistry.configure(
        httpEngine: 'http3',
        debugProxy: '',
      );
      expect(
        identical(registryInvalid, registryDirect),
        true,
        reason: 'registry: $invalidProxy',
      );
    }
  });

  test('equivalent valid proxies share one canonical configuration', () {
    final withScheme = factory.buildHttpTransport(
      debugProxy: 'http://LOCALHOST:9090/',
      useMock: false,
      httpEngine: 'http2',
    );
    final withoutScheme = factory.buildHttpTransport(
      debugProxy: 'localhost:9090',
      useMock: false,
      httpEngine: 'http2',
    );

    expect(identical(withScheme, withoutScheme), true);
  });

  test('legacy io engine is HTTP/2 direct but HTTP/1.1 with proxy', () {
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
    final proxiedPool = proxied! as GenesisHttpTransportPool;
    expect(proxiedPool.connectionCount, genesisHttp1ConnectionCount);
    expect(proxiedPool.debugUsesHttp1, isTrue);
  });

  test('dio engine is HTTP/2 direct but HTTP/1.1 with proxy', () {
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
    final proxiedPool = proxied! as GenesisHttpTransportPool;
    expect(proxiedPool.connectionCount, genesisHttp1ConnectionCount);
    expect(proxiedPool.debugUsesHttp1, isTrue);
  });

  test('http2 engine is HTTP/2 direct but HTTP/1.1 with proxy', () {
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
    final proxiedPool = proxied! as GenesisHttpTransportPool;
    expect(proxiedPool.connectionCount, genesisHttp1ConnectionCount);
    expect(proxiedPool.debugUsesHttp1, isTrue);
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
