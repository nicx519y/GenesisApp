import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/components/chat/chatroom_failure_toast.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_timeline_payload.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

String _readLocationChatImplementationSource() {
  return [
    'lib/pages/chat/location_chat_page.dart',
    'lib/pages/chat/location_chat_panel_connection.dart',
    'lib/pages/chat/location_chat_message_reconciler.dart',
    'lib/pages/chat/location_chat_send_actions.dart',
    'lib/pages/chat/location_chat_message_window.dart',
    'lib/pages/chat/location_chat_identity.dart',
    'lib/pages/chat/location_chat_scroll_actions.dart',
    'lib/pages/chat/location_chat_layout.dart',
    'lib/pages/chat/location_chat_panel_widgets.dart',
    'lib/pages/chat/location_chat_shared.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

void main() {
  test('location chat avoids broad MediaQuery and per-metric bottom jumps', () {
    final pageSource = File(
      'lib/pages/chat/location_chat_page.dart',
    ).readAsStringSync();
    final messageListSource = File(
      'lib/components/chat/shared/chat_ui_message_lists.dart',
    ).readAsStringSync();

    expect(pageSource, contains('MediaQuery.devicePixelRatioOf(context)'));
    expect(
      pageSource,
      isNot(contains('MediaQuery.maybeOf(context)?.devicePixelRatio')),
    );
    expect(pageSource, isNot(contains('with WidgetsBindingObserver')));
    expect(
      pageSource,
      isNot(contains('WidgetsBinding.instance.addObserver(this)')),
    );
    expect(pageSource, isNot(contains('void didChangeMetrics()')));
    expect(
      messageListSource,
      contains('class ChatBottomAnchoringScrollPhysics'),
    );
    expect(messageListSource, contains('return newPosition.maxScrollExtent;'));
  });

  test('chat scroll physics keeps a bottom-aligned viewport anchored', () {
    const physics = ChatBottomAnchoringScrollPhysics();
    final oldPosition = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 500,
      pixels: 500,
      viewportDimension: 600,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    final newPosition = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 800,
      pixels: 500,
      viewportDimension: 300,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    expect(
      physics.adjustPositionForNewDimensions(
        oldPosition: oldPosition,
        newPosition: newPosition,
        isScrolling: false,
        velocity: 0,
      ),
      newPosition.maxScrollExtent,
    );
  });

  test('location chat panel hides the inactive more button by default', () {
    const panel = LocationChatPanel(worldId: 'world-1', locationId: 'loc-1');

    expect(panel.showMoreButton, isFalse);
    expect(panel.unauthorizedHandledByOwner, isFalse);
  });

  test('selected model code reads the user info sibling field', () {
    expect(
      selectedModelCodeFromUserInfo({
        'selected_model_code': 'cc_4_5',
        'user': {'selected_model_code': 'legacy_model'},
      }),
      'cc_4_5',
    );
  });

  test('LLM stream and returned user UGC use their own display decoders', () {
    expect(
      locationChatMessageDisplayTextForTesting(
        _message(
          messageId: 1,
          locationMessageId: 1,
          content: r'Line\nTwo',
          isLlmStreamMessage: true,
        ),
      ),
      'Line\nTwo',
    );
    expect(
      locationChatMessageDisplayTextForTesting(
        _message(messageId: 2, locationMessageId: 2, content: r'Line\nTwo'),
      ),
      r'Line\nTwo',
    );
    expect(
      locationChatMessageDisplayTextForTesting(
        _message(messageId: 3, locationMessageId: 3, content: r'Line\\nTwo'),
      ),
      r'Line\\nTwo',
    );
    expect(
      locationChatMessageDisplayTextForTesting(
        _message(messageId: 4, locationMessageId: 4, content: 'Line\nTwo'),
      ),
      'Line\nTwo',
    );
  });

  test('selected model code accepts a nested compatibility fallback', () {
    expect(
      selectedModelCodeFromUserInfo({
        'user': {'selected_model_code': 'legacy_model'},
      }),
      'legacy_model',
    );
  });

  test('selected model code is empty when cache has no model field', () {
    expect(selectedModelCodeFromUserInfo({'uid': 'u_1'}), isEmpty);
  });

  test(
    'selected role aliases historical character messages to current user',
    () {
      const characters = <Map<String, dynamic>>[
        {'char_id': 'mateo', 'player_uid': 'u_me', 'name': 'Mateo Cruz'},
        {'char_id': 'marcus', 'player_uid': 'u_other', 'name': 'Marcus'},
      ];

      expect(
        locationChatMessageBelongsToCurrentRoleForTesting(
          messageUserId: '',
          messageSenderId: 'mateo',
          currentUserIds: const {'u_me'},
          currentSenderIds: const {'u_me'},
          characters: characters,
          characterPositions: const [],
        ),
        isTrue,
      );
      expect(
        locationChatMessageBelongsToCurrentRoleForTesting(
          messageUserId: 'u_me',
          messageSenderId: 'u_me',
          currentUserIds: const {'u_me'},
          currentSenderIds: const {'u_me'},
          characters: characters,
          characterPositions: const [],
        ),
        isTrue,
      );
      expect(
        locationChatMessageBelongsToCurrentRoleForTesting(
          messageUserId: '',
          messageSenderId: 'marcus',
          currentUserIds: const {'u_me'},
          currentSenderIds: const {'u_me'},
          characters: characters,
          characterPositions: const [],
        ),
        isFalse,
      );
    },
  );

  test('selected role alias resolves nested character position data', () {
    expect(
      locationChatMessageBelongsToCurrentRoleForTesting(
        messageUserId: '',
        messageSenderId: 'mateo',
        currentUserIds: const {'u_me'},
        currentSenderIds: const {'u_me'},
        characters: const [],
        characterPositions: const [
          {
            'location_id': 'loc-1',
            'character': {'id': 'mateo', 'player_uid': 'u_me'},
          },
        ],
      ),
      isTrue,
    );
  });

  test('story visibility uses every local character name', () {
    final roleNamesById = locationChatCurrentRoleNamesByIdForTesting(
      currentUserIds: const {'u_me'},
      currentSenderIds: const {'u_me'},
      characters: const [
        {'char_id': 'mateo', 'player_uid': 'u_me', 'name': 'Mateo Cruz'},
        {'char_id': 'iris', 'player_uid': 'u_me', 'name': 'Iris'},
        {'char_id': 'marcus', 'player_uid': 'u_other', 'name': 'Marcus'},
      ],
      characterPositions: const [],
    );

    expect(roleNamesById, {
      'mateo': 'Mateo Cruz',
      'iris': 'Iris',
      'marcus': 'Marcus',
    });
    expect(
      locationChatStoryEventParagraphVmForTesting(
        const ChatroomStoryEventParagraph(
          timestamp: 'Day 2, 10:15',
          visibility: 'public',
          visibleTo: [],
          text: 'Everyone can see this.',
          clue: '',
        ),
        roleNamesById: roleNamesById,
      )?.visibilityLabel,
      'public',
    );
    expect(
      locationChatStoryEventParagraphVmForTesting(
        const ChatroomStoryEventParagraph(
          timestamp: 'Day 2, 10:20',
          visibility: 'char_only',
          visibleTo: ['mateo', 'marcus', 'iris', 'mateo'],
          text: 'Only local roles can see this.',
          clue: '',
        ),
        roleNamesById: roleNamesById,
      )?.visibilityLabel,
      'Mateo Cruz, Marcus, Iris',
    );
    expect(
      locationChatStoryEventParagraphVmForTesting(
        const ChatroomStoryEventParagraph(
          timestamp: 'Day 2, 10:25',
          visibility: 'char_only',
          visibleTo: ['marcus'],
          text: 'A different player sees this.',
          clue: '',
        ),
        roleNamesById: roleNamesById,
      )?.visibilityLabel,
      'Marcus',
    );
    expect(
      locationChatStoryEventParagraphVmForTesting(
        const ChatroomStoryEventParagraph(
          timestamp: 'Day 2, 10:30',
          visibility: 'char_only',
          visibleTo: ['missing'],
          text: 'The event remains visible without a matching label.',
          clue: '',
        ),
        roleNamesById: roleNamesById,
      )?.visibilityLabel,
      isEmpty,
    );
  });

  test('movement labels resolve known names and retain unknown ids', () {
    expect(
      resolveLocationChatTimelineCharacterNameForTesting(
        characterId: 'char-alice',
        characterPositions: const [
          {
            'location_id': 'loc-cafe',
            'character': {'id': 'char-alice', 'name': 'Alice'},
          },
        ],
      ),
      'Alice',
    );
    expect(
      resolveLocationChatTimelineCharacterNameForTesting(
        characterId: 'char-unknown',
      ),
      'char-unknown',
    );
    expect(
      resolveLocationChatTimelineLocationNameForTesting(
        locationId: 'loc-cafe',
        locations: const [
          {'location_id': 'loc-cafe', 'location_name': 'Cafe'},
        ],
      ),
      'Cafe',
    );
    expect(
      resolveLocationChatTimelineLocationNameForTesting(
        locationId: 'loc-unknown',
      ),
      'loc-unknown',
    );
  });

  test('message reconciliation preserves unmatched local send failures', () {
    final sent = ChatMessageVm(
      localId: 'server-message',
      clientMsgId: 'server-client-id',
      senderId: 'u_me',
      senderName: 'Me',
      avatarUrl: '',
      text: 'Already sent',
      isMe: true,
      status: 'sent',
    );
    final sending = ChatMessageVm(
      localId: 'local-sending',
      clientMsgId: 'client-sending',
      senderId: 'u_me',
      senderName: 'Me',
      avatarUrl: '',
      text: 'Sending',
      isMe: true,
      status: 'sending',
    );
    final failed = ChatMessageVm(
      localId: 'local-failed',
      clientMsgId: 'client-failed',
      senderId: 'u_me',
      senderName: 'Me',
      avatarUrl: '',
      text: 'Insufficient balance',
      isMe: true,
      status: 'failed',
    );
    final reconciled = <ChatMessageVm>[sent];

    preserveUnmatchedLocationChatLocalMessages(
      previous: [sent, sending, failed],
      reconciled: reconciled,
      usedLocalIds: {sent.localId},
    );

    expect(reconciled, [sent, sending, failed]);
  });

  test('ack 3001 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-balance',
      clientMsgId: 'client-balance',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Try this again after top up',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '3001',
        message: 'Insufficient balance',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Try this again after top up');
    expect(messages, isEmpty);
  });

  test('ack 2010 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-rate-limited',
      clientMsgId: 'client-rate-limited',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Send this later',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '2010',
        message: 'Rate limit exceeded',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Send this later');
    expect(messages, isEmpty);
  });

  test('ack 2006 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-world-progressing',
      clientMsgId: 'client-world-progressing',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Send after world progress',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '2006',
        message: 'World is progressing',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Send after world progress');
    expect(messages, isEmpty);
  });

  test('ack 5000 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-server-error',
      clientMsgId: 'client-server-error',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Retry after server recovery',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '5000',
        message: 'Service unavailable',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Retry after server recovery');
    expect(messages, isEmpty);
  });

  test('ack 1002 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-format-error',
      clientMsgId: 'client-format-error',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Edit this message',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '1002',
        message: 'Message format error',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Edit this message');
    expect(messages, isEmpty);
  });

  test('ack 1008 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-send-format-error',
      clientMsgId: 'client-send-format-error',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Edit this send message',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '1008',
        message: 'Send message format error',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Edit this send message');
    expect(messages, isEmpty);
  });

  test('ack 10001 removes the optimistic message and restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-unauthorized',
      clientMsgId: 'client-unauthorized',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Retry this message',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: '10001',
        message: 'Unauthorized',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, 'Retry this message');
    expect(messages, isEmpty);
  });

  test('active socket close send failure restores its draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-socket-closed',
      clientMsgId: 'client-socket-closed',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Put this back in the input',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: 'socket_closed',
        message: 'Something went wrong',
        sourceType: 'socket_closed',
      ),
      localMessage: localMessage,
      messages: messages,
      activeSendFailure: true,
    );

    expect(restoredDraft, 'Put this back in the input');
    expect(messages, isEmpty);
  });

  test('passive socket close does not restore a draft', () {
    final localMessage = ChatMessageVm(
      localId: 'local-passive-socket-closed',
      clientMsgId: 'client-passive-socket-closed',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Do not restore this',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: 'socket_closed',
        message: 'Something went wrong',
        sourceType: 'socket_closed',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, isNull);
    expect(messages, [localMessage]);
  });

  test('only ack 10001 prompts chat login recovery', () {
    expect(
      isChatroomUnauthorizedFailure(
        const ChatroomFailureEvent(code: '10001', message: 'Unauthorized'),
      ),
      isTrue,
    );
    expect(
      isChatroomUnauthorizedFailure(
        const ChatroomFailureEvent(
          code: '5000',
          message: 'Service unavailable',
        ),
      ),
      isFalse,
    );
  });

  test('other send failures keep the optimistic message', () {
    final localMessage = ChatMessageVm(
      localId: 'local-failed',
      clientMsgId: 'client-failed',
      senderId: 'u_me',
      senderName: 'Me',
      text: 'Keep this failed message',
      isMe: true,
      status: 'sending',
    );
    final messages = <ChatMessageVm>[localMessage];

    final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
      failure: const ChatroomFailureEvent(
        code: 'send_failed',
        message: 'Send failed',
      ),
      localMessage: localMessage,
      messages: messages,
    );

    expect(restoredDraft, isNull);
    expect(messages, [localMessage]);
  });

  test('location chat model entry is server driven and world scoped', () {
    final source = _readLocationChatImplementationSource();

    expect(source, isNot(contains("modelLabel: 'CC4.5'")));
    expect(source, contains('sessionStore.readUserInfo()'));
    expect(source, contains('sessionStore.userInfoRevision'));
    expect(source, contains('_handleCachedUserInfoChanged'));
    expect(source, isNot(contains('api.v1.user.info()')));
    expect(source, contains('rootNavigator: true'));
    expect(source, contains('pushNamed<String>('));
    expect(source, contains("arguments: {'world_id': widget.worldId}"));
  });

  testWidgets('location chat model entry opens the current world model list', (
    tester,
  ) async {
    Object? routeArguments;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name != RouteNames.memoryModel) return null;
          routeArguments = settings.arguments;
          return MaterialPageRoute<String>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Model selection list')),
          );
        },
        home: Navigator(
          pages: const [
            MaterialPage<void>(
              child: LocationChatPanel(
                worldId: 'world-current',
                locationId: 'location-current',
                active: true,
              ),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('memory-model-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Model selection list'), findsOneWidget);
    expect(routeArguments, {'world_id': 'world-current'});
  });

  testWidgets('unlaunched location chat hides the model entry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocationChatPanel(
          worldId: 'world-current',
          locationId: 'location-current',
          active: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('memory-model-entry')), findsNothing);
  });

  testWidgets('WebSocket and HTTP narrator nar_pic messages render as images', (
    tester,
  ) async {
    const imageUrl = 'assets/images/default_list_image.png';
    final websocketMessage = WorldChatroomMessage.fromNarratorMessage(
      ChatroomNarratorMessage.fromEnvelope(
        ChatroomEnvelope.fromJson({
          'type': 'nar_new_message',
          'world_id': 'world-current',
          'location_id': 'location-current',
          'global_msg_id': 1,
          'msg_id': 1,
          'location_msg_id': 1,
          'conversation_round_id': 1,
          'sender_id': 'nar_pic',
          'sender_name': 'Narrator',
          'payload': {'sender_type': 'narrator', 'content': imageUrl},
        }),
      ),
    );
    final httpMessage = WorldChatroomMessage.fromHttpMessage(
      ChatroomHttpMessage.fromJson({
        'global_message_id': 2,
        'message_id': 2,
        'location_msg_id': 2,
        'location_id': 'location-current',
        'conversation_round_id': 2,
        'sender_type': 'narrator',
        'sender_id': 'nar_pic',
        'sender_name': 'Narrator',
        'content': imageUrl,
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LocationChatPanel(
          worldId: 'world-current',
          locationId: 'location-current',
          active: false,
          openingPreviewMessages: [websocketMessage, httpMessage],
        ),
      ),
    );
    await tester.pump();

    expect(websocketMessage.senderType, 'narrator');
    expect(httpMessage.senderType, 'narrator');
    expect(websocketMessage.messageType, 'image');
    expect(httpMessage.messageType, 'image');
    expect(find.byType(ChatImageMessage), findsNWidgets(2));
    expect(find.byType(ChatMessageBubble), findsNothing);
    final imageMessages = tester.widgetList<ChatImageMessage>(
      find.byType(ChatImageMessage),
    );
    expect(
      imageMessages.every(
        (widget) =>
            widget.message.senderType == 'image' &&
            widget.message.imageUrl == imageUrl,
      ),
      isTrue,
    );
    expect(find.text(imageUrl), findsNothing);
  });

  testWidgets(
    'location chat only renders nar_pic images and hides unknown types',
    (tester) async {
      const visibleImage = 'assets/images/default_list_image.png';
      final acceptedImage = WorldChatroomMessage.fromHttpMessage(
        ChatroomHttpMessage.fromJson({
          'global_message_id': 1,
          'message_id': 1,
          'location_msg_id': 1,
          'location_id': 'location-current',
          'conversation_round_id': 1,
          'sender_type': 'narrator',
          'sender_id': 'nar_pic',
          'sender_name': 'Narrator',
          'content': visibleImage,
          'message_type': 'image',
        }),
      );
      final blockedImage = WorldChatroomMessage.fromHttpMessage(
        ChatroomHttpMessage.fromJson({
          'global_message_id': 2,
          'message_id': 2,
          'location_msg_id': 2,
          'location_id': 'location-current',
          'conversation_round_id': 2,
          'sender_type': 'narrator',
          'sender_id': 'nar',
          'sender_name': 'Narrator',
          'content': 'https://cdn.example.com/blocked.png',
          'message_type': 'image',
        }),
      );
      final unknown = WorldChatroomMessage.fromHttpMessage(
        ChatroomHttpMessage.fromJson({
          'global_message_id': 3,
          'message_id': 3,
          'location_msg_id': 3,
          'location_id': 'location-current',
          'conversation_round_id': 3,
          'sender_type': 'narrator',
          'sender_id': 'nar_pic',
          'sender_name': 'Narrator',
          'content': 'https://cdn.example.com/future.bin',
          'message_type': 'future_format',
        }),
      );
      final explicitText = WorldChatroomMessage.fromHttpMessage(
        ChatroomHttpMessage.fromJson({
          'global_message_id': 4,
          'message_id': 4,
          'location_msg_id': 4,
          'location_id': 'location-current',
          'conversation_round_id': 4,
          'sender_type': 'narrator',
          'sender_id': 'nar_pic',
          'sender_name': 'Narrator',
          'content': 'Visible narrator text',
          'message_type': 'text',
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'world-current',
            locationId: 'location-current',
            active: false,
            openingPreviewMessages: [
              acceptedImage,
              blockedImage,
              unknown,
              explicitText,
            ],
          ),
        ),
      );
      await tester.pump();

      expect(acceptedImage.messageType, 'image');
      expect(blockedImage.messageType, 'image');
      expect(unknown.messageType, 'future_format');
      expect(explicitText.messageType, 'text');
      expect(find.byType(ChatImageMessage), findsOneWidget);
      expect(find.text('Visible narrator text'), findsOneWidget);
      expect(find.text('https://cdn.example.com/blocked.png'), findsNothing);
      expect(find.text('https://cdn.example.com/future.bin'), findsNothing);
      expect(find.byType(ChatAvatar), findsNothing);
      expect(find.text('Narrator'), findsNothing);
    },
  );

  testWidgets(
    'location chat hides enter events but renders other typed timeline events',
    (tester) async {
      ChatCharacterMovementVm? openedMovement;
      final enter = _timelineMessage(
        messageId: 11,
        senderType: chatroomUserEnterLocationSenderType,
        payload: {
          'char_id': 'char-alice',
          'to_location_id': 'loc-cafe',
          'text': 'Alice entered the cafe.',
        },
      );
      final story = _timelineMessage(
        messageId: 12,
        senderType: chatroomStoryEventsSenderType,
        tickNo: 4,
        subTickNo: 1,
        currentTime: 'Day 2, 00:09:15',
        payload: {
          'location_id': 'loc-station',
          'location_name': 'Old Station',
          'paragraphs': [
            {
              'timestamp': 'Day 2, 10:15',
              'visibility': 'public',
              'visible_to': <String>[],
              'text': 'Alice found a ticket.',
              'clue': 'The date is three years ago.',
            },
            {
              'timestamp': 'Day 2, 10:20',
              'visibility': 'public',
              'visible_to': <String>[],
              'text': 'The platform became quiet.',
              'clue': '',
            },
          ],
        },
      );
      final moved = _timelineMessage(
        messageId: 13,
        senderType: chatroomCharactersMovedSenderType,
        payload: [
          {
            'char_id': 'char-alice',
            'old_loc_id': 'loc-station',
            'to_loc_id': 'loc-cafe',
          },
          {
            'char_id': 'char-unknown',
            'old_loc_id': 'loc-cafe',
            'to_loc_id': 'loc-unknown',
          },
        ],
      );
      final invalid = _timelineMessage(
        messageId: 14,
        senderType: chatroomStoryEventsSenderType,
        payload: '{"broken":',
      );
      final plainTextEnter = _timelineMessage(
        messageId: 15,
        senderType: chatroomUserEnterLocationSenderType,
        payload: 'Dh来到了okkk。',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'world-current',
            locationId: 'location-current',
            active: false,
            openingPreviewMessages: [
              enter,
              story,
              moved,
              invalid,
              plainTextEnter,
            ],
            openingPreviewEntities: const [
              WorldChatroomEntity(
                id: 'char-alice',
                name: 'Alice',
                avatarUrl: '',
                type: WorldChatroomEntityType.character,
                locationId: 'loc-cafe',
                isAi: true,
              ),
            ],
            onCharactersMovedLocationTap: (movement) {
              openedMovement = movement;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ChatUserEnterLocationMessageBubble), findsNothing);
      expect(find.byType(ChatStoryEventsMessageBubble), findsOneWidget);
      expect(find.byType(ChatCharactersMovedMessageBubble), findsOneWidget);
      expect(find.text('Alice entered the cafe.'), findsNothing);
      expect(find.text('Dh来到了okkk。'), findsNothing);
      expect(find.text('Tick 4-1 · Day 2, 00:09:15'), findsNothing);
      expect(find.text('Old Station'), findsNothing);
      expect(find.text('事件'), findsNWidgets(2));
      expect(find.text('Day 2, 10:15'), findsOneWidget);
      expect(find.text('public'), findsNWidgets(2));
      expect(find.text('Alice found a ticket.'), findsOneWidget);
      expect(find.text('The date is three years ago.'), findsOneWidget);
      expect(find.text('Day 2, 10:20'), findsOneWidget);
      expect(find.text('The platform became quiet.'), findsOneWidget);
      expect(find.text('人物去向'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk_rounded), findsNWidgets(3));
      expect(find.text('Alice'), findsNWidgets(2));
      expect(find.text('char-unknown'), findsOneWidget);
      expect(find.text('has gone to'), findsNWidgets(2));
      expect(find.text('loc-cafe'), findsOneWidget);
      expect(find.text('loc-unknown'), findsOneWidget);
      await tester.tap(find.text('loc-unknown'));
      expect(openedMovement?.toLocationId, 'loc-unknown');
      expect(find.text('{"broken":'), findsNothing);
      expect(find.text('sub_tick'), findsNothing);
      expect(find.byType(ChatAvatar), findsNothing);
    },
  );

  testWidgets(
    'HTTP flat story_events 60 and 61 render the same event bubbles as WS',
    (tester) async {
      WorldChatroomMessage storyMessage({
        required int globalMessageId,
        required int messageId,
        required int locationMessageId,
        required String timestamp,
        required String text,
        required String clue,
      }) {
        return WorldChatroomMessage.fromHttpMessage(
          ChatroomHttpMessage.fromJson({
            'global_message_id': globalMessageId,
            'message_id': messageId,
            'location_message_id': locationMessageId,
            'location_id': 'loc_1_1_1',
            'conversation_round_id': 7003,
            'sender_type': 'story_events',
            'sender_id': 'tick',
            'sender_name': 'SubTick',
            'user_id': null,
            'content': jsonEncode({
              'location_id': 'loc_1_1_1',
              'timestamp': timestamp,
              'visibility': 'char_only',
              'visible_to': ['char_1'],
              'text': text,
              'clue': clue,
            }),
            'message_type': 'text',
            'current_time': 'Day 2, 00:09:15',
            'tick_no': 4,
            'sub_tick_no': 1,
            'created_at': '2026-08-06 20:57:54',
          }),
        );
      }

      final message60 = storyMessage(
        globalMessageId: 6140,
        messageId: 60,
        locationMessageId: 31,
        timestamp: 'Day 2, 00:08:30',
        text: '中年男人把录音带塞进桌角的旧录音机。',
        clue: '问他为什么不敢让你听完。',
      );
      final message61 = storyMessage(
        globalMessageId: 6141,
        messageId: 61,
        locationMessageId: 32,
        timestamp: 'Day 2, 00:09:00',
        text: '录音机开始播放，第三人的声音从磁带深处浮出来。',
        clue: '去辨认磁带里的耳语者。',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'w_LV7MN3',
            locationId: 'loc_1_1_1',
            active: false,
            openingPreviewMessages: [message60, message61],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ChatStoryEventsMessageBubble), findsNWidgets(2));
      expect(find.text('Tick 4-1 · Day 2, 00:09:15'), findsNothing);
      expect(find.text('loc_1_1_1'), findsNothing);
      expect(find.text('Day 2, 00:08:30'), findsOneWidget);
      expect(find.text('中年男人把录音带塞进桌角的旧录音机。'), findsOneWidget);
      expect(find.text('问他为什么不敢让你听完。'), findsOneWidget);
      expect(find.text('Day 2, 00:09:00'), findsOneWidget);
      expect(find.text('录音机开始播放，第三人的声音从磁带深处浮出来。'), findsOneWidget);
      expect(find.text('去辨认磁带里的耳语者。'), findsOneWidget);
      expect(find.textContaining('"location_id"'), findsNothing);
    },
  );

  testWidgets('HTTP and WSS story_events share the same bubble layout', (
    tester,
  ) async {
    final httpMessage = _timelineMessage(
      messageId: 201,
      senderType: chatroomStoryEventsSenderType,
      tickNo: 5,
      subTickNo: 2,
      currentTime: 'Day 3, 08:30:00',
      payload: {
        'location_id': 'location-current',
        'timestamp': 'Day 3, 08:29:00',
        'visibility': 'public',
        'visible_to': <String>[],
        'text': 'HTTP event body.',
        'clue': 'HTTP event clue.',
      },
    );
    final websocketMessage = _wssStoryTimelineMessage(
      messageId: 202,
      locationMessageId: 202,
      tickNo: 5,
      subTickNo: 2,
      currentTime: 'Day 3, 08:30:00',
      payload: {
        'location_id': 'location-current',
        'timestamp': 'Day 3, 08:29:30',
        'visibility': 'public',
        'visible_to': <String>[],
        'text': 'WSS event body.',
        'clue': 'WSS event clue.',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LocationChatPanel(
          worldId: 'world-current',
          locationId: 'location-current',
          active: false,
          openingPreviewMessages: [httpMessage, websocketMessage],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatStoryEventsMessageBubble), findsNWidgets(2));
    expect(find.text('Tick 5-2 · Day 3, 08:30:00'), findsNothing);
    expect(find.text('事件'), findsNWidgets(2));
    expect(find.byIcon(Icons.push_pin_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNWidgets(2));
    expect(find.text('public'), findsNWidgets(2));
    expect(find.text('Day 3, 08:29:00'), findsOneWidget);
    expect(find.text('HTTP event body.'), findsOneWidget);
    expect(find.text('HTTP event clue.'), findsOneWidget);
    expect(find.text('Day 3, 08:29:30'), findsOneWidget);
    expect(find.text('WSS event body.'), findsOneWidget);
    expect(find.text('WSS event clue.'), findsOneWidget);
  });

  testWidgets('location chat updates when cached selected model arrives', (
    tester,
  ) async {
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUserInfo({'uid': 'u_1'});
    final services = ServiceRegistry.build(
      config: const AppConfig(useMock: true),
      sessionStoreOverride: sessionStore,
    );

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(
          home: LocationChatPanel(
            worldId: 'world-current',
            locationId: 'location-current',
            active: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Model'), findsOneWidget);

    await sessionStore.saveUserInfo({
      'uid': 'u_1',
      'selected_model_code': 'luxury_selection_v4',
    });
    await tester.pump();

    expect(find.text('luxury_selection_v4'), findsOneWidget);
    expect(find.text('Model'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('location chat background falls back to bundled default when empty', () {
    expect(
      resolveLocationChatBackgroundUrlForTesting(imageUrl: ''),
      'assets/images/map_default/location_default.webp',
    );
  });

  test('location chat background maps predata default CDN image to asset', () {
    expect(
      resolveLocationChatBackgroundUrlForTesting(
        imageUrl: 'https://cdn-001.worldo.ai/predata/location_default.webp',
      ),
      'assets/images/map_default/location_default.webp',
    );
  });

  test('message sender id matches only character char id', () {
    const characters = <Map<String, dynamic>>[
      {
        'char_id': 'char-role',
        'player_uid': 'user-role',
        'name': 'Character Name',
        'player_username': 'Player Username',
      },
    ];

    expect(
      resolveLocationChatMessageSenderNameForTesting(
        senderId: 'char-role',
        senderName: 'Pushed Name',
        characters: characters,
      ),
      'Character Name',
    );
    expect(
      resolveLocationChatMessageSenderNameForTesting(
        senderId: 'user-role',
        senderName: 'Pushed Name',
        characters: characters,
      ),
      'Pushed Name',
    );
  });

  test('matched character avatar resolves its image resource object', () {
    const xlUrl = 'https://example.test/character_800_600.webp';
    const smUrl = 'https://example.test/character_400_300.webp';
    const entityUrl = 'https://example.test/entity.webp';
    const characters = <Map<String, dynamic>>[
      {
        'char_id': 'char-role',
        'avatar': {
          'sm_url': smUrl,
          'xl_url': xlUrl,
          'object_key': 'uploads/character_800_600.webp',
        },
      },
    ];

    expect(
      resolveLocationChatMessageAvatarForTesting(
        senderId: 'char-role',
        characters: characters,
        entitiesById: const {
          'CHAR-ROLE': WorldChatroomEntity(
            id: 'char-role',
            name: 'Entity Role',
            avatarUrl: entityUrl,
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
          ),
        },
      ),
      xlUrl,
    );
    expect(
      resolveLocationChatMessageAvatarForTesting(
        senderId: 'entity-role',
        characters: const <Map<String, dynamic>>[],
        entitiesById: const {
          'ENTITY-ROLE': WorldChatroomEntity(
            id: 'entity-role',
            name: 'Entity Role',
            avatarUrl: entityUrl,
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
          ),
        },
      ),
      entityUrl,
    );
    expect(
      resolveLocationChatMessageAvatarForTesting(
        userId: 'user-role',
        senderId: 'unknown-sender',
        characters: const <Map<String, dynamic>>[],
        entitiesById: const {
          'user-role': WorldChatroomEntity(
            id: 'user-role',
            name: 'User Role',
            avatarUrl: entityUrl,
            type: WorldChatroomEntityType.player,
            locationId: 'loc-1',
          ),
        },
      ),
      entityUrl,
    );
    expect(
      resolveLocationChatMessageAvatarForTesting(
        senderId: 'missing-role',
        characters: characters,
      ),
      isEmpty,
    );
  });

  testWidgets('inactive opening preview uses entity avatar', (tester) async {
    const avatarAsset = 'assets/images/default_list_image.png';
    await tester.pumpWidget(
      const MaterialApp(
        home: LocationChatPanel(
          worldId: 'origin-preview',
          locationId: 'loc-1',
          active: false,
          openingPreviewMessages: [
            WorldChatroomMessage(
              messageId: 0,
              conversationRoundId: 'opening-preview-0',
              roundOrder: 0,
              locationId: 'loc-1',
              senderType: 'character',
              senderId: 'char-role',
              senderName: 'Preview Role',
              content: 'Opening line.',
              createdAt: null,
            ),
          ],
          openingPreviewEntities: [
            WorldChatroomEntity(
              id: 'CHAR-ROLE',
              name: 'Preview Role',
              avatarUrl: avatarAsset,
              type: WorldChatroomEntityType.character,
              locationId: 'loc-1',
              isAi: true,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<ChatAvatar>(find.byType(ChatAvatar));
    expect(avatar.imageUrl, avatarAsset);
  });

  test('name list uses AI role names instead of real user names', () {
    const state = WorldChatroomState(
      entitiesByLocation: {
        'loc-1': [
          WorldChatroomEntity(
            id: 'ai-1',
            name: 'Alice',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
            isAi: true,
          ),
          WorldChatroomEntity(
            id: 'user-1',
            name: 'Real User Role',
            avatarUrl: '',
            type: WorldChatroomEntityType.player,
            locationId: 'loc-1',
          ),
          WorldChatroomEntity(
            id: 'ai-2',
            name: 'Guide',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
            isAi: true,
          ),
        ],
        'loc-alias': [
          WorldChatroomEntity(
            id: 'ai-1',
            name: 'Alice',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-alias',
            isAi: true,
          ),
        ],
      },
    );

    expect(
      resolveLocationChatAiRoleNamesForTesting(state, ['loc-1', 'loc-alias']),
      ['Alice', 'Guide'],
    );
  });

  test('message report target prefers global message id', () {
    expect(
      locationChatMessageReportTargetIdForTesting(
        ChatMessageVm(
          localId: 'local-fallback',
          clientMsgId: 'client-fallback',
          globalMessageId: 90001,
          messageId: 1001,
          locationMessageId: 101,
          senderId: 'u_peer',
          senderName: 'Peer',
          text: 'hello',
          isMe: false,
          status: 'sent',
        ),
      ),
      '90001',
    );
  });

  test('message report target is empty when global message id is absent', () {
    expect(
      locationChatMessageReportTargetIdForTesting(
        ChatMessageVm(
          localId: 'local-fallback',
          clientMsgId: 'client-fallback',
          messageId: 1001,
          locationMessageId: 101,
          senderId: 'u_peer',
          senderName: 'Peer',
          text: 'hello',
          isMe: false,
          status: 'sent',
        ),
      ),
      '',
    );

    expect(
      locationChatMessageReportTargetIdForTesting(
        ChatMessageVm(
          localId: 'local-fallback',
          clientMsgId: 'client-fallback',
          senderId: 'u_peer',
          senderName: 'Peer',
          text: 'pending',
          isMe: false,
          status: 'sending',
        ),
      ),
      '',
    );
  });

  test('message local id uses location message id as queue key', () {
    final first = _message(
      messageId: 1080,
      locationMessageId: 80,
      senderType: 'narrator',
      senderId: 'nar',
      content: 'narrator 80',
    );
    final second = _message(
      messageId: 1083,
      locationMessageId: 83,
      senderType: 'narrator',
      senderId: 'nar',
      content: 'narrator 83',
    );

    expect(locationChatMessageLocalIdForTesting(first), 'location-loc-1-80');
    expect(locationChatMessageLocalIdForTesting(second), 'location-loc-1-83');
    expect(
      locationChatMessageLocalIdForTesting(first),
      isNot(locationChatMessageLocalIdForTesting(second)),
    );
  });

  test('timeline messages use world message id as local key', () {
    const first = WorldChatroomMessage(
      messageId: 1080,
      locationMessageId: 0,
      conversationRoundId: '80',
      roundOrder: 0,
      locationId: 'loc-1',
      senderType: 'story_events',
      senderId: 'sub_tick',
      senderName: 'sub_tick',
      content: '{}',
      createdAt: null,
    );
    const second = WorldChatroomMessage(
      messageId: 1083,
      locationMessageId: 83,
      conversationRoundId: '80',
      roundOrder: 0,
      locationId: 'loc-1',
      senderType: 'story_events',
      senderId: 'sub_tick',
      senderName: 'sub_tick',
      content: '{}',
      createdAt: null,
    );

    expect(locationChatMessageLocalIdForTesting(first), 'message-loc-1-1080');
    expect(locationChatMessageLocalIdForTesting(second), 'message-loc-1-1083');
    expect(
      locationChatMessageLocalIdForTesting(first),
      isNot(locationChatMessageLocalIdForTesting(second)),
    );
  });

  test('local hydrate ignores stale disposed provided chatroom services', () {
    final panelSource = _readLocationChatImplementationSource();
    final serviceSource = File(
      'lib/network/chatroom/world_chatroom_service.dart',
    ).readAsStringSync();

    expect(serviceSource, contains('bool get isDisposed => _disposed;'));
    expect(panelSource, contains('int _serviceGeneration = 0;'));
    expect(
      panelSource,
      contains('_startHydrateLocalMessages(provided, services);'),
    );
    expect(
      panelSource,
      isNot(contains('unawaited(_hydrateLocalMessages(provided, services))')),
    );
    expect(panelSource, contains('identical(_service, service)'));
    expect(panelSource, contains('!service.isDisposed'));
    expect(panelSource, contains('on ChatroomProtocolException catch (error)'));
    expect(
      panelSource,
      contains('.catchError((Object error, StackTrace stackTrace)'),
    );
    expect(
      panelSource,
      contains('Error.throwWithStackTrace(error, stackTrace)'),
    );
    expect(panelSource, contains('hydrateLocalStaleService'));
    expect(panelSource, contains('_serviceGeneration++;'));
  });

  test(
    'visible location chat messages keep latest continuous location id suffix',
    () {
      final visible = visibleLocationChatMessagesForTesting([
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(
          messageId: 30,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick before gap',
        ),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(
          messageId: 45,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick in visible range',
        ),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ]);

      expect(visible.map((message) => message.messageId), [40, 45, 50]);
      expect(
        locationChatMessageGapFillCursorForTesting([
          _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
          _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
          _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
        ]),
        4,
      );
    },
  );

  test(
    'visible location chat messages render all continuous location messages',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'one'),
        _message(
          messageId: 15,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick',
        ),
        _message(messageId: 20, locationMessageId: 2, content: 'two'),
        _message(messageId: 30, locationMessageId: 3, content: 'three'),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.messageId),
        [10, 15, 20, 30],
      );
      expect(locationChatMessageGapFillCursorForTesting(source), 0);
    },
  );

  test(
    'visible location chat messages insert timeline events by world message id',
    () {
      final source = [
        _message(messageId: 100, locationMessageId: 10, content: 'ten'),
        _message(
          messageId: 110,
          locationMessageId: 0,
          senderType: 'user_enter_location',
          content: 'enter',
        ),
        _message(messageId: 120, locationMessageId: 11, content: 'eleven'),
        _message(
          messageId: 130,
          locationMessageId: 0,
          senderType: 'story_events',
          content: 'story',
        ),
        _message(
          messageId: 135,
          locationMessageId: 0,
          senderType: 'characters_moved',
          content: 'moved',
        ),
        _message(messageId: 140, locationMessageId: 12, content: 'twelve'),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.messageId),
        [100, 110, 120, 130, 135, 140],
      );
      expect(oldestLocationChatMessageIdForTesting(source), 10);
    },
  );

  test(
    'positive story_events location ids participate in the continuous window',
    () {
      final source = [
        _message(
          messageId: 58,
          locationMessageId: 30,
          senderType: 'narrator',
          content: 'Narrator before the events',
        ),
        _message(
          messageId: 60,
          locationMessageId: 31,
          senderType: 'story_events',
          content: 'First flat story event',
        ),
        _message(
          messageId: 61,
          locationMessageId: 32,
          senderType: 'story_events',
          content: 'Second flat story event',
        ),
        _message(
          messageId: 64,
          locationMessageId: 33,
          senderType: 'user_enter_location',
          content: 'Enter after the events',
        ),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.messageId),
        [58, 60, 61, 64],
      );
      expect(locationChatMessageGapFillCursorForTesting(source), 0);
    },
  );

  test('timeline events respect the visible side of a location id gap', () {
    final source = [
      _message(messageId: 100, locationMessageId: 1, content: 'old one'),
      _message(
        messageId: 110,
        locationMessageId: 0,
        senderType: 'story_events',
        content: 'old-side event',
      ),
      _message(messageId: 400, locationMessageId: 4, content: 'new four'),
      _message(
        messageId: 410,
        locationMessageId: 0,
        senderType: 'user_enter_location',
        content: 'new-side event',
      ),
      _message(messageId: 500, locationMessageId: 5, content: 'new five'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.messageId),
      [400, 410, 500],
    );
    expect(locationChatMessageGapFillCursorForTesting(source), 4);
  });

  test('timeline-only queues retain every event without tick collapsing', () {
    final source = [
      _message(
        messageId: 100,
        locationMessageId: 0,
        senderType: 'story_events',
        content: 'story one',
      ),
      _message(
        messageId: 110,
        locationMessageId: 0,
        senderType: 'story_events',
        content: 'story two',
      ),
      _message(
        messageId: 120,
        locationMessageId: 0,
        senderType: 'characters_moved',
        content: 'moved',
      ),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.messageId),
      [100, 110, 120],
    );
    expect(oldestLocationChatMessageIdForTesting(source), 0);
    expect(locationChatMessageGapFillCursorForTesting(source), 0);
  });

  test(
    'visible location chat messages include leading tick in visible window',
    () {
      final source = [
        _message(
          messageId: 0,
          locationMessageId: 0,
          senderType: 'tick',
          tickNo: 1,
          content: 'Day 1, 20:00',
        ),
        _message(messageId: 55, locationMessageId: 55, content: 'turn 19'),
        _message(messageId: 56, locationMessageId: 56, content: 'narrator'),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.content),
        ['Day 1, 20:00', 'turn 19', 'narrator'],
      );
    },
  );

  test('visible location chat messages hide ticks without a number', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        tickNo: 0,
        content: 'Day 1, 20:00',
      ),
      _message(messageId: 2, locationMessageId: 1, content: 'one'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['one'],
    );
  });

  test('visible location chat messages keep leading cursorless records', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'Day 1, 20:00',
      ),
      _message(
        messageId: 5,
        locationMessageId: 0,
        senderType: 'character',
        content: 'dirty record without location id',
      ),
      _message(messageId: 45, locationMessageId: 12, content: 'first valid'),
      _message(messageId: 46, locationMessageId: 13, content: 'second valid'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      [
        'Day 1, 20:00',
        'dirty record without location id',
        'first valid',
        'second valid',
      ],
    );
  });

  test('visible location chat messages collapse consecutive ticks', () {
    final source = [
      _message(messageId: 1, locationMessageId: 1, content: 'one'),
      _message(
        messageId: 2,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'older tick',
      ),
      _message(
        messageId: 3,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'newer tick',
      ),
      _message(messageId: 4, locationMessageId: 2, content: 'two'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['one', 'newer tick', 'two'],
    );
  });

  test('visible location chat messages collapse consecutive leading ticks', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'older leading tick',
      ),
      _message(
        messageId: 2,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'newer leading tick',
      ),
      _message(messageId: 3, locationMessageId: 1, content: 'one'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['newer leading tick', 'one'],
    );
  });

  test('visible location chat messages collapse tick-only queues', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'Tick 1',
      ),
      _message(
        messageId: 2,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'Tick 2',
      ),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['Tick 2'],
    );
  });

  test(
    'visible location chat messages keep rendered old data before new gaps',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ];

      expect(
        visibleLocationChatMessagesWithRenderedIdsForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
        ).map((message) => message.messageId),
        [10, 20],
      );
    },
  );

  test('visible location chat messages fill holes inside rendered span', () {
    final source = [
      _message(messageId: 193, locationMessageId: 160, content: 'hi'),
      _message(
        messageId: 194,
        locationMessageId: 161,
        senderType: 'narrator',
        content: 'narrator inside rendered span',
      ),
      _message(
        messageId: 195,
        locationMessageId: 162,
        senderType: 'character',
        content: 'character',
      ),
      _message(messageId: 197, locationMessageId: 164, content: 'new gap'),
    ];

    expect(
      visibleLocationChatMessagesWithRenderedIdsForTesting(
        source,
        renderedLocationMessageIds: const {160, 162},
      ).map((message) => message.locationMessageId),
      [160, 161, 162],
    );
  });

  test('visible location chat messages release unrecoverable gaps', () {
    final source = [
      _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
      _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
      _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
      _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
    ];

    expect(
      visibleLocationChatMessagesWithRenderedIdsForTesting(
        source,
        renderedLocationMessageIds: const {1, 2},
        releasedGapKeys: const {'loc-1\u001F2\u001F4'},
      ).map((message) => message.messageId),
      [10, 20, 40, 50],
    );
  });

  test(
    'oldest edge notice waits for rendered window to include oldest message',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ];

      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {4, 5},
        ),
        isFalse,
      );
      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          releasedGapKeys: const {'loc-1\u001F2\u001F4'},
        ),
        isTrue,
      );
    },
  );

  test(
    'oldest edge notice waits while older loading or gap fill is active',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
      ];

      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          loadingOlderMessages: true,
        ),
        isFalse,
      );
      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          hasPendingGapFill: true,
        ),
        isFalse,
      );
      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          hasMoreOlderMessages: true,
        ),
        isFalse,
      );
    },
  );
}

