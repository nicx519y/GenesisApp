import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/v1/device_api.dart';

void main() {
  test(
    'device attribution registration uses the documented path and body',
    () async {
      TransportRequest? captured;
      final api = DeviceV1Api(
        ApiClient(
          baseUrl: 'https://example.test/api/',
          defaultHeaders: const {'content-type': 'application/json'},
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

      await api.registerAttribution(
        adid: ' adid-1 ',
        environment: ' Production ',
        idfa: '',
        idfv: 'idfv-1',
      );

      expect(captured?.method, 'POST');
      expect(captured?.uri.path, '/api/v1/device/register');
      expect(jsonDecode(utf8.decode(captured!.bodyBytes!)), {
        'adid': 'adid-1',
        'environment': 'production',
        'idfa': '',
        'idfv': 'idfv-1',
      });
    },
  );

  test('device attribution registration rejects an empty ADID', () async {
    final api = DeviceV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _CallbackTransport((_) {
          throw StateError('request must not be sent');
        }),
      ),
    );

    await expectLater(
      api.registerAttribution(adid: '   ', environment: 'sandbox'),
      throwsArgumentError,
    );
  });

  test(
    'device attribution registration rejects an invalid environment',
    () async {
      final api = DeviceV1Api(
        ApiClient(
          baseUrl: 'https://example.test/api/',
          transport: _CallbackTransport((_) {
            throw StateError('request must not be sent');
          }),
        ),
      );

      await expectLater(
        api.registerAttribution(adid: 'adid-1', environment: 'test'),
        throwsArgumentError,
      );
    },
  );
}

class _CallbackTransport implements HttpTransport {
  const _CallbackTransport(this.sendRequest);

  final TransportResponse Function(TransportRequest request) sendRequest;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    return sendRequest(request);
  }
}
