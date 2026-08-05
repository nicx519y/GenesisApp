import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/devtools_websocket_profile.dart';
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

  test('records outgoing JSON as a synthetic WS_SEND request', () async {
    late HttpClientRequestProfile capturedProfile;
    final recorder = DevToolsWebSocketProfile(
      Uri.parse(
        'wss://user:password@api.worldo.ai/aitown-chat/ws'
        '?world_id=world-1&token=secret-token',
      ),
      connectionId: 'ws-test',
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

    await recorder.recordFrame(
      direction: '=>',
      message: jsonEncode({
        'type': 'send_message',
        'token': 'frame-secret',
        'payload': {
          'authorization': 'Bearer nested-secret',
          'content': 'hello',
        },
      }),
    );

    expect(capturedProfile.requestMethod, 'WS_SEND');
    final recordedUri = Uri.parse(capturedProfile.requestUri);
    expect(recordedUri.userInfo, isEmpty);
    expect(recordedUri.queryParameters['world_id'], 'world-1');
    expect(recordedUri.queryParameters['token'], '[REDACTED]');
    expect(Uri.splitQueryString(recordedUri.fragment), {
      'type': 'send_message',
      'connection': 'ws-test',
      'frame': '1',
    });
    expect(
      capturedProfile.requestData.headers,
      containsPair('x-genesis-devtools-synthetic', ['websocket-frame']),
    );
    expect(
      capturedProfile.requestData.headers,
      containsPair('x-genesis-websocket-direction', ['send']),
    );
    final requestJson =
        jsonDecode(utf8.decode(capturedProfile.requestData.bodyBytes))
            as Map<String, dynamic>;
    expect(requestJson['token'], '[REDACTED]');
    expect(
      (requestJson['payload'] as Map<String, dynamic>)['authorization'],
      '[REDACTED]',
    );
    expect(
      (requestJson['payload'] as Map<String, dynamic>)['content'],
      'hello',
    );
    expect(capturedProfile.responseData.statusCode, 200);
    expect(capturedProfile.responseData.bodyBytes, isEmpty);
    expect(capturedProfile.responseData.headers!['content-type'], [
      'application/json; charset=utf-8',
    ]);
    expect(capturedProfile.connectionInfo, {
      'transport': 'websocket',
      'connectionId': 'ws-test',
      'direction': 'send',
      'sequence': 1,
    });
  });

  test('records incoming JSON in the synthetic response body', () async {
    late HttpClientRequestProfile capturedProfile;
    final recorder = DevToolsWebSocketProfile(
      Uri.parse('wss://api.worldo.ai/aitown-chat/ws?world_id=world-1'),
      connectionId: 'ws-test',
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

    await recorder.recordFrame(
      direction: '<=',
      message: '{"type":"ack","msg_id":501,"location_msg_id":201,"err_no":0}',
    );

    expect(capturedProfile.requestMethod, 'WS_RECV');
    expect(
      Uri.splitQueryString(Uri.parse(capturedProfile.requestUri).fragment),
      {
        'type': 'ack',
        'msg_id': '501',
        'location_msg_id': '201',
        'connection': 'ws-test',
        'frame': '1',
      },
    );
    expect(capturedProfile.requestData.bodyBytes, isEmpty);
    expect(
      utf8.decode(capturedProfile.responseData.bodyBytes),
      '{"type":"ack","msg_id":501,"location_msg_id":201,"err_no":0}',
    );
    expect(
      capturedProfile.responseData.headers,
      containsPair('content-type', ['application/json; charset=utf-8']),
    );
    expect(capturedProfile.connectionInfo?['direction'], 'receive');
  });

  test('increments frame sequence and truncates oversized payloads', () async {
    final capturedProfiles = <HttpClientRequestProfile>[];
    final recorder = DevToolsWebSocketProfile(
      Uri.parse('wss://api.worldo.ai/aitown-chat/ws'),
      connectionId: 'ws-test',
      profileFactory:
          ({
            required requestStartTime,
            required requestMethod,
            required requestUri,
          }) {
            final profile = HttpClientRequestProfile.profile(
              requestStartTime: requestStartTime,
              requestMethod: requestMethod,
              requestUri: requestUri,
            )!;
            capturedProfiles.add(profile);
            return profile;
          },
    );

    await recorder.recordFrame(direction: '=>', message: 'first');
    await recorder.recordFrame(
      direction: '<=',
      message: 'x' * (kDevToolsWebSocketProfileMaxBodyBytes + 100),
    );

    expect(
      Uri.splitQueryString(Uri.parse(capturedProfiles[0].requestUri).fragment),
      {'connection': 'ws-test', 'frame': '1'},
    );
    expect(
      Uri.splitQueryString(Uri.parse(capturedProfiles[1].requestUri).fragment),
      {'connection': 'ws-test', 'frame': '2'},
    );
    final body = capturedProfiles[1].responseData.bodyBytes;
    expect(
      body.length,
      lessThanOrEqualTo(kDevToolsWebSocketProfileMaxBodyBytes),
    );
    expect(utf8.decode(body), contains('[truncated'));
  });
}
