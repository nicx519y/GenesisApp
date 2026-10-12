import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/v1/device_api.dart';

void main() {
  test(
    'language endpoint preserves all nine codes and required device header',
    () async {
      TransportRequest? captured;
      final api = DeviceV1Api(
        ApiClient(
          baseUrl: 'https://example.test/api/',
          transport: _CallbackTransport((request) {
            captured = request;
            return const TransportResponse(
              statusCode: 200,
              headers: {},
              body: '{"err_no":0,"err_msg":"succ","data":{}}',
            );
          }),
        ),
      );
      for (final code in [
        'en',
        'zh-TW',
        'es',
        'pt',
        'fr',
        'de',
        'it',
        'ja',
        'ko',
      ]) {
        await api.setLanguage(deviceId: 'device-1', language: code);
        expect(captured!.method, 'POST');
        expect(captured!.uri.path, '/api/v1/device/setlanguage');
        expect(captured!.headers['X-Device-ID'], 'device-1');
        expect(jsonDecode(utf8.decode(captured!.bodyBytes!)), {
          'language': code,
        });
      }
      await expectLater(
        api.setLanguage(deviceId: 'device-1', language: 'zh_TW'),
        throwsArgumentError,
      );
    },
  );

  test('language endpoint propagates business failure', () async {
    final api = DeviceV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _CallbackTransport(
          (_) => const TransportResponse(
            statusCode: 200,
            headers: {},
            body:
                '{"err_no":3102,"err_msg":"Unable to save language","data":{}}',
          ),
        ),
      ),
    );
    await expectLater(
      api.setLanguage(deviceId: 'device-1', language: 'zh-TW'),
      throwsA(isA<Exception>()),
    );
  });
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
        appInstanceId: ' firebase-instance-1 ',
      );

      expect(captured?.method, 'POST');
      expect(captured?.uri.path, '/api/v1/device/register');
      expect(jsonDecode(utf8.decode(captured!.bodyBytes!)), {
        'adid': 'adid-1',
        'environment': 'production',
        'idfa': '',
        'idfv': 'idfv-1',
        'app_instance_id': 'firebase-instance-1',
      });
    },
  );

  test('device attribution registration sends an empty ADID', () async {
    TransportRequest? captured;
    final api = DeviceV1Api(
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

    await api.registerAttribution(
      adid: '   ',
      environment: 'sandbox',
      gpsAdid: 'gaid-1',
    );

    expect(jsonDecode(utf8.decode(captured!.bodyBytes!)), {
      'adid': '',
      'environment': 'sandbox',
      'gps_adid': 'gaid-1',
      'app_instance_id': '',
    });
  });

  test('device attribution registration sends empty platform IDs', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = DeviceV1Api(
      ApiClient(
        baseUrl: 'https://example.test/api/',
        transport: _CallbackTransport((request) {
          bodies.add(
            jsonDecode(utf8.decode(request.bodyBytes!)) as Map<String, dynamic>,
          );
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
      adid: '',
      environment: 'sandbox',
      gpsAdid: '',
    );
    await api.registerAttribution(
      adid: '',
      environment: 'sandbox',
      idfa: '',
      idfv: '',
    );

    expect(bodies, [
      {
        'adid': '',
        'environment': 'sandbox',
        'gps_adid': '',
        'app_instance_id': '',
      },
      {
        'adid': '',
        'environment': 'sandbox',
        'idfa': '',
        'idfv': '',
        'app_instance_id': '',
      },
    ]);
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
