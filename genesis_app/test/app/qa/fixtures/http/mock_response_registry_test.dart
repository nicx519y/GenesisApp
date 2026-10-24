import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_registry.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_overrides.dart'
    show QaMockResponseOverrides;
import 'package:genesis_flutter_android/network/http_transport.dart';

TransportRequest request(String path, {String method = 'GET'}) =>
    TransportRequest(
      method: method,
      uri: Uri.parse('https://qa.invalid$path'),
      headers: const {},
      bodyBytes: null,
      timeoutMs: 1000,
    );
const response = TransportResponse(statusCode: 200, headers: {}, body: 'owned');

void main() {
  if (!QaMockResponseOverrides.enabled) {
    test(
      'keeps shared startup wiring inert outside an internal mock QA build',
      () async {
        var called = false;
        final registration = registerQaHook('test:disabled', (_) async {
          called = true;
          return response;
        });
        final repeated = registerQaHook(
          'test:disabled',
          (_) async => response,
          methods: {'POST'},
        );
        expect(await dispatchQaMockResponders(request('/owned')), isNull);
        expect(
          await QaMockResponseOverrides.respond(request('/owned')),
          isNull,
        );
        expect(
          await dispatchQaMockResponders(request('/owned', method: 'POST')),
          isNull,
        );
        expect(called, isFalse);
        registration.close();
        registration.close();
        repeated.close();
      },
    );
    return;
  }
  test(
    'dispatches matching reads through the public entry and releases them',
    () async {
      final registration = registerQaHook(
        'test:dataset',
        (r) async => r.uri.path == '/owned' ? response : null,
      );
      try {
        expect(
          await QaMockResponseOverrides.respond(request('/owned')),
          same(response),
        );
        expect(
          await QaMockResponseOverrides.respond(request('/other')),
          isNull,
        );
        expect(
          await dispatchQaMockResponders(request('/owned', method: 'POST')),
          isNull,
        );
      } finally {
        registration.close();
      }
      registration.close();
      expect(await QaMockResponseOverrides.respond(request('/owned')), isNull);
    },
  );
  test(
    'explicit submit registration dispatches only declared methods',
    () async {
      var calls = 0;
      final methods = <String>{'POST'};
      final registration = registerQaHook('test:submit', (_) async {
        calls++;
        return response;
      }, methods: methods);
      methods.add('DELETE');
      try {
        expect(
          await QaMockResponseOverrides.respond(
            request('/submit', method: 'POST'),
          ),
          same(response),
        );
        expect(await dispatchQaMockResponders(request('/submit')), isNull);
        expect(
          await dispatchQaMockResponders(request('/submit', method: 'DELETE')),
          isNull,
        );
        expect(calls, 1);
      } finally {
        registration.close();
      }
      expect(
        await QaMockResponseOverrides.respond(
          request('/submit', method: 'POST'),
        ),
        isNull,
      );
      expect(calls, 1);
    },
  );
  test(
    'default read registration never receives submission requests',
    () async {
      var calls = 0;
      final registration = registerQaHook('test:read-only', (_) async {
        calls++;
        return response;
      });
      try {
        expect(
          await QaMockResponseOverrides.respond(
            request('/submit', method: 'POST'),
          ),
          isNull,
        );
        expect(calls, 0);
      } finally {
        registration.close();
      }
    },
  );
  test('method registration rejects empty and unknown method declarations', () {
    expect(
      () => registerQaHook('test:empty', (_) async => response, methods: {}),
      throwsArgumentError,
    );
    expect(
      () =>
          registerQaHook('test:invalid', (_) async => response, methods: {'*'}),
      throwsArgumentError,
    );
  });
  test(
    'explicit submit retains ownership release and overlap guards',
    () async {
      final gate = Completer<TransportResponse?>();
      final registration = registerQaHook(
        'test:pending-post',
        (_) => gate.future,
        methods: {'POST'},
      );
      final pending = dispatchQaMockResponders(
        request('/submit', method: 'POST'),
      );
      final checked = expectLater(pending, throwsStateError);
      registration.close();
      gate.complete(response);
      await checked;
      final first = registerQaHook(
        'test:post-one',
        (_) async => response,
        methods: {'POST'},
      );
      final second = registerQaHook(
        'test:post-two',
        (_) async => response,
        methods: {'POST'},
      );
      try {
        await expectLater(
          dispatchQaMockResponders(request('/submit', method: 'POST')),
          throwsStateError,
        );
      } finally {
        first.close();
        second.close();
      }
    },
  );
  test(
    'preserves the existing static lease fallback and owner guard',
    () async {
      var uid = 'qa_test_owner';
      final registration = registerQaHook('test:unrelated', (_) async => null);
      final lease = QaMockResponseOverrides.install(
        resource: 'resource',
        ownerUid: uid,
        currentOwner: () async => uid,
        currentResource: () => true,
        responses: {
          'GET /legacy': {'preserved': true},
        },
      );
      try {
        expect(
          (await QaMockResponseOverrides.respond(request('/legacy')))!.body,
          '{"preserved":true}',
        );
        uid = 'qa_test_foreign';
        await expectLater(
          QaMockResponseOverrides.respond(request('/legacy')),
          throwsStateError,
        );
      } finally {
        lease.restore();
        registration.close();
      }
    },
  );
  test('rejects duplicate registrations and overlapping responders', () async {
    final first = registerQaHook('test:first', (_) async => response);
    final second = registerQaHook('test:second', (_) async => response);
    try {
      expect(
        () => registerQaHook('test:first', (_) async => null),
        throwsStateError,
      );
      await expectLater(
        dispatchQaMockResponders(request('/owned')),
        throwsStateError,
      );
    } finally {
      first.close();
      second.close();
    }
  });
  test('rejects stale responses after release or cancellation', () async {
    final gate = Completer<TransportResponse?>();
    final registration = registerQaHook('test:pending', (_) => gate.future);
    final pending = dispatchQaMockResponders(request('/owned'));
    final checked = expectLater(pending, throwsStateError);
    registration.close();
    gate.complete(response);
    await checked;
    final token = NetworkCancellationToken()..cancel();
    await expectLater(
      dispatchQaMockResponders(request('/owned').withCancellationToken(token)),
      throwsA(isA<NetworkRequestCancelledException>()),
    );
  });
}
