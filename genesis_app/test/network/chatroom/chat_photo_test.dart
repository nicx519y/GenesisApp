import 'dart:convert';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chat_photo_request_store.dart';

class PhotoTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  int error = 0;
  Object price = 3000;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: {},
      body: jsonEncode({
        'err_no': error,
        'err_msg': error == 0 ? 'succ' : 'localized rejection',
        'data': request.uri.path.endsWith('/price')
            ? {'price_cent': price}
            : {
                'source': 'chat',
                'world_id': 'w',
                'location_id': 'l',
                'conversation_round_id': '101',
                'global_message_id': '9007199254740993',
                'message_id': '80',
                'location_message_id': '61',
                'photo': photoJson('generating'),
              },
      }),
    );
  }
}

Map<String, Object?> photoJson(String status) => {
  'task_id': 'task',
  'client_request_id': 'request',
  'status': status,
  'image': status == 'succeeded'
      ? {
          'asset_id': 3,
          'image_url': 'https://example.com/a.png',
          'description': 'A photo',
          'chat_global_message_id': '9007199254740993',
        }
      : null,
  'failure': status == 'failed'
      ? {'code': 'generation_failed', 'message': 'A localized failure'}
      : null,
};
void main() {
  test(
    'candidate photo request, receipt, card query and WS have no formal cursors',
    () {
      const request = ChatPhotoRequest(
        requestId: 'request',
        worldId: 'w',
        locationId: 'l',
        roundId: 101,
        cardId: 9902,
      );
      expect(request.toJson()['conversation_round_id'], '101');
      expect(ChatPhotoRequest.fromJson(request.toJson()).cardId, 9902);
      final receipt = ChatPhotoReceipt.fromJson({
        'source': 'chat',
        'world_id': 'w',
        'location_id': 'l',
        'conversation_round_id': '101',
        'card_id': 9902,
        'global_message_id': '8002',
        'photo': photoJson('generating'),
      });
      expect(receipt.messageId, 0);
      final event = ChatroomV2Message.fromJson(receipt.toMessageJson());
      expect(event.payload['card_id'], 9902);
      final cardMessage = ChatroomLlmCardMessage.fromJson({
        ...receipt.toMessageJson(),
        'card_id': 9902,
        'card_message_index': 3,
      });
      expect(cardMessage.content, '');
      expect(
        ChatPhotoTarget.tryParse({
          'source': 'chat',
          'location_id': 'l',
          'conversation_round_id': '101',
          'card_id': 9902,
          'chat_global_message_id': '8002',
        })!.cardId,
        9902,
      );
    },
  );
  test(
    'regenerating and failed photo retain the previous successful image',
    () {
      for (final status in ['generating', 'failed']) {
        final photo = ChatPhoto.fromJson({
          ...photoJson(status),
          'image': photoJson('succeeded')['image'],
        });
        expect(photo.imageUrl, 'https://example.com/a.png');
        expect(ChatPhoto.fromJson(photo.toJson()), photo);
      }
    },
  );
  test(
    'uncertain card requests are isolated and preserve original parameters',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = ChatPhotoRequestStore(
        'dev',
        'u',
        'w',
        'l',
        roundId: 101,
        cardId: 1,
      );
      final b = ChatPhotoRequestStore(
        'dev',
        'u',
        'w',
        'l',
        roundId: 101,
        cardId: 2,
      );
      const request = ChatPhotoRequest(
        requestId: 'request',
        worldId: 'w',
        locationId: 'l',
        roundId: 101,
        cardId: 1,
      );
      await a.save(request);
      expect((await a.read())!.toJson(), request.toJson());
      expect(await b.read(), isNull);
    },
  );

  test(
    'photo model parses all three contract positions and absent failure text',
    () {
      final photo = photoJson('failed');
      final row = {
        'type': 'live_photo',
        'world_id': 'w',
        'location_id': 'l',
        'global_message_id': 123,
        'message_id': 123,
        'location_message_id': 5,
        'conversation_round_id': 88,
        'sender_type': 'live_photo',
        'message_type': 'image',
        'payload': {'photo': photo, 'content': ''},
      };
      expect(
        ChatPhoto.fromJson(
          ChatroomHttpMessage.fromV2Json(row).payload['photo'],
        ).status,
        ChatPhotoStatus.failed,
      );
      final history = WorldHistoryMessage.fromJson({
        'global_message_id': '123',
        'type': 'live_photo',
        'sender_id': '',
        'sender_name': '',
        'message_type': 'image',
        'content': '',
        'min_app_version': 0,
        'current_time': '',
        'created_at': '2026-11-04T01:00:00Z',
        'location_refs': ['l'],
        'tick': 0,
        'sub_tick': 0,
        'photo': photo,
      });
      expect(history.photo!.status, ChatPhotoStatus.failed);
      expect(
        ChatPhoto.fromJson({
          ...photo,
          'failure': {'code': 'future_code'},
        }).failureMessage,
        '',
      );
    },
  );
  test(
    'active photo journal outlives message eviction and isolates worlds',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ChatPhotoJobStore('dev', 'u', 'w', 'l');
      const request = ChatPhotoRequest(
        requestId: 'r',
        worldId: 'w',
        locationId: 'l',
      );
      final row = <String, dynamic>{
        'location_message_id': 5,
        'conversation_round_id': 88,
        'payload': {'photo': photoJson('generating')},
      };
      await store.update(row, request: request);
      await store.update({
        ...row,
        'payload': {
          'photo': {...photoJson('generating'), 'task_id': 'second'},
        },
      });
      expect(await ChatPhotoJobStore('dev', 'u', 'other', 'l').read(), isEmpty);
      expect(await store.read(), hasLength(2));
      expect(
        (await store.read()).firstWhere(
          (j) => j['photo_request'] != null,
        )['photo_request'],
        request.toJson(),
      );
      await store.update({
        ...row,
        'payload': {'photo': photoJson('failed')},
      });
      expect(await store.read(), hasLength(1));
    },
  );
  test(
    'local contract honors idempotency and parameter conflict without price',
    () async {
      final api = ChatroomHttpApi(
        ApiClient(
          baseUrl: 'https://example.com/',
          transport: LocalMockGenesisTransport.isolated(),
        ),
      );
      const request = ChatPhotoRequest(
        requestId: 'r',
        worldId: 'w',
        locationId: 'l',
      );
      final first = await api.createPhoto(request);
      expect(
        (await api.createPhoto(request)).locationMessageId,
        first.locationMessageId,
      );
      await expectLater(
        api.createPhoto(
          const ChatPhotoRequest(
            requestId: 'r',
            worldId: 'w',
            locationId: 'other',
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 2062)),
      );
    },
  );

  test('legacy journal drops the obsolete price when restoring a request', () {
    final request = ChatPhotoRequest.fromJson({
      'client_request_id': 'old',
      'world_id': 'w',
      'location_id': 'l',
      'expected_price_cent': 3000,
    });
    expect(request.toJson(), {
      'client_request_id': 'old',
      'world_id': 'w',
      'location_id': 'l',
    });
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'price and exact create contract preserve cent and int64 identities',
    () async {
      final transport = PhotoTransport();
      final api = ChatroomHttpApi(
        ApiClient(baseUrl: 'https://example.com/', transport: transport),
      );
      expect(await api.getPhotoPrice(), 3000);
      const request = ChatPhotoRequest(
        requestId: 'request',
        worldId: 'w',
        locationId: 'l',
      );
      final receipt = await api.createPhoto(request);
      expect(receipt.globalMessageId, 9007199254740993);
      expect(receipt.photo.status, ChatPhotoStatus.generating);
      expect(
        transport.requests.last.uri.path,
        '/aitown-chat/api/v1/message/photo/create',
      );
      expect(jsonDecode(utf8.decode(transport.requests.last.bodyBytes!)), {
        'client_request_id': 'request',
        'world_id': 'w',
        'location_id': 'l',
      });
    },
  );
  for (final code in [1001, 10001, 2061, 2062, 2070, 3001, 21001, 9999]) {
    test('create preserves business error $code', () async {
      final transport = PhotoTransport()..error = code;
      final api = ChatroomHttpApi(
        ApiClient(baseUrl: 'https://example.com/', transport: transport),
      );
      await expectLater(
        api.createPhoto(
          const ChatPhotoRequest(
            requestId: 'request',
            worldId: 'w',
            locationId: 'l',
          ),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'business code', code),
        ),
      );
    });
  }
  test('malformed price cannot become a free quote', () async {
    final transport = PhotoTransport()..price = 30.0;
    final api = ChatroomHttpApi(
      ApiClient(baseUrl: 'https://example.com/', transport: transport),
    );
    await expectLater(api.getPhotoPrice(), throwsA(isA<ApiException>()));
    expect(() => chatPhotoId(9007199254740992.0), throwsFormatException);
  });
  test(
    'empty request key is valid for broadcast but not required for identity',
    () {
      final photo = ChatPhoto.fromJson({
        ...photoJson('failed'),
        'client_request_id': '',
      });
      expect(photo.failureMessage, 'A localized failure');
      expect(photo.terminal, isTrue);
    },
  );
  test('outer successful result envelope still contains a failed task', () {
    final event =
        chatroomEventFromV2Message(
              ChatroomV2Message(
                type: 'phone.photo.result',
                worldId: 'w',
                errNo: 0,
                payload: {
                  'source': 'chat',
                  'event_id': 'e',
                  'photo': photoJson('failed'),
                },
              ),
            )
            as ChatroomPhotoResult;
    expect(event.photo!.status, ChatPhotoStatus.failed);
  });
  test('unknown photo source does not enter either photo adapter', () {
    final event =
        chatroomEventFromV2Message(
              const ChatroomV2Message(
                type: 'phone.photo.result',
                payload: {'source': 'unknown'},
              ),
            )
            as ChatroomPhotoResult;
    expect(event.photo, isNull);
  });
  test(
    'journal restores exact uncertain request and isolates accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ChatPhotoRequestStore('dev', 'u', 'w', 'l');
      const request = ChatPhotoRequest(
        requestId: 'r',
        worldId: 'w',
        locationId: 'l',
      );
      await store.save(request);
      expect(
        (await ChatPhotoRequestStore('dev', 'u', 'w', 'l').read())!.toJson(),
        request.toJson(),
      );
      expect(
        await ChatPhotoRequestStore('dev', 'other', 'w', 'l').read(),
        isNull,
      );
      await store.clear('stale');
      expect(await store.read(), isNotNull);
      await store.clear('r');
      expect(await store.read(), isNull);
    },
  );
}
