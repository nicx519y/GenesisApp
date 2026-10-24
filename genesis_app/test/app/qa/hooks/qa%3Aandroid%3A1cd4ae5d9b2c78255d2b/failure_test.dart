import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A1cd4ae5d9b2c78255d2b/hook.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import 'package:genesis_flutter_android/app/qa/qa_bridge.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

class UnusedStore implements UserSessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected session mutation');
}

class Dataset extends WorldDataset {
  Dataset()
    : super(
        resource: 'r',
        owner: 'qa_test_world_r',
        currentOwner: () async => 'qa_test_world_r',
        currentResource: () => true,
        list: () async => {},
        fetch: (_, __) async => {},
      );
  final raw = <String, dynamic>{
    'stats': {'tick_cnt': 7},
    'info': {'current_time': 'before'},
  };
  @override
  Future<JsonMap> selected(String endpoint) async => copyWorldJson(raw);
}

class Owner extends TickPreparation {
  Owner() : super(QaBridge(UnusedStore(), token: 'test', buildId: 'test')) {
    dataset = Dataset();
  }
  bool owned = true;
  @override
  String get worldId => 'owned-world';
  @override
  Future<void> requireOwner() async {
    if (!owned) throw StateError('Resource changed');
  }
}

TransportRequest request({
  String world = 'owned-world',
  String path = '/api/v1/world/tick',
  String? raw,
  NetworkCancellationToken? cancellation,
}) => TransportRequest(
  method: 'POST',
  uri: Uri.parse('https://qa.invalid' + path),
  headers: const {},
  bodyBytes: utf8.encode(raw ?? jsonEncode({'world_id': world})),
  timeoutMs: 1000,
  cancellationToken: cancellation,
);
void main() {
  test(
    'only first owned request fails, retry enters real completion attempt, timer is released',
    () async {
      final owner = Owner();
      // One owner is used for every observation and transport call in this test.
      final actual = RetryFault(owner)
        ..active = true
        ..newRound = 8;
      try {
        expect(await actual.respond(request(world: 'foreign')), isNull);
        expect(
          await actual.respond(
            request(path: '/api/v1/other', raw: 'malformed'),
          ),
          isNull,
        );
        expect(actual.requests, 0);
        final first = await actual.respond(request());
        expect(jsonDecode(first!.body)['err_no'], 50001);
        expect(actual.firstResponse!['worldAdvanced'], false);
        expect(actual.firstResponse!['insufficientBalance'], false);
        expect(actual.attempt.submissions, 0);
        expect((owner.dataset as Dataset).raw['stats']['tick_cnt'], 7);
        final second = await actual.respond(request());
        expect(jsonDecode(second!.body)['err_no'], 0);
        expect(actual.requests, 2);
        expect(actual.attempt.submissions, 1);
        expect(actual.retryRequestId, actual.requestId(2));
        await actual.respond(request());
        expect(actual.requests, 3);
        expect(actual.attempt.submissions, 2);
        expect(actual.retryRequestId, actual.requestId(2));
      } finally {
        await actual.attempt.close();
        actual.active = false;
      }
      expect(actual.attempt.released, true);
      expect(actual.attempt.completed, false);
      expect(await actual.respond(request()), isNull);
      expect((owner.dataset as Dataset).raw['stats']['tick_cnt'], 7);
    },
  );
  test(
    'cancellation and lost ownership do not consume first failure',
    () async {
      final owner = Owner(), canceled = NetworkCancellationToken()..cancel();
      final f = RetryFault(owner)..active = true;
      try {
        await expectLater(
          f.respond(request(cancellation: canceled)),
          throwsA(isA<NetworkRequestCancelledException>()),
        );
        expect(f.requests, 0);
        owner.owned = false;
        await expectLater(f.respond(request()), throwsStateError);
        expect(f.requests, 0);
        expect(f.firstResponse, isNull);
      } finally {
        await f.attempt.close();
        f.active = false;
      }
      expect(f.attempt.released, true);
    },
  );
}
