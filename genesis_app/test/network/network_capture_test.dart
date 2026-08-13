import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/multipart_body.dart';
import 'package:genesis_flutter_android/network/network_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('capture enabled state persists and loads', () async {
    final controller = NetworkCaptureController();
    expect(await controller.loadEnabled(), isFalse);

    await controller.setEnabled(true);

    final restored = NetworkCaptureController();
    expect(await restored.loadEnabled(), isTrue);
  });

  test('non-debug controller cannot enable or capture requests', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      NetworkCaptureController.storageKey: true,
    });
    final controller = NetworkCaptureController(available: false);

    expect(await controller.loadEnabled(), isFalse);
    await controller.setEnabled(true);

    expect(controller.available, isFalse);
    expect(controller.enabled, isFalse);
    expect(controller.begin(_request()), isNull);
    expect(controller.records, isEmpty);
  });

  test('HTTP transport is wrapped only for debug builds', () {
    final delegate = _CallbackTransport(
      (_) async => const TransportResponse(
        statusCode: 204,
        headers: <String, String>{},
        body: '',
      ),
    );

    expect(
      debugNetworkCaptureTransport(delegate: delegate, isDebugBuild: false),
      same(delegate),
    );
    expect(
      debugNetworkCaptureTransport(delegate: delegate, isDebugBuild: true),
      isA<RecordingHttpTransport>(),
    );
  });

  test(
    'recording transport pairs pending request with successful response',
    () async {
      final responseCompleter = Completer<TransportResponse>();
      final controller = NetworkCaptureController();
      await controller.setEnabled(true);
      final transport = RecordingHttpTransport(
        delegate: _CallbackTransport((_) => responseCompleter.future),
        controller: controller,
      );
      final request = _request(
        uri: Uri.parse('https://api.worldo.ai/api/v1/user?token=query-secret'),
        headers: const <String, String>{
          'authorization': 'Bearer secret-token',
          'content-type': 'application/json',
        },
        bodyBytes: utf8.encode(
          jsonEncode(<String, Object?>{
            'name': 'Worldo',
            'password': 'private-password',
          }),
        ),
      );

      final future = transport.send(request);
      expect(controller.records, hasLength(1));
      expect(controller.records.single.status, NetworkCaptureStatus.pending);
      expect(
        controller.records.single.uri.queryParameters['token'],
        isNot('query-secret'),
      );
      expect(
        controller.records.single.requestHeaders['authorization'],
        isNot('Bearer secret-token'),
      );
      expect(controller.records.single.requestBody!.text, contains('Worldo'));
      expect(
        controller.records.single.requestBody!.text,
        isNot(contains('private-password')),
      );

      responseCompleter.complete(
        TransportResponse(
          statusCode: 200,
          headers: const <String, String>{'content-type': 'application/json'},
          body: '{"token":"response-secret","ok":true}',
          bodyBytes: utf8.encode('{"token":"response-secret","ok":true}'),
          httpProtocolVersion: 'h3',
        ),
      );
      final response = await future;

      expect(response.statusCode, 200);
      expect(controller.records, hasLength(1));
      expect(controller.records.single.status, NetworkCaptureStatus.success);
      expect(controller.records.single.httpProtocolVersion, 'h3');
      expect(
        controller.records.single.responseBody!.text,
        isNot(contains('response-secret')),
      );
    },
  );

  test(
    'recording transport records errors and preserves original error',
    () async {
      final controller = NetworkCaptureController();
      await controller.setEnabled(true);
      final originalError = StateError('network failed');
      final transport = RecordingHttpTransport(
        delegate: _CallbackTransport((_) async => throw originalError),
        controller: controller,
      );

      await expectLater(
        transport.send(_request()),
        throwsA(same(originalError)),
      );

      expect(controller.records.single.status, NetworkCaptureStatus.error);
      expect(controller.records.single.errorType, 'StateError');
      expect(
        controller.records.single.errorMessage,
        contains('network failed'),
      );
    },
  );

  test('non-2xx responses are retained as error records', () async {
    final controller = NetworkCaptureController();
    await controller.setEnabled(true);
    final transport = RecordingHttpTransport(
      delegate: _CallbackTransport(
        (_) async => const TransportResponse(
          statusCode: 503,
          headers: <String, String>{'content-type': 'application/json'},
          body: '{"error":"unavailable"}',
        ),
      ),
      controller: controller,
    );

    final response = await transport.send(_request());

    expect(response.statusCode, 503);
    expect(controller.records.single.status, NetworkCaptureStatus.error);
    expect(controller.records.single.statusCode, 503);
  });

  test('cancellation is recorded without changing cancellation type', () async {
    final controller = NetworkCaptureController();
    await controller.setEnabled(true);
    final transport = RecordingHttpTransport(
      delegate: _CallbackTransport(
        (_) async => throw const NetworkRequestCancelledException(),
      ),
      controller: controller,
    );

    await expectLater(
      transport.send(_request()),
      throwsA(isA<NetworkRequestCancelledException>()),
    );

    expect(controller.records.single.status, NetworkCaptureStatus.error);
    expect(
      controller.records.single.errorType,
      'NetworkRequestCancelledException',
    );
  });

  test('ApiClient retries create separate paired network records', () async {
    final controller = NetworkCaptureController();
    await controller.setEnabled(true);
    var attempt = 0;
    final recordingTransport = RecordingHttpTransport(
      delegate: _CallbackTransport((_) async {
        attempt += 1;
        if (attempt == 1) throw TimeoutException('slow');
        return const TransportResponse(
          statusCode: 200,
          headers: <String, String>{'content-type': 'application/json'},
          body: '{"ok":true}',
        );
      }),
      controller: controller,
    );
    final client = ApiClient(
      baseUrl: 'https://api.worldo.ai/',
      transport: recordingTransport,
      retryPolicy: ApiRetryPolicy.safe,
    );

    expect(await client.get<Object?>('/ping'), <String, Object?>{'ok': true});

    expect(controller.records, hasLength(2));
    expect(
      controller.records.map((record) => record.status),
      containsAll(<NetworkCaptureStatus>[
        NetworkCaptureStatus.success,
        NetworkCaptureStatus.error,
      ]),
    );
    expect(
      controller.records.every((record) => record.finishedAt != null),
      isTrue,
    );
  });

  test(
    'disabled controller keeps existing records and stops new records',
    () async {
      final controller = NetworkCaptureController();
      await controller.setEnabled(true);
      final transport = RecordingHttpTransport(
        delegate: _CallbackTransport(
          (_) async => const TransportResponse(
            statusCode: 204,
            headers: <String, String>{},
            body: '',
          ),
        ),
        controller: controller,
      );

      await transport.send(_request());
      await controller.setEnabled(false);
      await transport.send(
        _request(uri: Uri.parse('https://api.worldo.ai/two')),
      );

      expect(controller.records, hasLength(1));
      controller.clear();
      expect(controller.records, isEmpty);
    },
  );

  test('multipart stores fields and file metadata without file bytes', () {
    final multipart = MultipartBody.singleFile(
      bytes: List<int>.filled(128, 65),
      filename: 'avatar.jpg',
      contentType: 'image/jpeg',
      fields: const <String, String>{
        'caption': 'hello',
        'access_token': 'upload-secret',
      },
    );
    final request = _request(
      headers: <String, String>{'content-type': multipart.contentType},
      bodyBytes: multipart.toBytes(),
    );

    final captured = captureNetworkRequestBody(request)!;

    expect(captured.binary, isTrue);
    expect(captured.text, contains('avatar.jpg'));
    expect(captured.text, contains('image/jpeg'));
    expect(captured.text, contains('128'));
    expect(captured.text, contains('hello'));
    expect(captured.text, isNot(contains('upload-secret')));
    expect(captured.text, isNot(contains(List.filled(16, 'A').join())));
  });

  test('form body and plain error text redact sensitive values', () async {
    final request = _request(
      headers: const <String, String>{
        'content-type': 'application/x-www-form-urlencoded',
      },
      bodyBytes: utf8.encode('name=Worldo&access_token=upload-secret'),
    );

    final captured = captureNetworkRequestBody(request)!;
    expect(captured.text, contains('name=Worldo'));
    expect(captured.text, isNot(contains('upload-secret')));
    final controller = NetworkCaptureController();
    await controller.setEnabled(true);
    final id = controller.begin(_request())!;
    controller.fail(id, StateError('request failed: token=plain-secret'));
    expect(
      controller.records.single.errorMessage,
      isNot(contains('plain-secret')),
    );
    expect(
      sanitizeNetworkCaptureText('plain token=body-value'),
      'plain token=body-value',
    );
  });

  test(
    'capture failures never change transport success or error semantics',
    () async {
      const successfulResponse = TransportResponse(
        statusCode: 201,
        headers: <String, String>{},
        body: 'created',
      );
      final successTransport = RecordingHttpTransport(
        delegate: _CallbackTransport((_) async => successfulResponse),
        controller: _ThrowingCaptureController(),
      );
      expect(await successTransport.send(_request()), same(successfulResponse));
      final completionTransport = RecordingHttpTransport(
        delegate: _CallbackTransport((_) async => successfulResponse),
        controller: _ThrowingCaptureController(throwOnBegin: false),
      );
      expect(
        await completionTransport.send(_request()),
        same(successfulResponse),
      );

      final originalError = ArgumentError('delegate failure');
      final errorTransport = RecordingHttpTransport(
        delegate: _CallbackTransport((_) async => throw originalError),
        controller: _ThrowingCaptureController(throwOnBegin: false),
      );
      await expectLater(
        errorTransport.send(_request()),
        throwsA(same(originalError)),
      );
    },
  );

  test('binary response records metadata without decoding its bytes', () async {
    final controller = NetworkCaptureController();
    await controller.setEnabled(true);
    final transport = RecordingHttpTransport(
      delegate: _CallbackTransport(
        (_) async => const TransportResponse(
          statusCode: 200,
          headers: <String, String>{'content-type': 'image/jpeg'},
          body: '',
          bodyBytes: <int>[0, 255, 216, 0, 1],
          responsePayloadSizeBytes: 5,
        ),
      ),
      controller: controller,
    );

    await transport.send(_request());

    final body = controller.records.single.responseBody!;
    expect(body.binary, isTrue);
    expect(body.byteCount, 5);
    expect(body.contentType, 'image/jpeg');
    expect(body.text, '[Binary body: 5 bytes]');
  });

  test(
    'limits evict oldest completed records while preserving pending',
    () async {
      final controller = NetworkCaptureController(
        maxRecords: 2,
        maxBodyBytes: 50,
      );
      await controller.setEnabled(true);
      final pendingId = controller.begin(
        _request(uri: Uri.parse('https://api.worldo.ai/pending')),
      );
      final firstId = controller.begin(
        _request(uri: Uri.parse('https://api.worldo.ai/first')),
      );
      controller.complete(firstId!, _response('1234567890'));
      final secondId = controller.begin(
        _request(uri: Uri.parse('https://api.worldo.ai/second')),
      );
      controller.complete(secondId!, _response('abcdefghij'));

      expect(
        controller.records.map((record) => record.id),
        contains(pendingId),
      );
      expect(controller.records, hasLength(2));
      expect(
        controller.records.map((record) => record.uri.path),
        contains('/second'),
      );
      expect(
        controller.records.map((record) => record.uri.path),
        isNot(contains('/first')),
      );
    },
  );

  test(
    'body byte limit keeps only the newest oversized completed record',
    () async {
      final controller = NetworkCaptureController(
        maxRecords: 200,
        maxBodyBytes: 8,
      );
      await controller.setEnabled(true);
      final first = controller.begin(
        _request(uri: Uri.parse('https://api.worldo.ai/first')),
      );
      controller.complete(first!, _response('1234'));
      final oversized = controller.begin(
        _request(uri: Uri.parse('https://api.worldo.ai/oversized')),
      );
      controller.complete(oversized!, _response('0123456789'));

      expect(controller.records, hasLength(1));
      expect(controller.records.single.uri.path, '/oversized');
      expect(controller.records.single.responseBody!.text, '0123456789');
    },
  );
}

