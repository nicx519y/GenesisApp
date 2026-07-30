import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/devtools_http_profile.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:http_profile/http_profile.dart';

void main() {
  late bool previousProfilingState;

  setUp(() {
    previousProfilingState = HttpClientRequestProfile.profilingEnabled;
    HttpClientRequestProfile.profilingEnabled = true;
  });

  tearDown(() {
    HttpClientRequestProfile.profilingEnabled = previousProfilingState;
  });

  test('records transport-neutral request and response for DevTools', () async {
    late HttpClientRequestProfile capturedProfile;
    final request = TransportRequest(
      method: 'POST',
      uri: Uri.parse('https://api.worldo.ai/api/v1/search'),
      headers: const {
        'content-type': 'application/json',
        'x-request-id': 'request-1',
      },
      bodyBytes: const [1, 2, 3],
      timeoutMs: 5000,
    );
    final recorder = DevToolsHttpProfile.start(
      request,
      profileFactory:
          ({
            required requestStartTime,
            required requestMethod,
            required requestUri,
          }) {
            capturedProfile = HttpClientRequestProfile.profile(
              requestStartTime: requestStartTime,
              requestMethod: requestMethod,
              requestUri: requestUri,
            )!;
            return capturedProfile;
          },
    );

    expect(recorder, isNotNull);
    await recorder!.completeRequest(request);
    await recorder.completeResponse(
      const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json', 'content-length': '4'},
        body: 'done',
        bodyBytes: [100, 111, 110, 101],
        responsePayloadSizeBytes: 4,
        httpProtocolVersion: 'h2',
      ),
    );

    expect(capturedProfile.requestMethod, 'POST');
    expect(capturedProfile.requestUri, 'https://api.worldo.ai/api/v1/search');
    expect(capturedProfile.requestData.headers, {
      'content-type': ['application/json'],
      'x-request-id': ['request-1'],
    });
    expect(capturedProfile.requestData.bodyBytes, [1, 2, 3]);
    expect(capturedProfile.requestData.endTime, isNotNull);
    expect(capturedProfile.responseData.statusCode, 200);
    expect(capturedProfile.responseData.headers, {
      'content-type': ['application/json'],
      'content-length': ['4'],
    });
    expect(capturedProfile.responseData.bodyBytes, [100, 111, 110, 101]);
    expect(capturedProfile.responseData.endTime, isNotNull);
    expect(capturedProfile.connectionInfo, {
      'transport': 'dio',
      'httpVersion': 'h2',
    });
  });

  test('records transport errors without rethrowing from profiler', () async {
    late HttpClientRequestProfile capturedProfile;
    final request = TransportRequest(
      method: 'GET',
      uri: Uri.parse('https://api.worldo.ai/api/v1/health'),
      headers: const {},
      bodyBytes: null,
      timeoutMs: 5000,
    );
    final recorder = DevToolsHttpProfile.start(
      request,
      profileFactory:
          ({
            required requestStartTime,
            required requestMethod,
            required requestUri,
          }) {
            capturedProfile = HttpClientRequestProfile.profile(
              requestStartTime: requestStartTime,
              requestMethod: requestMethod,
              requestUri: requestUri,
            )!;
            return capturedProfile;
          },
    );

    await recorder!.completeRequest(request);
    await recorder.completeWithError(StateError('connection failed'));

    expect(capturedProfile.requestData.endTime, isNotNull);
    expect(capturedProfile.responseData.error, contains('connection failed'));
    expect(capturedProfile.responseData.endTime, isNotNull);
  });
}
