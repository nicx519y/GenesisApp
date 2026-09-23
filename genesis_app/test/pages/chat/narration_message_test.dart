import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_type.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_render_snapshot.dart';
import 'package:genesis_flutter_android/pages/chat/message_parsers/location_chat_message_parsers.dart';

void main() {
  test(
    'narration version boundaries use semantic version, not build suffix',
    () {
      expect(chatroomAppVersionNumber('0.5.1+9999'), 5001);
      expect(chatroomAppVersionNumber('0.5.2+1'), 5002);
      expect(chatroomAppVersionNumber('1.2.3-rc.1'), 1002003);
      expect(chatroomAppVersionNumber(''), 0);
      final message = WorldChatroomMessage.fromHttpMessage(
        ChatroomHttpMessage.fromV2Json({
          'type': 'user',
          'location_id': 'loc-1',
          'location_message_id': 102,
          'sender_type': 'user',
          'sender_id': 'char-1',
          'sender_name': 'Alice',
          'message_type': 'narration',
          'min_app_version': 5002,
          'payload': {'content': '门外下起了雨。'},
        }),
      );
      expect(
        locationChatMessageParserForTesting(message, appVersion: 5001),
        isNull,
      );
      expect(
        locationChatMessageParserForTesting(message, appVersion: 5002),
        isA<TextMessageParser>(),
      );
      expect(
        locationChatMessageParserForTesting(message, appVersion: 5003),
        isA<TextMessageParser>(),
      );
      expect(
        locationChatMessageParserForTesting(
          message.copyWith(minAppVersion: 0),
          appVersion: 0,
        ),
        isA<TextMessageParser>(),
      );
      expect(message.senderType, 'user');
      expect(message.content, '门外下起了雨。');
    },
  );

  test(
    'outgoing modes normalize without changing inbound image compatibility',
    () {
      for (final input in ['', 'invalid', 'text', 'image']) {
        expect(normalizeOutgoingChatroomMessageType(input), 'text');
      }
      expect(normalizeOutgoingChatroomMessageType(' NARRATION '), 'narration');
      expect(
        resolveIncomingChatroomMessageType(
          hasMessageTypeField: false,
          rawMessageType: null,
          senderId: 'nar_pic',
        ),
        'image',
      );
      expect(
        resolveChatroomMessageRenderKind(
          messageType: 'image',
          senderId: 'nar_pic',
        ),
        ChatroomMessageRenderKind.image,
      );
      expect(
        resolveChatroomMessageRenderKind(
          messageType: 'future',
          senderId: 'nar',
        ),
        ChatroomMessageRenderKind.hidden,
      );
    },
  );

  for (final isMe in [false, true]) {
    testWidgets(
      'user narration renders full width without identity, isMe=$isMe',
      (tester) async {
        final message = ChatMessageVm(
          localId: 'note',
          senderId: 'char-1',
          senderName: 'Alice',
          text: '门外下起了雨。',
          isMe: isMe,
          status: 'sent',
          senderType: 'user',
          messageType: 'narration',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: ChatMessageRow(
                  showDateDivider: false,
                  message: message,
                  style: kLocationChatStyle,
                ),
              ),
            ),
          ),
        );
        final bubble = tester.widget<ChatSystemMessage>(
          find.byType(ChatSystemMessage),
        );
        expect(bubble.fullWidth, isTrue);
        expect(bubble.softItalic, isTrue);
        expect(
          bubble.leadingIconColor,
          chatNarratorMessageIconColor(kLocationChatStyle),
        );
        expect(bubble.text, '门外下起了雨。');
        expect(find.text('Alice'), findsNothing);
        expect(find.byType(ChatAvatar), findsNothing);
        expect(message.isSystem, isFalse);
        final frozen = freezeLocationChatReplyMessage(message);
        expect(frozen.messageType, 'narration');
        message.messageType = 'text';
        expect(
          locationChatReplyMessagePresentationEqual(frozen, message),
          isFalse,
        );
      },
    );
  }

  testWidgets('AI narration keeps its existing icon color', (tester) async {
    final message = ChatMessageVm(
      localId: 'ai-note',
      senderId: 'nar',
      senderName: 'Narrator',
      text: 'AI narration',
      isMe: false,
      status: 'sent',
      senderType: 'narrator',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            showDateDivider: false,
            message: message,
            style: kLocationChatStyle,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ChatSystemMessage>(find.byType(ChatSystemMessage))
          .leadingIconColor,
      chatNarratorMessageIconColor(kLocationChatStyle),
    );
  });
}
