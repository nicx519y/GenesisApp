import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_store.dart';

Map<String, dynamic> phoneMessage(
  int id, {
  String sender = 'char',
  String? requestId,
  int session = 9,
}) => {
  'message_id': id,
  'world_id': 'w',
  'dm_session_id': session,
  'sender_type': sender,
  'sender_id': sender == 'char' ? 'c' : 'u',
  'type': 'text',
  'content': 'Message $id',
  'current_time': 'Day 2/10:00',
  'delivered_at': '2026-10-12T08:00:00Z',
  'client_request_id': requestId,
};
Map<String, dynamic> phoneSession({int unread = 0}) => {
  'dm_session_id': 9,
  'world_id': 'w',
  'char_id': 'c',
  'char_name': 'Character',
  'char_avatar_url': '',
  'unread_count': unread,
  'peer_uid': '',
  'last_message': null,
  'updated_at': '2026-10-12T08:00:00Z',
};
Map<String, dynamic> phoneNotification() => {
  'world_id': 'w',
  'post_id': 8,
  'actor_type': 2,
  'actor_id': 'c',
  'event_type': 'comment',
  'current_time': 'Day 2/10:00',
  'published_at': '2026-10-12T08:00:00Z',
  'read_at': null,
};
Map<String, dynamic> phonePost({bool liked = false}) => {
  'post_id': 8,
  'world_id': 'w',
  'author_type': 2,
  'author_id': 'c',
  'author_name': 'Character',
  'author_avatar_url': '',
  'text': 'Post body',
  'current_time': 'Day 2/10:00',
  'published_at': '2026-10-12T08:00:00Z',
  'image': '',
  'like_count': liked ? 1 : 0,
  'is_liked': liked,
  'comment_count': 0,
};
Map<String, dynamic> phoneDetail({bool liked = false}) => {
  'char_id': 'c',
  'char_name': 'Character',
  'content': 'Post body',
  'image': '',
  'like_count': liked ? 1 : 0,
  'is_liked': liked,
  'comment_count': 0,
  'comments': [],
  'published_at': '2026-10-12T08:00:00Z',
};
Object page(List<Object?> list, {int pn = 1, int rn = 10, int? total}) => {
  'list': list,
  'total': total ?? list.length,
  'pn': pn,
  'rn': rn,
};
Object ok(Object? data) => {'err_no': 0, 'err_msg': 'succ', 'data': data};
ChatroomPhoneEvent phoneEvent(
  String eventId,
  List<Map<String, dynamic>> messages, {
  String? requestId,
  String? failure,
  String world = 'w',
  int session = 9,
}) =>
    chatroomEventFromV2Message(
          ChatroomV2Message.fromJson({
            'type': failure == null
                ? 'phone.messages.delivered'
                : 'phone.reply.updated',
            'stream_type': '',
            'world_id': world,
            'ts': 1,
            'trigger_uid': '',
            'err_no': 0,
            'err_msg': '',
            'payload': {
              'event_id': eventId,
              'dm_session_id': session,
              'client_request_id': requestId,
              if (failure == null) 'messages': messages,
              if (failure != null) ...{
                'message_id': 1,
                'job_status': 'failed',
                'failure': {'message': failure},
              },
            },
          }),
        )
        as ChatroomPhoneEvent;

class PhoneBackend implements HttpTransport {
  FutureOr<Object?> Function(TransportRequest request)? respond;
  final requests = <TransportRequest>[];
  late final api = MiniPhoneApi(
    ApiClient(baseUrl: 'https://phone.example/', transport: this),
  );
  final revision = ValueNotifier(0);
  String? uid = 'u';
  MiniPhoneStore store({String namespace = 'test'}) => MiniPhoneStore(
    api: api,
    worldId: 'w',
    namespace: namespace,
    readUid: () async => uid,
    loadWorld: () async => WorldDetail.fromJson({
      'name': 'World',
      'current_time': 'Day 2/10:00',
      'characters': [
        {'char_id': 'c', 'name': 'Character'},
        {'char_id': 'player-char', 'name': 'Player', 'player_uid': 'u'},
      ],
    }),
    accountRevision: revision,
  );
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final raw = respond == null ? null : await respond!(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {},
      body: jsonEncode(raw ?? defaultResponse(request)),
    );
  }

  Object defaultResponse(TransportRequest r) {
    final suffix = r.uri.path.split('/phone/').last;
    if (r.method == 'POST') return ok({});
    if (suffix == 'home') {
      return ok({
        'dms': {'unread_count': 0, 'list': []},
        'posts': {'unread_count': 0, 'list': []},
      });
    }
    if (suffix == 'unread') return ok({'unread_count': 0, 'char_id': null});
    if (suffix == 'post/detail') return ok(phoneDetail());
    if (suffix == 'post/authors') {
      return ok({
        'list': ['c'],
      });
    }
    return ok(
      page(
        suffix == 'dm_sessions'
            ? [phoneSession()]
            : suffix == 'posts'
            ? [phonePost()]
            : [],
        pn: int.parse(r.uri.queryParameters['pn'] ?? '1'),
      ),
    );
  }

  List<TransportRequest> calls(String suffix) =>
      requests.where((r) => r.uri.path.endsWith('/$suffix')).toList();
  Map<String, dynamic> body(TransportRequest r) =>
      jsonDecode(utf8.decode(r.bodyBytes!)) as Map<String, dynamic>;
}
