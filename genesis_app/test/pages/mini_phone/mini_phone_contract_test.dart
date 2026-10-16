import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import '../../support/mini_phone_chat_backend.dart';

ChatroomPhoneEvent replyEvent(
  String eventId,
  String requestId,
  String status,
) =>
    chatroomEventFromV2Message(
          ChatroomV2Message.fromJson({
            'type': 'phone.reply.updated',
            'stream_type': '',
            'world_id': 'w',
            'err_no': 0,
            'payload': {
              'event_id': eventId,
              'dm_session_id': 9,
              'message_id': 1,
              'client_request_id': requestId,
              'job_status': status,
              'failure': status == 'failed'
                  ? {'message': 'Reply generation failed.'}
                  : null,
            },
          }),
        )
        as ChatroomPhoneEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reply terminal arriving before session discovery is applied after HTTP recovery',
    () async {
      final b = PhoneBackend();
      b.respond = (r) =>
          r.uri.path.endsWith('/dm_sessions') ? ok(page([])) : null;
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      s.receive(replyEvent('early-failure', 'old-request', 'failed'));
      expect(s.replyFailures, isEmpty);
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm_sessions')) {
          return ok(page([phoneSession()]));
        }
        if (r.uri.path.endsWith('/messages')) {
          return ok(
            page([
              {
                ...phoneMessage(1, sender: 'user', requestId: 'old-request'),
                'reply_status': 'pending',
              },
            ]),
          );
        }
        return null;
      };
      await s.refreshSessions();
      await s.refreshMessages('c');
      expect(s.history('c').single.replyStatus, 'failed');
      expect(s.replyFailures['c'], 'Reply generation failed.');
      expect(s.waiting('c'), isNull);
      await s.writesSaved;
    },
  );

  test(
    'local text validation leaves a rejected editable draft rather than an uncertain write',
    () async {
      final b = PhoneBackend(), s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      expect(await s.write('post', 'new', '界' * 21846), isFalse);
      expect(s.pending['post:new']!.rejected, isTrue);
      expect(s.unresolved('post:new'), isFalse);
      expect(b.calls('post/create'), isEmpty);
      expect(await s.write('post', 'new', 'Shorter text'), isTrue);
      expect(b.calls('post/create'), hasLength(1));
      await s.writesSaved;
    },
  );

  test(
    'six virtual rows keep server order and skip history/read until first send',
    () async {
      final b = PhoneBackend();
      var created = false;
      b.respond = (r) {
        if (r.uri.path.endsWith('/dm_sessions')) {
          return ok(
            page([
              for (var i = 1; i <= 6; i++)
                {
                  ...phoneSession(),
                  'char_id': 'char_$i',
                  'char_name': 'Person $i',
                  'dm_session_id': created && i == 2 ? 91 : 0,
                  'updated_at': '',
                },
            ]),
          );
        }
        if (r.uri.path.endsWith('/dm/send')) created = true;
        return null;
      };
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      expect(s.errors, isEmpty);
      expect(s.conversations.map((c) => c.person.id), [
        for (var i = 1; i <= 6; i++) 'char_$i',
      ]);
      for (var i = 1; i <= 6; i++) {
        expect(await s.refreshMessages('char_$i'), isTrue);
        expect(s.sessionFor('char_$i'), isNull);
      }
      await s.markSessionRead(0);
      expect(b.calls('messages'), isEmpty);
      expect(b.calls('dm_session/read'), isEmpty);
      expect(await s.write('dm', 'char_2', 'First message'), isTrue);
      await s.refreshSessions();
      await s.refreshMessages('char_2');
      expect(s.sessions, hasLength(6));
      expect(s.sessionFor('char_2'), 91);
      expect(
        b.calls('messages').last.uri.queryParameters['dm_session_id'],
        '91',
      );
      expect(s.sessionFor('char_1'), isNull);
    },
  );

  test(
    'paged virtual rows merge by world and character and preserve API ordering',
    () async {
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
          ? ok(
              page(
                [
                  {
                    ...phoneSession(),
                    'dm_session_id': 0,
                    'char_id': r.uri.queryParameters['pn'] == '1' ? 'a' : 'b',
                  },
                  if (r.uri.queryParameters['pn'] == '2')
                    {...phoneSession(), 'dm_session_id': 22, 'char_id': 'a'},
                ],
                total: 3,
                pn: int.parse(r.uri.queryParameters['pn']!),
                rn: 1,
              ),
            )
          : null;
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.refreshSessions(next: true);
      expect(s.sessions.map((v) => v.person.id), ['a', 'b']);
      expect(s.sessionFor('a'), 22);
      expect(s.sessionFor('b'), isNull);
    },
  );

  test(
    'player source delivery completes send with no AI waiting or user-ID confusion',
    () async {
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
          ? ok(
              page([
                {...phoneSession(), 'peer_uid': 'other-user'},
              ]),
            )
          : null;
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.write('dm', 'c', 'Hi player');
      final requestId = s.waiting('c')!.id;
      s.receive(
        phoneEvent('own', [
          phoneMessage(1, sender: 'user', requestId: requestId),
        ], requestId: requestId),
      );
      expect(s.waiting('c'), isNull);
      s.receive(
        phoneEvent('incoming', [
          {...phoneMessage(2, sender: 'user'), 'sender_id': 'other-user'},
        ]),
      );
      expect(s.history('c').last.senderId, 'other-user');
      expect(s.personForMessage(s.history('c').last).id, 'c');
      expect(s.charForMessage(s.history('c').last), 'c');
      expect(s.replyFailures, isEmpty);
      await s.writesSaved;
    },
  );

  test(
    'offline old request state recovers by request key and terminals never regress',
    () async {
      final b = PhoneBackend();
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.write('dm', 'c', 'Question');
      final requestId = s.waiting('c')!.id;
      var state = 'pending';
      b.respond = (r) {
        if (!r.uri.path.endsWith('/messages')) return null;
        final exact = r.uri.queryParameters['client_request_id'];
        return ok(
          page(
            exact == requestId
                ? [
                    {
                      ...phoneMessage(1, sender: 'user', requestId: requestId),
                      'reply_status': state,
                      'failure': state == 'failed'
                          ? {'message': 'Reply generation failed.'}
                          : null,
                    },
                  ]
                : [phoneMessage(100)],
          ),
        );
      };
      s.receive(replyEvent('generating', requestId, 'generating'));
      expect(s.waiting('c')!.accepted, isTrue);
      state = 'failed';
      s.scheduleRefresh();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        b
            .calls('messages')
            .any(
              (r) => r.uri.queryParameters['client_request_id'] == requestId,
            ),
        isTrue,
      );
      expect(s.waiting('c'), isNull);
      expect(s.replyFailures['c'], 'Reply generation failed.');
      expect(s.history('c').first.replyStatus, 'failed');
      s.receive(replyEvent('late-generating', requestId, 'generating'));
      expect(s.history('c').first.replyStatus, 'failed');
      expect(s.waiting('c'), isNull);
      state = 'pending';
      b.respond = (r) => r.uri.path.endsWith('/messages')
          ? ok(
              page([
                {
                  ...phoneMessage(1, sender: 'user', requestId: requestId),
                  'reply_status': state,
                },
              ]),
            )
          : null;
      await s.refreshMessages('c');
      expect(s.history('c').first.replyStatus, 'failed');
      expect(s.waiting('c'), isNull);
      await s.writesSaved;
    },
  );

  test(
    'completed history ends wait and generating WS accepts null failure',
    () async {
      final b = PhoneBackend();
      final s = b.store();
      addTearDown(s.dispose);
      await s.ready;
      await s.write('dm', 'c', 'Question');
      final requestId = s.waiting('c')!.id;
      expect(replyEvent('g', requestId, 'generating').failure, isNull);
      b.respond = (r) => r.uri.path.endsWith('/messages')
          ? ok(
              page([
                {
                  ...phoneMessage(1, sender: 'user', requestId: requestId),
                  'reply_status': 'completed',
                  'failure': null,
                },
              ]),
            )
          : null;
      await s.refreshMessages('c');
      expect(s.waiting('c'), isNull);
      s.receive(replyEvent('late', requestId, 'failed'));
      expect(s.replyFailures, isEmpty);
      expect(s.history('c').single.replyStatus, 'completed');
      await s.writesSaved;
    },
  );
}
