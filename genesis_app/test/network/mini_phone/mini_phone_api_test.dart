import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import '../../support/mini_phone_chat_backend.dart';

void main() {
  test(
    'request recovery query, virtual IDs and byte limits follow current dev',
    () async {
      final b = PhoneBackend();
      await b.api.messages('w', 9, clientRequestId: 'request');
      expect(
        b.requests.last.uri.queryParameters['client_request_id'],
        'request',
      );
      final virtual = PhoneSession.fromJson({
        ...phoneSession(),
        'dm_session_id': 0,
        'peer_uid': 'peer',
      });
      expect(virtual.id, 0);
      expect(virtual.peerUid, 'peer');
      await expectLater(b.api.messages('w', 0), throwsFormatException);
      await expectLater(b.api.readSession(0), throwsFormatException);
      await expectLater(b.api.sessions('w', rn: 101), throwsArgumentError);
      await expectLater(
        b.api.send('w', 'c', 'request', '界' * 21846),
        throwsArgumentError,
      );
      await b.api.send('w', 'c', 'request', '界' * 21845);
      const image = 'https://cdn.example/x.png?x-oss-process=image/format,webp';
      await b.api.createPost('w', 'post', 'Body', image: image);
      expect(b.body(b.requests.last)['image'], image);
      await expectLater(
        b.api.createPost(
          'w',
          'post',
          'Body',
          image: 'https://user:pass@cdn.example/x',
        ),
        throwsArgumentError,
      );
      final asset = PhoneAlbumAsset.fromJson({
        'asset_id': 1,
        'thumbnail_url': null,
        'image_url': image,
      });
      expect(asset.thumbnail, isEmpty);
      expect(asset.image, image);
    },
  );
  test(
    'posts parse embedded newest-first comments without a total count',
    () async {
      final b = PhoneBackend();
      const newestId = 9007199254740993;
      b.respond = (_) => ok(
        page([
          {
            ...phonePost(),
            'comments': [
              for (var offset = 0; offset < 4; offset++)
                {
                  'comment_id': newestId - offset,
                  'post_id': 8,
                  'author_type': 2,
                  'author_id': 'c',
                  'author_name': 'Character',
                  'text': 'Reply $offset',
                  'comment_type': 2,
                  'reply_to_comment_id': newestId - 4,
                  'reply_to_char_id': 'player-char',
                  'published_at': '2026-10-20T08:00:00Z',
                },
            ],
          },
        ]),
      );
      final post = (await b.api.posts('w')).list.single;
      expect(post.comments.map((c) => c.id), [
        newestId,
        newestId - 1,
        newestId - 2,
        newestId - 3,
      ]);
      expect(post.comments.first.replyToCommentId, newestId - 4);
      expect(post.comments.first.replyToCharId, 'player-char');
      expect(post.comments.first.type, 2);
      expect(b.requests, hasLength(1));
      b.respond = (_) => ok(page([phonePost()]));
      expect((await b.api.posts('w')).list.single.comments, isEmpty);
    },
  );
  test('local mock author list is empty and requires authentication', () async {
    final client = ApiClient(
      baseUrl: 'https://phone.example/',
      transport: LocalMockGenesisTransport.instance,
    );
    await expectLater(
      MiniPhoneApi(client).postAuthors('w'),
      throwsA(isA<ApiException>()),
    );
    final api = MiniPhoneApi(
      client.copyWith(defaultHeaders: {'Authorization': 'Bearer test'}),
    );
    expect(await api.postAuthors('w'), isEmpty);
    expect((await api.posts('w', charId: 'player-char')).list, isEmpty);
  });
  test(
    'all 17 routes use Chat prefix, typed reads and empty write responses',
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
      await api.postAuthors('w');
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
      expect(b.requests.length, 17);
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
      final posts = await b.api.posts('w', pn: 3, charId: 'player-char');
      expect(b.requests.single.uri.queryParameters, {
        'world_id': 'w',
        'char_id': 'player-char',
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
    'author IDs are an unpaginated string list; All omits char_id',
    () async {
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/post/authors')
          ? ok({
              'list': ['c', 'player-char'],
            })
          : null;
      expect(await b.api.postAuthors('w'), ['c', 'player-char']);
      expect(b.calls('post/authors').single.uri.queryParameters, {
        'world_id': 'w',
      });
      for (final charId in <String?>[null, '']) {
        await b.api.posts('w', charId: charId);
        expect(b.requests.last.uri.queryParameters, {
          'world_id': 'w',
          'pn': '1',
          'rn': '10',
        });
      }
      expect(b.calls('post/notifications/read'), isEmpty);
      expect(() => b.api.posts('w', charId: 'c' * 65), throwsArgumentError);
      b.respond = (_) => ok({'list': []});
      expect(await b.api.postAuthors('w'), isEmpty);
      for (final value in <Object?>[
        null,
        {},
        [1],
        [
          {'char_id': 'c'},
        ],
        [''],
      ]) {
        b.respond = (_) => ok({'list': value});
        await expectLater(b.api.postAuthors('w'), throwsFormatException);
      }
      b.respond = (_) => {
        'err_no': 4004,
        'err_msg': 'World unavailable',
        'data': {},
      };
      await expectLater(
        b.api.postAuthors('w'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'World unavailable',
          ),
        ),
      );
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
