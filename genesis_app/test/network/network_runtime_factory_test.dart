import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/dio_http_transport.dart';
import 'package:genesis_flutter_android/network/io_http_transport.dart';
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

  test(
    'io engine only creates explicit transport when a proxy is configured',
    () {
      expect(
        factory.buildHttpTransport(
          debugProxy: '',
          useMock: false,
          httpEngine: 'io',
        ),
        isNull,
      );

      expect(
        factory.buildHttpTransport(
          debugProxy: '127.0.0.1:9090',
          useMock: false,
          httpEngine: 'io',
        ),
        isA<IoHttpTransport>(),
      );
    },
  );

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