WorldChatroomMessage _message({
  required int messageId,
  required int locationMessageId,
  required String content,
  String senderType = 'user',
  int? tickNo,
  String? senderId,
  bool isLlmStreamMessage = false,
}) {
  return WorldChatroomMessage(
    messageId: messageId,
    locationMessageId: locationMessageId,
    conversationRoundId: '$messageId',
    roundOrder: 0,
    tickNo: tickNo ?? (senderType == 'tick' ? messageId : 0),
    locationId: 'loc-1',
    senderType: senderType,
    senderId: senderId ?? (senderType == 'tick' ? 'tick' : 'u_peer'),
    senderName: senderType == 'tick' ? 'Time' : 'Peer',
    content: content,
    createdAt: null,
    isLlmStreamMessage: isLlmStreamMessage,
  );
}

WorldChatroomMessage _timelineMessage({
  required int messageId,
  required String senderType,
  required Object payload,
  int tickNo = 0,
  int subTickNo = 0,
  String currentTime = '',
}) {
  return WorldChatroomMessage.fromHttpMessage(
    ChatroomHttpMessage.fromJson({
      'global_message_id': 90000 + messageId,
      'message_id': messageId,
      'location_msg_id': messageId,
      'location_id': 'location-current',
      'conversation_round_id': messageId,
      'sender_type': senderType,
      'sender_id': 'sub_tick',
      'sender_name': 'sub_tick',
      'tick_no': tickNo,
      'sub_tick_no': subTickNo,
      'content': payload is String ? payload : jsonEncode(payload),
      'current_time': currentTime,
    }),
  );
}

WorldChatroomMessage _wssStoryTimelineMessage({
  required int messageId,
  required int locationMessageId,
  required int tickNo,
  required int subTickNo,
  required String currentTime,
  required Map<String, dynamic> payload,
}) {
  final envelope = ChatroomEnvelope.fromJson({
    'type': chatroomStoryEventsSenderType,
    'schema_version': 1,
    'event_id': 'event-$messageId',
    'ts': 1786062600000,
    'world_id': 'world-current',
    'location_id': 'location-current',
    'global_msg_id': 90000 + messageId,
    'msg_id': messageId,
    'location_msg_id': locationMessageId,
    'conversation_round_id': messageId,
    'sender_id': 'sub_tick',
    'sender_name': 'sub_tick',
    'tick_no': tickNo,
    'sub_tick_no': subTickNo,
    'current_time': currentTime,
    'payload': payload,
  });
  return WorldChatroomMessage.fromStoryEventsMessage(
    ChatroomStoryEventsMessage.fromEnvelope(envelope),
  );
}
