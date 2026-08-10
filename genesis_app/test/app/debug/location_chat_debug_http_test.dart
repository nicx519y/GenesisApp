import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_debug_http.dart';

void main() {
  test('debug HTTP uses the V2 parser and location cursor fallback', () {
    final parsed = LocationChatDebugHttp.parseLocationMessagesResponseForTesting(
      uri: Uri.parse(
        'https://example.test/aitown-chat/api/v2/messages?world_id=w1&location_id=l1&since=0',
      ),
      decoded: {
        'err_no': 0,
        'err_msg': '',
        'data': {
          'has_more': false,
          'messages': [
            {
              'type': 'tick',
              'stream_type': '',
              'ts': 1780000000000,
              'world_id': 'w1',
              'session_id': '',
              'global_message_id': 11,
              'message_id': 99,
              'location_message_id': 7,
              'location_id': 'l1',
              'conversation_round_id': 5,
              'sender_type': 'tick',
              'sender_id': 'tick',
              'sender_name': 'Tick',
              'user_id': '',
              'client_msg_id': '',
              'message_type': 'text',
              'min_app_version': 304,
              'created_at': '2026-08-10T10:00:00Z',
              'payload': {
                'current_time': 'Day 2, 09:00',
                'tick_no': 2,
                'sub_tick_no': 1,
                'global': 'The bell rang.',
                'story_events': <Object?>[],
                'characters_moved': <Object?>[],
              },
              'err_no': 0,
              'err_msg': '',
            },
          ],
        },
      },
    );

    expect(parsed.newestMessageId, 7);
    expect(parsed.messages.single.businessType, 'tick');
    expect(parsed.messages.single.streamType, isEmpty);
    expect(parsed.messages.single.v2TickPayload, isNotNull);
    expect(parsed.messages.single.v2TickPayload!.globalText, 'The bell rang.');
  });

  test(
    'debug HTTP treats since zero as latest and positive since as older',
    () {
      expect(
        LocationChatDebugHttp.locationMessagesActionForTesting(const {
          'since': '0',
        }),
        'getMessagesLatest',
      );
      expect(
        LocationChatDebugHttp.locationMessagesActionForTesting(const {
          'since': '7',
        }),
        'getMessagesOlder',
      );
      expect(
        LocationChatDebugHttp.locationMessagesActionForTesting(const {}),
        'getMessagesLatest',
      );
    },
  );
}
