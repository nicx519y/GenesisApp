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
  });
}
