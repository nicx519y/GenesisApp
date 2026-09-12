import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/inspiration/inspiration.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_feature_quota_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

Map<String, Object?> _quota(
  String feature, {
  bool member = false,
  int used = 3,
  int consumed = 1,
}) => {
  'feature': feature,
  'membership_status': member ? 1 : 0,
  'is_member': member,
  'scope': member ? 'member_unlimited' : 'trial_lifetime',
  'unlimited': member,
  'limit': member ? null : 3,
  'used': used,
  'remaining': member ? null : (3 - used).clamp(0, 3),
  'reset_at': null,
  'consumed': consumed,
};

const _inspiration = {
  'conversation_round_id': 7,
  'card_id': 0,
  'source_card_id': 0,
  'messages': ['One', 'Two', 'Three'],
  'gateway_request_id': 'request-7',
};
const _formal = {
  'start_conversation_round_id': 7,
  'end_conversation_round_id': 8,
  'newest_message_id': 12,
};
const _candidate = {
  'conversation_round_id': 7,
  'card': {
    'card_id': 9,
    'card_index': 1,
    'is_original': false,
    'generation_state': 'succeeded',
    'can_edit': true,
    'can_delete': false,
    'messages': [],
    'billing': {
      'status': 'not_required',
      'price_cent': null,
      'pricing_version': '',
    },
    'created_at': '2026-09-11 10:00:00',
  },
};
const _operations = [
  ChatroomLlmMessageOperation.edit(globalMessageId: 11, content: 'Edited'),
];

class _Transport implements HttpTransport {
  Object? data = _inspiration;
  Object? quota;
  int code = 0;
  Completer<void>? gate;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    await gate?.future;
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'err_no': code,
        'err_msg': code == 2030 ? 'Feature quota exhausted' : 'server message',
        'data': data,
        if (quota != null) 'quota': quota,
      }),
    );
  }
}

ChatroomHttpApi _api(_Transport transport) => ChatroomHttpApi(
  ApiClient(baseUrl: 'https://chat.test/', transport: transport),
);
Future<ChatroomInspirationResponse> _inspire(ChatroomHttpApi api) =>
    api.getInspirations(worldId: 'w', locationId: 'l', conversationRoundId: 7);
Future<ChatroomMessageMutationResult> _edit(ChatroomHttpApi api) =>
    api.batchMutateLlmMessages(
      worldId: 'w',
      locationId: 'l',
      conversationRoundId: 7,
      operations: _operations,
    );
Future<ChatroomCardMutationResult> _editCard(ChatroomHttpApi api) =>
    api.batchMutateLlmCardMessages(
      worldId: 'w',
      locationId: 'l',
      conversationRoundId: 7,
      cardId: 9,
      operations: _operations,
    );

