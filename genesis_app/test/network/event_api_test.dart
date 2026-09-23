import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/v1/event_api.dart';

void main() {
  test('event report uses documented path and exact body', () async {
    TransportRequest? captured;
    final api = EventV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        defaultHeaders: const {'content-type': 'application/json'},
        transport: _CallbackTransport((request) {
          captured = request;
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{"duplicate":false}}',
          );
        }),
        responseProcessor: ApiClient.defaultResponseProcessor,
      ),
    );

    await api.report(
      event: 'gems',
      environment: 'sandbox',
      businessId: 'gems:order-1',
      params: const <String, String>{
        'provider': 'google',
        'product_id': 'gems-500',
        'device_id': 'device-1',
        'value': '4.99',
        'currency': 'USD',
      },
    );

    expect(captured?.method, 'POST');
    expect(captured?.uri.path, '/api/v1/event/report');
    expect(jsonDecode(utf8.decode(captured!.bodyBytes!)), {
      'event': 'gems',
      'environment': 'sandbox',
      'business_id': 'gems:order-1',
      'params': {
        'provider': 'google',
        'product_id': 'gems-500',
        'device_id': 'device-1',
        'value': '4.99',
        'currency': 'USD',
      },
    });
  });

  test('device-once event omits an empty business id', () async {
    TransportRequest? captured;
    final api = EventV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _CallbackTransport((request) {
          captured = request;
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{}}',
          );
        }),
        responseProcessor: ApiClient.defaultResponseProcessor,
      ),
    );

    await api.report(
      event: 'login_first',
      environment: 'production',
      businessId: ' ',
      params: const {'method': 'google', 'device_id': 'device-1'},
    );

    expect(jsonDecode(utf8.decode(captured!.bodyBytes!)), {
      'event': 'login_first',
      'environment': 'production',
      'params': {'method': 'google', 'device_id': 'device-1'},
    });
  });

  test('event report rejects invalid environment before sending', () async {
    final api = EventV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _CallbackTransport((_) {
          throw StateError('request must not be sent');
        }),
      ),
    );

    await expectLater(
      api.report(event: 'login_first', environment: 'test', params: const {}),
      throwsArgumentError,
    );
  });
}

class _CallbackTransport implements HttpTransport {
  const _CallbackTransport(this.sendRequest);

  final TransportResponse Function(TransportRequest request) sendRequest;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    return sendRequest(request);
  }
}
