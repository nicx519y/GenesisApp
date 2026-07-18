import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/chatroom_failure_toast.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';

void main() {
  group('shouldShowChatroomFailureToast', () {
    test('hides passive websocket disconnect failures', () {
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'socket_closed',
            message: 'Something went wrong',
            sourceType: 'socket_closed',
          ),
        ),
        isFalse,
      );
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'socket_error',
            message: 'Something went wrong',
            sourceType: 'socket_error',
            requestType: 'socket',
          ),
        ),
        isFalse,
      );
    });

    test('hides automatic reconnect and heartbeat failures', () {
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'connect_failed',
            message: 'Failed to connect to chatroom',
            sourceType: 'connect',
            requestType: 'connect',
          ),
        ),
        isFalse,
      );
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'heartbeat_failed',
            message: 'Something went wrong',
            sourceType: 'heartbeat',
            requestType: 'heartbeat',
          ),
        ),
        isFalse,
      );
    });

    test('hides internal LLM stream ordering failures', () {
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'stream_missing',
            message: 'Missing LLM stream start for round-1',
            sourceType: 'llm_chunk',
          ),
        ),
        isFalse,
      );
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'stream_missing',
            message: 'Missing LLM stream start for round-1',
            sourceType: 'llm_stream_end',
          ),
        ),
        isFalse,
      );
    });

    test('hides internal chatroom maintenance failures', () {
      for (final code in <String>[
        'event_handle_failed',
        'message_cache_failed',
        'message_cache_load_failed',
        'message_history_load_failed',
        'protocol_error',
      ]) {
        expect(
          shouldShowChatroomFailureToast(
            ChatroomFailureEvent(
              code: code,
              message: 'Something went wrong',
              sourceType: code,
            ),
          ),
          isFalse,
        );
      }
    });

    test('keeps user initiated operation failures visible', () {
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'send_message_send_failed',
            message: 'Failed to send chatroom send_message',
            sourceType: 'send_message',
            requestType: 'send_message',
          ),
        ),
        isTrue,
      );
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: 'join_failed',
            message: 'Failed to join chatroom',
            sourceType: 'join',
            requestType: 'join',
          ),
        ),
        isTrue,
      );
    });

    test('hides balance errors handled by the recharge dialog', () {
      expect(
        shouldShowChatroomFailureToast(
          const ChatroomFailureEvent(
            code: '3001',
            message: 'Insufficient balance',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        isFalse,
      );
    });
  });

  group('chatroomFailureToastMessage', () {
    test('maps internal protocol messages to user facing copy', () {
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: 'send_message_send_failed',
            message: 'Failed to send chatroom send_message',
            sourceType: 'send_message',
            requestType: 'send_message',
          ),
        ),
        'Send failed',
      );
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: 'ack_timeout',
            message: 'Timed out waiting for send_message ack',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        'Send failed',
      );
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: 'join_failed',
            message: 'Something went wrong',
            sourceType: 'join',
            requestType: 'join',
          ),
        ),
        'Join failed',
      );
    });

    test('keeps server provided user facing messages', () {
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: 'muted',
            message: 'You cannot send messages right now',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        'You cannot send messages right now',
      );
    });

    test('maps rate limit ack to concise user facing copy', () {
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: '2010',
            message: 'Rate limit exceeded',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        'Too little time between posts. Ease up and try again shortly.',
      );
    });

    test('maps world progress ack to retry copy', () {
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: '2006',
            message: 'World is progressing',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        'The World is progressing. Please try again shortly.',
      );
    });

    test('maps temporary server failure ack to retry copy', () {
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: '5000',
            message: 'Service unavailable',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        'Something went wrong. Please try again later.',
      );
    });

    test('maps unauthorized ack to sign-in copy', () {
      expect(
        chatroomFailureToastMessage(
          const ChatroomFailureEvent(
            code: '10001',
            message: 'Unauthorized',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        "You've been signed out unexpectedly. Please sign in again.",
      );
    });

    test('maps message format ack to edit copy', () {
      for (final code in <String>['1002', '1008']) {
        expect(
          chatroomFailureToastMessage(
            ChatroomFailureEvent(
              code: code,
              message: 'Message format error',
              sourceType: 'ack',
              requestType: 'send_message',
            ),
          ),
          'Message format error. Please edit and send again.',
        );
      }
    });
  });

  group('chatroomFailureToastDuration', () {
    test('keeps rate limit toast visible for four seconds', () {
      expect(
        chatroomFailureToastDuration(
          const ChatroomFailureEvent(
            code: '2010',
            message: 'Rate limit exceeded',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        const Duration(seconds: 4),
      );
    });

    test('keeps world progress toast visible for four seconds', () {
      expect(
        chatroomFailureToastDuration(
          const ChatroomFailureEvent(
            code: '2006',
            message: 'World is progressing',
            sourceType: 'ack',
            requestType: 'send_message',
          ),
        ),
        const Duration(seconds: 4),
      );
    });

    test('keeps temporary server failure toast visible for four seconds', () {
      for (final code in <String>['5000', '10001']) {
        expect(
          chatroomFailureToastDuration(
            ChatroomFailureEvent(
              code: code,
              message: 'Service unavailable',
              sourceType: 'ack',
              requestType: 'send_message',
            ),
          ),
          const Duration(seconds: 4),
        );
      }
    });

    test('keeps message format toast visible for four seconds', () {
      for (final code in <String>['1002', '1008']) {
        expect(
          chatroomFailureToastDuration(
            ChatroomFailureEvent(
              code: code,
              message: 'Message format error',
              sourceType: 'ack',
              requestType: 'send_message',
            ),
          ),
          const Duration(seconds: 4),
        );
      }
    });

    test('keeps the default duration for other failures', () {
      expect(
        chatroomFailureToastDuration(
          const ChatroomFailureEvent(
            code: 'send_failed',
            message: 'Send failed',
            requestType: 'send_message',
          ),
        ),
        const Duration(seconds: 2),
      );
    });
  });
}
