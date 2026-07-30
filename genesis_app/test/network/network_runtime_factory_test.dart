import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/dio_http_transport.dart';
import 'package:genesis_flutter_android/network/network_runtime_factory.dart';
import 'package:genesis_flutter_android/network/websocket_transport.dart';

void main() {
  const factory = NetworkRuntimeFactory();

  test('mock environment leaves ApiClient on mock/default transport path', () {
    final transport = factory.buildHttpTransport(
      debugProxy: '127.0.0.1:9090',
      useMock: true,
      httpEngine: 'dio',
    );

    expect(transport, isNull);
  });

  test('default engine creates Dio transport', () {
    expect(
      factory.buildHttpTransport(debugProxy: '', useMock: false),
      isA<DioHttpTransport>(),
    );
  });

  test('legacy io engine name still resolves to HTTP/2 Dio transport', () {
    expect(
      factory.buildHttpTransport(
        debugProxy: '',
        useMock: false,
        httpEngine: 'io',
      ),
      isA<DioHttpTransport>(),
    );
    expect(
      factory.buildHttpTransport(
        debugProxy: '127.0.0.1:9090',
        useMock: false,
        httpEngine: 'io',
      ),
      isA<DioHttpTransport>(),
    );
  });

  test('dio engine creates Dio transport with or without proxy', () {
    expect(
      factory.buildHttpTransport(
        debugProxy: '',
        useMock: false,
        httpEngine: 'dio',
      ),
      isA<DioHttpTransport>(),
    );
    expect(
      factory.buildHttpTransport(
        debugProxy: '127.0.0.1:9090',
        useMock: false,
        httpEngine: 'DIO',
      ),
      isA<DioHttpTransport>(),
    );
  });

  test('http2 engine creates Dio HTTP/2 transport with or without proxy', () {
    expect(
      factory.buildHttpTransport(
        debugProxy: '',
        useMock: false,
        httpEngine: 'http2',
      ),
      isA<DioHttpTransport>(),
    );
    expect(
      factory.buildHttpTransport(
        debugProxy: '127.0.0.1:9090',
        useMock: false,
        httpEngine: 'HTTP2',
      ),
      isA<DioHttpTransport>(),
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
