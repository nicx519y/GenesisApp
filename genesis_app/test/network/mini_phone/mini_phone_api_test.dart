import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import '../../support/mini_phone_chat_backend.dart';

void main() {
  test(
    'all 16 routes use Chat prefix, typed reads and empty write responses',
    () async {
      final b = PhoneBackend(), a = PhoneBackend();
      final api = b.api;
      await api.home('w');
      await api.unread('w');
      await api.sessions('w');
      await api.messages('w', 9);
      await api.send('w', 'c', 'request', 'Hello');
      await api.readSession(9);
      await api.notifications('w');
      await api.readPosts('w');
      await api.posts('w');
      await api.detail('w', 8);
      await api.createPost('w', 'post', 'Text');
      await api.like('w', 8);
      await api.unlike('w', 8);
      await api.comments('w', 8);
      await api.comment(
        'w',
        8,
        'comment',
        'Reply',
        replyToCommentId: 9007199254740993,
      );
      await api.album('w');
      expect(b.requests.length, 16);
      expect(
        b.requests.every(
          (r) => r.uri.path.startsWith('/aitown-chat/api/v1/phone/'),
        ),
        isTrue,
      );
      expect(b.body(b.calls('dm_session/read').single), {'dm_session_id': 9});
      expect(b.body(b.calls('post/notifications/read').single), {
        'world_id': 'w',
      });
      expect(b.body(b.calls('post/like').single), {
        'world_id': 'w',
        'post_id': 8,
      });
      expect(b.body(b.calls('post/unlike').single), {
        'world_id': 'w',
        'post_id': 8,
      });
      expect(
        b.body(b.calls('comment/create').single)['reply_to_comment_id'],
        9007199254740993,
      );
      expect(b.calls('home').single.uri.queryParameters, {'world_id': 'w'});
      expect(a.requests, isEmpty);
    },
  );
  test(
    'filter is sent to server before pagination; text/content and album URL stay distinct',
    () async {
      final b = PhoneBackend();
      final posts = await b.api.posts(
        'w',
        pn: 3,
        author: const PhonePerson('u', 'Player', '', type: 1),
      );
      expect(b.requests.single.uri.queryParameters, {
        'world_id': 'w',
        'author_type': '1',
        'author_id': 'u',
        'pn': '3',
        'rn': '10',
      });
      expect(posts.list.single.text, 'Post body');
      await b.api.createPost(
        'w',
        'r',
        'Body',
        image: 'https://image.example/x',
      );
      expect(b.body(b.requests.last), {
        'world_id': 'w',
        'client_request_id': 'r',
        'content': 'Body',
        'image': 'https://image.example/x',
      });
      expect((await b.api.detail('w', 8)).content, 'Post body');
    },
  );
  test(
    'HTTP 200 error and malformed envelope never become empty success',
    () async {
      final b = PhoneBackend();
      b.respond = (_) => {'err_no': 10001, 'err_msg': 'Sign in', 'data': {}};
      await expectLater(
        b.api.send('w', 'c', 'r', 'text'),
        throwsA(isA<ApiException>()),
      );
      b.respond = (_) => {'data': {}};
      await expectLater(b.api.home('w'), throwsA(isA<ApiException>()));
    },
  );
  test(
    'native int64 precision, complete batch, event identity and no location required',
    () {
      const id = 9007199254740993;
      final event = phoneEvent('event', [
        phoneMessage(id),
        phoneMessage(id + 1),
      ]);
      expect(event.messages.map((m) => m.id), [id, id + 1]);
      expect(chatroomEventType(event), 'phone.messages.delivered');
      expect(
        () => PhoneMessage.fromJson({...phoneMessage(1), 'message_id': 1.0}),
        throwsFormatException,
      );
      expect(
        () => phoneEvent('e', [phoneMessage(1)], world: 'other'),
        throwsFormatException,
      );
      final failed = phoneEvent(
        'f',
        [],
        requestId: 'r',
        failure: 'Not enough gems',
      );
      expect(failed.failure, 'Not enough gems');
    },
  );
  test('notification events retain each fact, even on the same post', () {
    ChatroomPhoneEvent event(String id) =>
        chatroomEventFromV2Message(
              ChatroomV2Message.fromJson({
                'type': 'phone.post.notification.created',
                'stream_type': '',
                'world_id': 'w',
                'err_no': 0,
                'payload': {...phoneNotification(), 'event_id': id},
              }),
            )
            as ChatroomPhoneEvent;
    expect(event('a').notification!.postId, event('b').notification!.postId);
    expect(event('a').eventId, isNot(event('b').eventId));
  });
}