TransportRequest _request({
  Uri? uri,
  Map<String, String> headers = const <String, String>{},
  List<int>? bodyBytes,
}) {
  return TransportRequest(
    method: 'POST',
    uri: uri ?? Uri.parse('https://api.worldo.ai/api/v1/test'),
    headers: headers,
    bodyBytes: bodyBytes,
    timeoutMs: 1000,
  );
}

TransportResponse _response(String body) {
  return TransportResponse(
    statusCode: 200,
    headers: const <String, String>{'content-type': 'text/plain'},
    body: body,
    bodyBytes: utf8.encode(body),
  );
}

class _CallbackTransport implements HttpTransport {
  const _CallbackTransport(this.callback);

  final Future<TransportResponse> Function(TransportRequest request) callback;

  @override
  Future<TransportResponse> send(TransportRequest request) => callback(request);
}

class _ThrowingCaptureController extends NetworkCaptureController {
  _ThrowingCaptureController({this.throwOnBegin = true});

  final bool throwOnBegin;

  @override
  String? begin(TransportRequest request) {
    if (throwOnBegin) throw StateError('capture begin failed');
    return 'capture-id';
  }

  @override
  void complete(String id, TransportResponse response) {
    throw StateError('capture complete failed');
  }

  @override
  void fail(String id, Object error) {
    throw StateError('capture fail failed');
  }
}
