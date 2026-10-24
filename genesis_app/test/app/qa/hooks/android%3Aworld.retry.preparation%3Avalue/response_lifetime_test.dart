import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_overrides.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';

TransportRequest request(String path, {String method = 'GET'}) =>
    TransportRequest(
      method: method,
      uri: Uri.parse('https://mock.invalid$path'),
      headers: {},
      bodyBytes: null,
      timeoutMs: 1000,
    );
void main() {
  const path = '/api/v1/direct_message/conversations';
  test(
    'real mode rejects overrides and keeps original mock behavior',
    () async {
      if (QaMockResponseOverrides.enabled) return;
      final original = await LocalMockGenesisTransport.instance.send(
        request(path),
      );
      expect(
        () => QaMockResponseOverrides.install(
          resource: 'case',
          ownerUid: 'qa_test_owner',
          currentOwner: () async => 'qa_test_owner',
          currentResource: () => true,
          responses: {
            'GET $path': {
              'data': {'items': []},
            },
          },
        ),
        throwsStateError,
      );
      expect(
        (await LocalMockGenesisTransport.instance.send(request(path))).body,
        original.body,
      );
    },
  );
  test(
    'actual mock transport overrides only its endpoint and restores the untouched seed',
    () async {
      if (!QaMockResponseOverrides.enabled) return;
      final transport = LocalMockGenesisTransport.instance;
      final original = await transport.send(request(path));
      final health = await transport.send(request('/health'));
      String? owner = 'qa_test_owner';
      bool resource = true;
      final payload = {
        'err_no': 0,
        'data': {'items': []},
      };
      final lease = QaMockResponseOverrides.install(
        resource: 'case',
        ownerUid: owner,
        currentOwner: () async => owner,
        currentResource: () => resource,
        responses: {'GET $path': payload},
      );
      try {
        payload['err_no'] = 99;
        expect(jsonDecode((await transport.send(request(path))).body), {
          'err_no': 0,
          'data': {'items': []},
        });
        expect((await transport.send(request('/health'))).body, health.body);
        expect(
          await QaMockResponseOverrides.respond(request(path, method: 'POST')),
          null,
        );
        expect(
          () => QaMockResponseOverrides.install(
            resource: 'other',
            ownerUid: owner!,
            currentOwner: () async => owner,
            currentResource: () => true,
            responses: {'GET $path': {}},
          ),
          throwsStateError,
        );
        owner = 'foreign';
        await expectLater(transport.send(request(path)), throwsStateError);
        owner = 'qa_test_owner';
        resource = false;
        await expectLater(transport.send(request(path)), throwsStateError);
      } finally {
        lease.restore();
        lease.restore();
      }
      expect((await transport.send(request(path))).body, original.body);
    },
  );
  test(
    'in-flight lookup cannot survive cleanup or leak into a later Case',
    () async {
      if (!QaMockResponseOverrides.enabled) return;
      final pending = Completer<String?>();
      final first = QaMockResponseOverrides.install(
        resource: 'old',
        ownerUid: 'qa_test_owner',
        currentOwner: () => pending.future,
        currentResource: () => true,
        responses: {'GET $path': {}},
      );
      final response = QaMockResponseOverrides.respond(request(path));
      first.restore();
      final second = QaMockResponseOverrides.install(
        resource: 'new',
        ownerUid: 'qa_test_owner',
        currentOwner: () async => 'qa_test_owner',
        currentResource: () => true,
        responses: {
          'GET $path': {'new': true},
        },
      );
      try {
        pending.complete('qa_test_owner');
        await expectLater(response, throwsStateError);
        first.restore();
        expect(
          jsonDecode(
            (await QaMockResponseOverrides.respond(request(path)))!.body,
          ),
          {'new': true},
        );
      } finally {
        second.restore();
      }
    },
  );
}