void main() {
  test(
    'last free inspiration succeeds and cache serialization omits its old quota',
    () async {
      final transport = _Transport()..quota = _quota('inspiration');
      final observed = <ChatroomFeatureQuota>[];
      final api = _api(transport)..onFeatureQuotaRequest = () => observed.add;
      final result = await _inspire(api);
      expect(result.messages, ['One', 'Two', 'Three']);
      expect(result.quota?.remaining, 0);
      expect(result.quota?.consumed, 1);
      expect(observed.single, same(result.quota));
      expect(
        ChatroomInspirationResponse.fromJson(result.toJson()).quota,
        isNull,
      );
      expect(observed, hasLength(1));
    },
  );

  test(
    'both batch success variants preserve authoritative optional quota',
    () async {
      final transport = _Transport()..quota = _quota('conversation_edit');
      final api = _api(transport);
      transport.data = _formal;
      final formal = await _edit(api);
      expect(formal.newestMessageId, 12);
      expect(formal.quota?.remaining, 0);
      transport.data = _candidate;
      final candidate = await _editCard(api);
      expect(candidate.card.cardId, 9);
      expect(candidate.quota?.remaining, 0);
    },
  );

  test(
    'missing malformed and unrelated optional quotas do not invalidate committed responses',
    () async {
      final transport = _Transport();
      final observed = <ChatroomFeatureQuota>[];
      final api = _api(transport)..onFeatureQuotaRequest = () => observed.add;
      for (final invalid in <Object?>[
        null,
        false,
        {},
        {'feature': 'inspiration'},
        {..._quota('conversation_edit'), 'used': -1},
      ]) {
        transport.quota = invalid;
        transport.data = _inspiration;
        expect((await _inspire(api)).quota, isNull);
        transport.data = _formal;
        expect((await _edit(api)).quota, isNull);
        transport.data = _candidate;
        expect((await _editCard(api)).quota, isNull);
      }
      transport.quota = _quota('conversation_edit');
      transport.data = _inspiration;
      expect((await _inspire(api)).quota, isNull);
      expect(observed, isEmpty);
    },
  );

  test(
    '2030 carries optional quota for inspiration and both batch variants',
    () async {
      final transport = _Transport()..code = 2030;
      final observed = <ChatroomFeatureQuota>[];
      final api = _api(transport)..onFeatureQuotaRequest = () => observed.add;
      for (final call in [
        () => _inspire(api),
        () => _edit(api),
        () => _editCard(api),
      ]) {
        transport.quota = _quota(
          observed.isEmpty ? 'inspiration' : 'conversation_edit',
          consumed: 0,
        );
        transport.data = observed.isEmpty ? {} : false;
        await expectLater(
          call(),
          throwsA(
            isA<ChatroomFeatureQuotaException>()
                .having((error) => error.code, 'code', 2030)
                .having((error) => error.quota?.remaining, 'remaining', 0)
                .having((error) => error.quota?.consumed, 'consumed', 0),
          ),
        );
      }
      expect(observed, hasLength(3));
      transport.quota = {'feature': 'inspiration'};
      await expectLater(
        _inspire(api),
        throwsA(
          isA<ChatroomFeatureQuotaException>().having(
            (error) => error.quota,
            'quota',
            isNull,
          ),
        ),
      );
      expect(observed, hasLength(3));
    },
  );

  test(
    'membership null counts remain unlimited and are not converted to zero',
    () async {
      final transport = _Transport()
        ..quota = _quota('inspiration', member: true, used: 51);
      final quota = (await _inspire(_api(transport))).quota!;
      expect(quota.isMember, isTrue);
      expect(quota.unlimited, isTrue);
      expect(quota.used, 51);
      expect(quota.remaining, isNull);
      expect(quota.limit, isNull);
    },
  );

  test(
    'real operation captures observer at request start; GET does not notify',
    () async {
      final gate = Completer<void>();
      final transport = _Transport()
        ..quota = _quota('inspiration')
        ..gate = gate;
      final oldAccount = <ChatroomFeatureQuota>[];
      final newAccount = <ChatroomFeatureQuota>[];
      final api = _api(transport)..onFeatureQuotaRequest = () => oldAccount.add;
      final pending = _inspire(api);
      api.onFeatureQuotaRequest = () => newAccount.add;
      gate.complete();
      await pending;
      expect(oldAccount, hasLength(1));
      expect(newAccount, isEmpty);
      transport.data = {
        'membership_status': 0,
        'is_member': false,
        'inspiration': _quota('inspiration'),
        'conversation_edit': _quota('conversation_edit'),
      };
      await api.getFeatureQuotas();
      expect(newAccount, isEmpty);
    },
  );

  test(
    'only feature 2030 bypasses global reply-action toast; auth remains global',
    () async {
      final transport = _Transport();
      final toasts = <String>[];
      final expired = <String>[];
      final api = GenesisApi(
        transport: transport,
        useMock: false,
        sessionStore: MemoryUserSessionStore(),
        appHeaderProvider: () async => {},
        onChatroomMessageMutationError: toasts.add,
        onSessionExpired: (message) async => expired.add(message),
      );
      for (final call in [
        () => _inspire(api.chatroomHttp),
        () => _edit(api.chatroomHttp),
        () => _editCard(api.chatroomHttp),
      ]) {
        transport.code = 2030;
        await expectLater(
          call(),
          throwsA(isA<ChatroomFeatureQuotaException>()),
        );
        expect(toasts, isEmpty);
        transport.code = 2012;
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>().having((error) => error.code, 'code', 2012),
          ),
        );
        expect(toasts, ['server message']);
        toasts.clear();
        transport.code = 10001;
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>().having((error) => error.code, 'code', 10001),
          ),
        );
        expect(toasts, isEmpty);
      }
      expect(expired, hasLength(3));
      transport.code = 2030;
      await expectLater(
        api.chatroomHttp.getLlmCards(
          worldId: 'w',
          locationId: 'l',
          conversationRoundId: 7,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(toasts, ['Feature quota exhausted']);
    },
  );

  test(
    'mock lifetime inspiration quota is shared across locations, and saved source remains reusable at zero',
    () async {
      final transport = LocalMockGenesisTransport.instance
        ..resetFeatureQuotaUsage();
      final api = ChatroomHttpApi(
        ApiClient(baseUrl: 'https://mock.test/', transport: transport),
      );
      for (var i = 0; i < 3; i++) {
        final result = await api.getInspirations(
          worldId: 'quota-world-$i',
          locationId: 'quota-location-$i',
          conversationRoundId: i + 1,
        );
        expect(result.quota?.remaining, 2 - i);
        expect(result.quota?.consumed, 1);
      }
      final quotas = await api.getFeatureQuotas();
      expect(quotas.isMember, isFalse);
      expect(quotas.inspiration.remaining, 0);
      expect(quotas.conversationEdit.remaining, 3);
      await expectLater(
        api.getInspirations(
          worldId: 'new-world',
          locationId: 'new-location',
          conversationRoundId: 4,
        ),
        throwsA(isA<ChatroomFeatureQuotaException>()),
      );
      final reused = await api.getInspirations(
        worldId: 'quota-world-0',
        locationId: 'quota-location-0',
        conversationRoundId: 1,
      );
      expect(reused.quota?.consumed, 0);
      expect(reused.quota?.remaining, 0);
      expect(reused.messages, isNotEmpty);
    },
  );

  test(
    'mock batch charges once per commit and exhausted batch preserves saved content',
    () async {
      final transport = LocalMockGenesisTransport.instance
        ..resetFeatureQuotaUsage();
      final api = ChatroomHttpApi(
        ApiClient(baseUrl: 'https://mock.test/', transport: transport),
      );
      const world = 'quota-batch-world';
      const location = 'quota-batch-location';
      await api.writeNarrator(
        worldId: world,
        tickId: 'quota-batch-tick',
        locationGroups: const [
          ChatroomNarratorLocationGroup(
            locationId: location,
            locationName: 'Quota fixture',
            locationSummary: '',
            characters: [],
            initialDialogue: [
              ChatroomNarratorDialogueLine(
                charId: 'nar',
                charName: 'Narrator',
                content: 'Original',
              ),
            ],
          ),
        ],
      );
      final initial = await api.getMessages(
        worldId: world,
        locationId: location,
      );
      final target = initial.messages.single;
      for (var i = 0; i < 3; i++) {
        final result = await api.batchMutateLlmMessages(
          worldId: world,
          locationId: location,
          conversationRoundId: target.conversationRoundId,
          operations: [
            ChatroomLlmMessageOperation.edit(
              globalMessageId: target.globalMessageId,
              content: 'Edit $i',
            ),
          ],
        );
        expect(result.quota?.remaining, 2 - i);
        expect(result.quota?.consumed, 1);
      }
      await expectLater(
        api.batchMutateLlmMessages(
          worldId: world,
          locationId: location,
          conversationRoundId: target.conversationRoundId,
          operations: [
            ChatroomLlmMessageOperation.delete(
              globalMessageId: target.globalMessageId,
            ),
          ],
        ),
        throwsA(
          isA<ChatroomFeatureQuotaException>().having(
            (error) => error.quota?.consumed,
            'consumed',
            0,
          ),
        ),
      );
      final history = await api.getMessages(
        worldId: world,
        locationId: location,
      );
      expect(history.messages.single.payload['content'], 'Edit 2');
      final quotas = await api.getFeatureQuotas();
      expect(quotas.conversationEdit.used, 3);
      expect(quotas.inspiration.remaining, 3);
    },
  );
}
